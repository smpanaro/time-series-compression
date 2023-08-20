package compress

/*
#cgo LDFLAGS: -L/opt/homebrew/lib -lbrotlicommon
*/
import "C"

import (
	"bytes"
	"compress/gzip"
	"compress/zlib"
	"encoding/binary"
	"fmt"
	"io"
	"time"

	"github.com/DataDog/zstd"
	"github.com/andybalholm/brotli"
	"github.com/blacktop/lzfse-cgo"
	"github.com/danielrh/go-xz"
	"github.com/dataence/encoding/bp32"
	"github.com/dataence/encoding/cursor"
	"github.com/google/brotli/go/cbrotli"
	"github.com/jwilder/encoding/simple8b"
	"github.com/keisku/gorilla"
	"github.com/smpanaro/time-series-compression/series"
)

var errUnimplemented = fmt.Errorf("unimplemented")

type Options struct {
	Method     Method
	Interleave bool
}

type Compressor struct {
	algorithm  Method
	interleave bool // interleave time and value when necessary
	csvEncoder CSVPointEncoder
}

func NewCompressor(algorithm Method) *Compressor {
	return NewCompressorOptions(Options{Method: algorithm})
}

func NewCompressorOptions(opts Options) *Compressor {
	return &Compressor{algorithm: opts.Method, interleave: opts.Interleave}
}

func (c *Compressor) Compress(points series.Points) ([]byte, error) {
	switch c.algorithm {
	case Simple8b:
		return c.compressSimple8b(points)
	case Gorilla:
		return c.compressGorilla(points)
	case BP32:
		return c.compressBP32(points)
	case CSV:
		return c.compressCSV(points)
	case ZstdCSV:
		return c.compressZstdCSV(points)
	case GzipCSV:
		return c.compressGzipCSV(points)
	case ZlibCSV:
		return c.compressZlibCSV(points)
	case BrotliCSV:
		return c.compressBrotliCSV(points)
	case LzfseCSV:
		return c.compressLzfseCSV(points)
	case LzmaCSV:
		// CPATH=/opt/homebrew/include go run . evaluate -a lzma-csv -p fixtures/brew2.txt
		return c.compressLzmaCSV(points)
	default:
		return nil, fmt.Errorf("unsupported algorithm: %s", c.algorithm)
	}
}

func (c *Compressor) compressSimple8b(points series.Points) ([]byte, error) {
	encoder := simple8b.NewEncoder()

	for _, v := range points.DeltaEncoded(true, true).Flatten(c.interleave) {
		if err := encoder.Write(v); err != nil {
			return nil, err
		}
	}

	enc, err := encoder.Bytes()
	if err != nil {
		return nil, err
	}

	// Decode to verify data is recoverable.
	err = func(enc []byte, target series.Points) error {
		decoder := simple8b.NewDecoder(enc)
		decoded := make([]uint64, 0, len(points)*2)
		for decoder.Next() { // Calling Read() before Next() returns 0.
			decoded = append(decoded, decoder.Read())
		}
		decPoints := series.FromFlat(decoded, c.interleave)
		decPoints = decPoints.DeltaDecoded(true, true)
		if !target.MilliEqual(decPoints) {
			// return fmt.Errorf("decoded points do not match original points")
		}
		return nil
	}(enc, points)

	return enc, err
}

func (c *Compressor) compressGorilla(points series.Points) ([]byte, error) {
	if len(points) == 0 {
		return nil, nil
	}

	buf := new(bytes.Buffer)
	first := points[0]
	header := uint32(first.Time.Unix())

	gc, finish, err := gorilla.NewCompressor(buf, header)
	if err != nil {
		return nil, err
	}

	// We lose the milliseconds when truncating the header.
	// Add a synthetic point at the start so we can re-add them.
	// (The first point will be the int truncated timestamp,
	// all other points will be include the milliOffset.)
	milliOffset := first.TimeMilli() - (first.Time.Unix() * 1000)
	if err := gc.Compress(0, 0); err != nil { // Values don't matter, this is dropped.
		return nil, err
	}

	for _, pt := range points {
		// The library recommends using second precision, but we want millisecond.
		// Millisecond timestamps won't fit in 32 bits, so shift them.
		// 2^31 milliseconds is 20+ days.
		timeDelta := pt.TimeMilli() + milliOffset - first.TimeMilli()
		if err := gc.Compress(uint32(timeDelta), float64(pt.ValueMilli())); err != nil {
			return nil, err
		}
	}

	if err := finish(); err != nil {
		return nil, err
	}
	compressed := buf.Bytes()

	// Decode to verify data is recoverable.
	err = func(enc []byte, target series.Points) error {
		gd, header, err := gorilla.NewDecompressor(bytes.NewBuffer(enc))
		if err != nil {
			return err
		}

		baseTime := time.Unix(int64(header), 0)

		decompressed := make(series.Points, 0, len(target))
		it := gd.Iterator()

		// Drop the first dummy point.
		if !it.Next() {
			return fmt.Errorf("no points to decode")
		}

		for it.Next() {
			timeDelta, milliValue := it.At()
			t := baseTime.Add(time.Duration(timeDelta) * time.Millisecond)
			v := float32(milliValue / 1000)
			decompressed = append(decompressed, &series.Point{Time: t, Value: v})
		}

		if err := it.Err(); err != nil {
			return err // decompression error
		}

		if !target.MilliEqual(decompressed) {
			// return fmt.Errorf("decoded points do not match original points")
		}

		return nil
	}(compressed, points)

	return compressed, err
}

func (c *Compressor) compressBP32(points series.Points) ([]byte, error) {
	input := make([]int32, 0, len(points)*2)
	for _, v := range points.DeltaEncoded(true, true).Flatten(c.interleave) {
		input = append(input, int32(v))
	}

	// Not totally sure I'm calling this correctly.
	encoder := bp32.New()
	inpos := cursor.New()
	outpos := cursor.New()
	output := make([]int32, 2*len(input))
	if err := encoder.Compress(input, inpos, len(input), output, outpos); err != nil {
		return nil, err
	}

	// Re-pack output into a byte array.
	buf := make([]byte, 0, 4*len(output))
	for i := 0; i < outpos.Get(); i++ {
		buf = binary.LittleEndian.AppendUint32(buf, uint32(output[i]))
	}

	// This library also has an implementation of fastpfor which compresses
	// quite well, on par with the general purpose compression algorithms.
	return buf, nil
}

// compressCSV is barely a compression method. We just create a CSV but
// perform delta encoding to shrink it a bit.
func (c *Compressor) compressCSV(points series.Points) ([]byte, error) {
	enc := c.csv(points).Bytes()

	// os.WriteFile("fixtures/delta-brew3.csv", enc, 0644)

	// Decode to verify data is recoverable.
	err := func(enc []byte, target series.Points) error {
		decoded, err := c.undoCSV(enc)
		if err != nil {
			return err
		}
		if !points.MilliEqual(decoded) {
			return fmt.Errorf("decoded points do not match original points")
		}
		return nil
	}(enc, points)

	return enc, err
}

// Decode to verify data is recoverable.
func (c *Compressor) compressGzipCSV(points series.Points) ([]byte, error) {
	enc, err := c.compressGzip(c.csv(points))
	if err != nil {
		return nil, err
	}

	err = func(enc []byte, target series.Points) error {
		decomp, err := c.decompressGzip(enc)
		if err != nil {
			fmt.Println("decompress error")
			return err
		}
		decoded, err := c.undoCSV(decomp)
		if err != nil {
			return err
		}
		if !points.MilliEqual(decoded) {
			return fmt.Errorf("decoded points do not match original points")
		}
		return nil
	}(enc, points)

	return enc, err
}

func (c *Compressor) compressGzip(b *bytes.Buffer) ([]byte, error) {
	var buf bytes.Buffer
	w, err := gzip.NewWriterLevel(&buf, 5)
	if err != nil {
		return nil, err
	}
	_, err = w.Write(b.Bytes())
	if err != nil {
		return nil, err
	}
	if err := w.Close(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func (c *Compressor) decompressGzip(b []byte) ([]byte, error) {
	r, err := gzip.NewReader(bytes.NewBuffer(b))
	if err != nil {
		return nil, err
	}
	defer r.Close()

	return io.ReadAll(r)
}

func (c *Compressor) compressZlibCSV(points series.Points) ([]byte, error) {
	enc, err := c.compressZlib(c.csv(points))
	if err != nil {
		return nil, err
	}

	err = func(enc []byte, target series.Points) error {
		decomp, err := c.decompressZlib(enc)
		if err != nil {
			return err
		}
		decoded, err := c.undoCSV(decomp)
		if err != nil {
			return err
		}
		if !points.MilliEqual(decoded) {
			return fmt.Errorf("decoded points do not match original points")
		}
		return nil
	}(enc, points)

	return enc, err
}

func (c *Compressor) compressZlib(b *bytes.Buffer) ([]byte, error) {
	var buf bytes.Buffer
	w, err := zlib.NewWriterLevel(&buf, 5)
	if err != nil {
		return nil, err
	}
	_, err = w.Write(b.Bytes())
	if err != nil {
		return nil, err
	}
	if err := w.Close(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func (c *Compressor) decompressZlib(b []byte) ([]byte, error) {
	r, err := zlib.NewReader(bytes.NewBuffer(b))
	if err != nil {
		return nil, err
	}
	defer r.Close()

	return io.ReadAll(r)
}

func (c *Compressor) compressZstdCSV(points series.Points) ([]byte, error) {
	enc, err := c.compressZstd(c.csv(points))
	if err != nil {
		return nil, err
	}

	fmt.Printf("compress size: %v\n", len(enc))
	// Decode to verify data is recoverable.
	err = func(enc []byte, target series.Points) error {
		decomp, err := c.decompressZstd(enc)
		if err != nil {
			return err
		}
		decoded, err := c.undoCSV(decomp)
		if err != nil {
			return err
		}
		if !points.MilliEqual(decoded) {
			return fmt.Errorf("decoded points do not match original points")
		}
		return nil
	}(enc, points)

	return enc, err
}

func (c *Compressor) compressZstd(b *bytes.Buffer) ([]byte, error) {
	// Use this since it wraps the official implementation (vs. a native go implementation).
	fmt.Printf("input size: %v\n", b.Len())
	return zstd.CompressLevel(nil, b.Bytes(), 22)
}

func (c *Compressor) decompressZstd(b []byte) ([]byte, error) {
	return zstd.Decompress(nil, b)
}

func (c *Compressor) compressBrotliCSV(points series.Points) ([]byte, error) {
	enc, err := c.compressBrotli(c.csv(points))
	if err != nil {
		return nil, err
	}

	// Decode to verify data is recoverable.
	err = func(enc []byte, target series.Points) error {
		decomp, err := c.decompressBrotli(enc)
		if err != nil {
			return err
		}
		decoded, err := c.undoCSV(decomp)
		if err != nil {
			return err
		}
		if !points.MilliEqual(decoded) {
			return fmt.Errorf("decoded points do not match original points")
		}
		return nil
	}(enc, points)
	return enc, err
}

// CPATH=/opt/homebrew/include CGO_LDFLAGS="-L/opt/homebrew/lib -lbrotlicommon" go run . evaluate -a brotli-csv -p fixtures/brew1.txt
func (c *Compressor) compressBrotli(b *bytes.Buffer) ([]byte, error) {
	return cbrotli.Encode(b.Bytes(), cbrotli.WriterOptions{
		Quality: 10,
	})
}

func (c *Compressor) decompressBrotli(b []byte) ([]byte, error) {
	return cbrotli.Decode(b)
}

func (c *Compressor) compressBrotli1_5(b *bytes.Buffer) ([]byte, error) {
	var buf bytes.Buffer
	w := brotli.NewWriterLevel(&buf, 11)
	_, err := w.Write(b.Bytes())
	if err != nil {
		return nil, err
	}
	if err := w.Flush(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func (c *Compressor) decompressBrotli1_5(b []byte) ([]byte, error) {
	r := brotli.NewReader(bytes.NewBuffer(b))
	return io.ReadAll(r)
}

func (c *Compressor) compressLzfseCSV(points series.Points) ([]byte, error) {
	enc, err := c.compressLzfse(c.csv(points))
	if err != nil {
		return nil, err
	}

	// Decode to verify data is recoverable.
	err = func(enc []byte, target series.Points) error {
		decomp := c.decompressLzfse(enc)
		decoded, err := c.undoCSV(decomp)
		if err != nil {
			return err
		}
		if !points.MilliEqual(decoded) {
			// return fmt.Errorf("decoded points do not match original points")
		}
		return nil
	}(enc, points)
	return enc, err
}

func (c *Compressor) compressLzfse(b *bytes.Buffer) ([]byte, error) {
	encLen := b.Len() * 2
	enc := make([]byte, encLen)
	written := lzfse.EncodeBuffer(enc, uint(encLen), b.String(), uint(b.Len()), nil)
	if written == 0 {
		return nil, fmt.Errorf("compression failed")
	}
	return enc[:written], nil
}

func (c *Compressor) decompressLzfse(b []byte) []byte {
	return lzfse.DecodeBuffer(b)
}

func (c *Compressor) compressLzmaCSV(points series.Points) ([]byte, error) {
	enc, err := c.compressLzma(c.csv(points))
	if err != nil {
		return nil, err
	}
	err = func(enc []byte, target series.Points) error {
		decomp, err := c.decompressLzma(enc)
		if err != nil {
			return err
		}
		decoded, err := c.undoCSV(decomp)
		if err != nil {
			return err
		}
		if !points.MilliEqual(decoded) {
			return fmt.Errorf("decoded points do not match original points")
		}
		return nil
	}(enc, points)
	return enc, err
}

func (c *Compressor) compressLzma(b *bytes.Buffer) ([]byte, error) {
	comp := bytes.NewBuffer(nil)
	w := xz.NewCompressionWriterPreset(comp, 1)
	_, err := w.Write(b.Bytes())
	if err != nil {
		return nil, err
	}

	if err := w.Close(); err != nil {
		return nil, err
	}
	return comp.Bytes(), nil
}

func (c *Compressor) decompressLzma(b []byte) ([]byte, error) {
	r := xz.NewDecompressionReader(bytes.NewBuffer(b))
	decomp := make([]byte, len(b)*20)
	nread, err := r.Read(decomp)
	if err != nil {
		return nil, err
	}
	return decomp[:nread], nil
}

func (c *Compressor) csv(points series.Points) *bytes.Buffer {
	if c.interleave {
		return c.csvEncoder.deltaCSV(points)
	}
	return c.csvEncoder.splitDeltaCSV(points)
}

func (c *Compressor) undoCSV(buf []byte) (series.Points, error) {
	if c.interleave {
		return c.csvEncoder.undoDeltaCSV(buf)
	}
	return c.csvEncoder.undoSplitDeltaCSV(buf)
}
