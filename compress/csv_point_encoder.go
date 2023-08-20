package compress

import (
	"bytes"
	"encoding/csv"
	"fmt"
	"strconv"
	"time"

	"github.com/smpanaro/time-series-compression/series"
)

// CSVPointEncoder encodes Points as CSV.
type CSVPointEncoder struct{}

func (c *CSVPointEncoder) splitDeltaCSV(points series.Points) *bytes.Buffer {
	var buf bytes.Buffer
	s := csv.NewWriter(&buf)
	s.Write([]string{"value"})
	for _, pt := range points.DeltaEncoded(true, true) {
		millisecondDelta := fmt.Sprintf("%v", pt.TimeMilli())
		s.Write([]string{millisecondDelta})
	}
	for _, pt := range points.DeltaEncoded(true, true) {
		milligramsDelta := fmt.Sprintf("%v", pt.ValueMilli())
		s.Write([]string{milligramsDelta})
	}
	s.Flush()

	// Trim the trailing newline.
	return bytes.NewBuffer(bytes.TrimSpace(buf.Bytes()))
}

func (c *CSVPointEncoder) undoSplitDeltaCSV(buf []byte) (series.Points, error) {
	lines, err := csv.NewReader(bytes.NewBuffer(buf)).ReadAll()
	if err != nil {
		return nil, err
	}

	if len(lines) == 0 {
		return nil, fmt.Errorf("no data")
	}

	if len(lines) == 1 {
		return nil, fmt.Errorf("only header")
	}

	lines = lines[1:] // skip header

	if len(lines)%2 != 0 {
		return nil, fmt.Errorf("uneven number of lines")
	}

	pts := make(series.Points, 0, len(lines)/2)
	for i := 0; i < len(lines)/2; i++ {
		millisecondDelta, err := strconv.ParseInt(lines[i][0], 10, 64)
		if err != nil {
			return nil, err
		}
		milligramsDelta, err := strconv.ParseInt(lines[i+len(lines)/2][0], 10, 64)
		if err != nil {
			return nil, err
		}
		pts = append(pts, &series.Point{
			Time:  time.UnixMilli(millisecondDelta),
			Value: float32(milligramsDelta) / 1000,
		})
	}

	return pts.DeltaDecoded(true, true), nil
}

func (c *CSVPointEncoder) deltaCSV(points series.Points) *bytes.Buffer {
	var buf bytes.Buffer
	s := csv.NewWriter(&buf)
	s.Write([]string{"millisecond delta", "milligram delta"})
	for _, pt := range points.DeltaEncoded(true, true) {
		millisecondDelta := fmt.Sprintf("%v", pt.TimeMilli())
		milligramsDelta := fmt.Sprintf("%v", pt.ValueMilli())
		s.Write([]string{millisecondDelta, milligramsDelta})
	}
	s.Flush()

	// Trim the trailing newline.
	return bytes.NewBuffer(bytes.TrimSpace(buf.Bytes()))
}

func (c *CSVPointEncoder) undoDeltaCSV(buf []byte) (series.Points, error) {
	lines, err := csv.NewReader(bytes.NewBuffer(buf)).ReadAll()
	if err != nil {
		return nil, err
	}

	if len(lines) == 0 {
		return nil, fmt.Errorf("no data")
	}
	if len(lines) == 1 {
		return nil, fmt.Errorf("only header")
	}

	pts := make(series.Points, 0, len(lines)-1)
	for _, l := range lines[1:] { // skip header
		millisecondDelta, err := strconv.ParseInt(l[0], 10, 64)
		if err != nil {
			return nil, err
		}
		milligramsDelta, err := strconv.ParseInt(l[1], 10, 64)
		if err != nil {
			return nil, err
		}
		pts = append(pts, &series.Point{
			Time:  time.UnixMilli(millisecondDelta),
			Value: float32(milligramsDelta) / 1000,
		})
	}

	return pts.DeltaDecoded(true, true), nil
}
