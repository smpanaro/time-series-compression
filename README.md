# Time Series Compression

Supporting code for time series compression blog post:
- 📏 compression evaluation (main.go, ios-app)
- 📊 chart generation (ios-app)

## main.go CLI

This CLI compresses scale timeseries (like in `fixtures/`) and measures compression ratio.

e.g.
```shell
❯ go run . evaluate -method simple-8b -path fixtures/brew1.txt
Algorithm        : simple-8b
Uncompressed     : 78228 bytes
Compressed       : 11304 bytes
Compression Ratio: 6.92
```

### running
1. You may will need both xz and brotli installed to build the binary.
    1. `brew install xz brotli`.
    1. If your homebrew prefix is not `/opt/homebrew`, update the #cgo directive in `compressor.go` with whatever it is.
    1. Alternatively, comment out the xz and brotli code in `compressor.go`
1. `go run .` from the repo root.

## ios-app

This app runs compression benchmarks on macOS or iOS. It also has a few charts created for visualization in the blog post.

### running
1. Open in Xcode and run.
    1. Be sure to Edit Scheme and change the build configuration to `Release` before running benchmarks.