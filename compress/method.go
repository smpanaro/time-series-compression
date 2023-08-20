package compress

import "strings"

type Method string

const (
	Simple8b  Method = "simple-8b"
	Gorilla   Method = "gorilla"
	BP32      Method = "bp32"
	CSV       Method = "csv"
	ZstdCSV   Method = "zstd-csv"
	GzipCSV   Method = "gzip-csv"
	ZlibCSV   Method = "zlib-csv"
	BrotliCSV Method = "brotli-csv"
	LzfseCSV  Method = "lzfse-csv"
	LzmaCSV   Method = "lzma-csv"
)

var (
	AllMethods = Methods{Simple8b, Gorilla, BP32, CSV, ZstdCSV, GzipCSV, ZlibCSV, BrotliCSV, LzfseCSV, LzmaCSV}
)

func (x Method) String() string {
	return string(x)
}

type Methods []Method

func (x Methods) Strings() []string {
	s := make([]string, len(x))
	for i, a := range x {
		s[i] = a.String()
	}
	return s
}

func (x Methods) Join(sep string) string {
	return strings.Join(x.Strings(), sep)
}

func (x Methods) Contains(a Method) bool {
	for _, b := range x {
		if a == b {
			return true
		}
	}
	return false
}
