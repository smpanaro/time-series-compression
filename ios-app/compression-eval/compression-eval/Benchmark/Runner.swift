//
//  Runner.swift
//  compression-eval
//
//  Created by Stephen Panaro on 8/12/23.
//

import Foundation
import Compression
#if os(iOS)
import UIKit
#else
import AppKit
#endif
import ZSTD
import Brotli

enum Method: String, CaseIterable {
    case zstd = "zstd"
    case brotli = "Brotli"
    case lzma = "LZMA"
    case lzfse = "LZFSE"
//    case appleBrotli = "Apple Brotli" // Need to use libCompression
    case zlib = "zlib"

    var levels: ClosedRange<Int>? {
        switch self {
        case .zstd:
            // ZSTD.Level.min.rawValue is -131072
            return Int(-10)...Int(ZSTD.Level.max.rawValue)
        case .brotli:
            return Int(Brotli.Quality.min.rawValue)...Int(Brotli.Quality.max.rawValue)
        default:
                return nil
        }
    }
}

struct Result {
    let iterationCount: Int
    let duration: Duration
}

struct Results {
    let byFile: [String: Result]

    var mean: Duration {
        let sum = byFile.values.map { $0.duration }.reduce(.zero, +)
        return sum / Double(byFile.count)
    }

    var byFileName: [(String, Result)] {
        byFile.map { ($0, $1) }
            .sorted(by: { $0.0 < $1.0 })
    }
}

fileprivate protocol Compressor {
    func compress(_ data: Data)
}

struct Runner {
    let files = NSDataAsset.loadBrewAssets()

    func run(_ method: Method, level: Int?) -> Results? {
        switch method {
        case .zstd:  return run(compressor: ZSTDCompressor(level: level))
        case .brotli: return run(compressor: BrotliCompressor(level: level))
        case .lzma: return run(compressor: AppleCompressor(algorithm: .lzma))
        case .lzfse: return run(compressor: AppleCompressor(algorithm: .lzfse))
        case .zlib: return run(compressor: AppleCompressor(algorithm: .zlib))
        }
    }

    fileprivate func run(compressor: Compressor) -> Results? {
        var results = [String: Result]()
        for (name, data) in files {
            let duration = measure(data, with: compressor.compress(_:))
            results[name] = duration
        }

        return .init(byFile: results)
    }


    fileprivate func measure(_ data: Data, with compressFn: (Data) -> Void) -> Result {
        let clock = ContinuousClock()

        // Get a rough idea of how long an iteration takes so we can choose a reasonable iteration count.
        let baselineStart = clock.now
        var baselineCount = 0
        for i in 0..<5_000 {
            compressFn(data)
            if clock.now - baselineStart > Duration.milliseconds(500) {
                baselineCount = i+1
                break
            }
        }
        let approxDurationPerIteration = (clock.now - baselineStart) / max(1, baselineCount)

        // If it is so fast that we can complete 5k iterations in < 500ms run for at least 3x that.
        // If it is slow (e.g. secons), we want at least 1 iteration.
        let minIterations = baselineCount == 0 ? 1_000 : 1
        let maxIterations = 50_000

        // Set the number of iterations to run for ~1.5s.
        let iterations = min(maxIterations, max(minIterations, Int(Duration.milliseconds(1_500) / approxDurationPerIteration)))
        let duration = clock.measure {
            for _ in 0..<iterations {
                compressFn(data)
            }
        } / iterations
        return .init(iterationCount: iterations, duration: duration)
    }
}

struct AppleCompressor: Compressor {
    let algorithm: NSData.CompressionAlgorithm

    func compress(_ data: Data) {
        try! (data as NSData).compressed(using: algorithm)
    }
}

struct BrotliCompressor: Compressor {
    let quality: Brotli.Quality
    init(level rawLevel: Int?) {
        self.quality = rawLevel.map { .init(rawValue: Brotli.Quality.RawValue($0))! } ?? .default
    }

    func compress(_ data: Data) {
        // This is faster(!) than the go implementation because it is version 1.9 and "github.com/andybalholm/brotli" is 1.5.
        let compressConfig = Brotli.CompressConfig(quality: quality)
        let inputMemory = BufferedMemoryStream(startData: data)
        let compressMemory = BufferedMemoryStream()
        try! Brotli.compress(reader: inputMemory, writer: compressMemory, config: compressConfig)
    }
}


struct ZSTDCompressor: Compressor {
    let level: ZSTD.Level
    init(level rawLevel: Int?) {
        self.level = rawLevel.map { .init(rawValue: ZSTD.Level.RawValue($0))! } ?? .default
    }

    func compress(_ data: Data) {
        // Match the parameters of the go implementation. Buffer size must be greater than
        // the data size (~40KB max) since this implementation buffers and the go one does not.
        let compressConfig = ZSTD.CompressConfig(bufferSize: 100_000, level: level)
        let inputMemory = BufferedMemoryStream(startData: data)
        let compressMemory = BufferedMemoryStream()
        try! ZSTD.compress(reader: inputMemory, writer: compressMemory, config: compressConfig)
    }
}
extension Duration {
    var measurement: Measurement<UnitDuration> {
        let (seconds, attoseconds) = components
        return .init(value: Double(seconds), unit: .seconds) + .init(value: Double(attoseconds) * 1e-6, unit: .picoseconds)
    }
}

extension NSDataAsset {
    static let brewAssetNames = ["Brew 1", "Brew 2", "Brew 3"]

    static func loadBrewAssets() -> [String: Data] {
        let kvs = brewAssetNames
            .compactMap {
                NSDataAsset(name: $0)
            }
            .map { ($0.name, $0.data) }
        return Dictionary(kvs, uniquingKeysWith: { a,b in a })
    }
}
