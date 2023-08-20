package evaluate

import (
	"fmt"

	"github.com/smpanaro/time-series-compression/compress"
	"github.com/smpanaro/time-series-compression/series"
)

type Evaluation struct {
	Algorithm  compress.Method
	Points     series.Points
	Compressor *compress.Compressor
}

func NewEvaluation(algorithm compress.Method, interleave bool, dataPath string) (*Evaluation, error) {
	points, err := series.FromFile(dataPath)
	if err != nil {
		return nil, err
	}

	return &Evaluation{
		Algorithm:  algorithm,
		Points:     points,
		Compressor: compress.NewCompressorOptions(compress.Options{Method: algorithm, Interleave: interleave}),
	}, nil
}

func (e *Evaluation) Run() (Result, error) {
	bytes, err := e.Compressor.Compress(e.Points)
	if err != nil {
		return Result{}, err
	}

	return Result{
		Algorithm: e.Algorithm,
		NumPoints: len(e.Points),
		Size:      len(bytes),
	}, nil
}

type Result struct {
	Algorithm compress.Method
	NumPoints int
	Size      int
}

func (r Result) NaiveSize() int64 {
	// timestamp in int64, value in float32
	return int64(r.NumPoints * (8 + 4))
}

func (r Result) PrintStats() {
	fmt.Printf("Algorithm        : %s\n", r.Algorithm)
	fmt.Printf("Uncompressed     : %v bytes\n", r.NaiveSize())
	fmt.Printf("Compressed       : %v bytes\n", r.Size)
	fmt.Printf("Compression Ratio: %.2f\n", float64(r.NaiveSize())/float64(r.Size))
}
