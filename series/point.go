package series

import (
	"encoding/csv"
	"fmt"
	"math"
	"os"
	"strconv"
	"time"
)

type Point struct {
	Time  time.Time
	Value float32
}

func (p *Point) ValueMilli() int64 {
	return int64(math.Round(float64(p.Value * 1000)))
}

func (p *Point) TimeMilli() int64 {
	return p.Time.UnixMilli()
}

func (p *Point) MilliEqual(other *Point) bool {
	if p == nil || other == nil {
		return p == nil && other == nil
	}
	return p.TimeMilli() == other.TimeMilli() && p.ValueMilli() == other.ValueMilli()
}

type Points []*Point

func (p Points) MilliEqual(other Points) bool {
	if len(p) != len(other) {
		return false
	}
	for i := range p {
		if !p[i].MilliEqual(other[i]) {
			fmt.Printf("p[%d] = %v, other[%d] = %v\n", i, p[i], i, other[i])
			return false
		}
	}
	return true
}

func (p Points) Flatten(interleaved bool) []uint64 {
	if interleaved {
		return p.Interleaved()
	}
	return p.Split()
}

// Interleaved returns an int64 array with alternating timestamps and values.
func (p Points) Interleaved() []uint64 {
	interleaved := make([]uint64, len(p)*2)
	for i, pt := range p {
		interleaved[i*2] = uint64(pt.TimeMilli())
		// Use ZigZag encoding to shrink the number of set bits without losing sign information.
		interleaved[i*2+1] = ZigZagEncode64(pt.ValueMilli())
	}

	return interleaved
}

// Split returns an int64 array with timestamps first followed by values after.
func (p Points) Split() []uint64 {
	split := make([]uint64, len(p)*2)
	for i, pt := range p {
		split[i] = uint64(pt.TimeMilli())
		// Use ZigZag encoding to shrink the number of set bits without losing sign information.
		split[i+len(p)] = ZigZagEncode64(pt.ValueMilli())
	}

	return split
}

func FromFlat(flat []uint64, interleaved bool) Points {
	if interleaved {
		return FromInterleaved(flat)
	}
	return FromSplit(flat)
}

func FromInterleaved(interleaved []uint64) Points {
	pts := make(Points, len(interleaved)/2)
	for i := 0; i < len(interleaved)/2; i++ {
		pts[i] = &Point{
			Time:  time.UnixMilli(int64(interleaved[i*2])),
			Value: float32(ZigZagDecode64(interleaved[i*2+1])) / 1000,
		}
	}

	return pts
}

func FromSplit(split []uint64) Points {
	pts := make(Points, len(split)/2)
	for i := 0; i < len(split)/2; i++ {
		pts[i] = &Point{
			Time:  time.UnixMilli(int64(split[i])),
			Value: float32(ZigZagDecode64(split[i+len(split)/2])) / 1000,
		}
	}

	return pts
}

func (p Points) DeltaEncoded(times bool, values bool) Points {
	enc := make(Points, len(p))
	enc[0] = p[0]

	for i := 1; i < len(p); i++ {
		enc[i] = &Point{}
		if times {
			timeDelta := p[i].Time.Sub(p[i-1].Time)
			enc[i].Time = time.UnixMilli(timeDelta.Milliseconds())
		} else {
			enc[i].Time = p[i].Time
		}
		if values {
			enc[i].Value = p[i].Value - p[i-1].Value
		} else {
			enc[i].Value = p[i].Value
		}
	}
	return enc
}

func (p Points) DeltaDecoded(times bool, values bool) Points {
	dec := make(Points, len(p))
	dec[0] = p[0]

	for i := 1; i < len(p); i++ {
		dec[i] = &Point{}
		if times {
			timeDelta := time.Duration(p[i].Time.UnixNano() * int64(time.Nanosecond))
			dec[i].Time = dec[i-1].Time.Add(timeDelta)
		} else {
			dec[i].Time = p[i].Time
		}
		if values {
			dec[i].Value = dec[i-1].Value + p[i].Value
		} else {
			dec[i].Value = p[i].Value
		}
	}
	return dec
}

func FromFile(filename string) (Points, error) {
	f, err := os.Open(filename)
	if err != nil {
		return nil, err
	}

	r := csv.NewReader(f)
	lines, err := r.ReadAll()
	if err != nil {
		return nil, err
	}

	pts := make(Points, len(lines)-1)
	for i, l := range lines[1:] {
		unixMilli, err := strconv.ParseInt(l[0], 10, 64)
		if err != nil {
			return nil, err
		}
		t := time.UnixMilli(unixMilli)

		value, err := strconv.ParseFloat(l[1], 32)
		if err != nil {
			return nil, err
		}

		pts[i] = &Point{
			Time:  t,
			Value: float32(value),
		}
	}

	return pts, nil
}

// https://github.com/jwilder/encoding/blob/master/bitops/bits.go#L66C1-L68C2
func ZigZagEncode64(x int64) uint64 {
	return uint64(uint64(x<<1) ^ uint64((int64(x) >> 63)))
}
func ZigZagDecode64(v uint64) int64 {
	return int64((v >> 1) ^ uint64((int64(v&1)<<63)>>63))
}
