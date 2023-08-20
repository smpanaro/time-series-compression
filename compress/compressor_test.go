package compress

import (
	"testing"

	"github.com/smpanaro/time-series-compression/series"
	"github.com/stretchr/testify/require"
)

func BenchmarkCompressor_compressBrotli(t *testing.B) {
	c := NewCompressor(Method(""))
	points, err := series.FromFile("../fixtures/brew1.txt")
	require.NoError(t, err)

	csv := c.deltaCSV(points)
	require.Greater(t, csv.Len(), 0)

	for i := 0; i < t.N; i++ {
		c.compressBrotli(csv)
	}
	// Brotli 1.5 from https://github.com/andybalholm/brotli
	//  654	   1743861 ns/op	 2760947 B/op	      74 allocs/op
	// 1.743861 ms

	// Level 1, 0.314578 ms
	// Level 11, 60.505794 ms
}

func BenchmarkCompressor_compressGzip(t *testing.B) {
	c := NewCompressor(Method(""))
	points, err := series.FromFile("../fixtures/brew1.txt")
	require.NoError(t, err)

	csv := c.deltaCSV(points)
	require.Greater(t, csv.Len(), 0)

	for i := 0; i < t.N; i++ {
		c.compressGzip(csv)
	}
	// Level 9: 8.70364 ms/op
	// Level 5: 1.336466 ms/op
	// Level 1: 0.369351 ms/op
}

func BenchmarkCompressor_compressZlib(t *testing.B) {
	c := NewCompressor(Method(""))
	points, err := series.FromFile("../fixtures/brew1.txt")
	require.NoError(t, err)

	csv := c.deltaCSV(points)
	require.Greater(t, csv.Len(), 0)

	for i := 0; i < t.N; i++ {
		c.compressZlib(csv)
	}
	// Level 5: 1.349067 ms
}

func BenchmarkCompressor_compressZstd(t *testing.B) {
	c := NewCompressor(Method(""))
	points, err := series.FromFile("../fixtures/brew1.txt")
	require.NoError(t, err)

	csv := c.deltaCSV(points)
	require.Greater(t, csv.Len(), 0)

	for i := 0; i < t.N; i++ {
		c.compressZstd(csv)
	}
	// Level: 3, 0.095466 ms/op

	// Level: 11, 3.10117 ms/op

	// Level 22, 13.13986 ms
}

func BenchmarkCompressor_compressLzfse(t *testing.B) {
	c := NewCompressor(Method(""))
	points, err := series.FromFile("../fixtures/brew1.txt")
	require.NoError(t, err)

	csv := c.deltaCSV(points)
	require.Greater(t, csv.Len(), 0)

	for i := 0; i < t.N; i++ {
		c.compressLzfse(csv)
	}
	// 0.35 ms/op
}

func BenchmarkCompressor_compressLzma(t *testing.B) {
	c := NewCompressor(Method(""))
	points, err := series.FromFile("../fixtures/brew1.txt")
	require.NoError(t, err)

	csv := c.deltaCSV(points)
	require.Greater(t, csv.Len(), 0)

	for i := 0; i < t.N; i++ {
		c.compressLzma(csv)
	}
	// Level 9: 17 ms/op
	// Level 6: 12.6 ms/op (the libCompression header claims this is what iOS uses)
}
