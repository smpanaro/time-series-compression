//
//  ComparisonData.swift
//  compression-eval
//
//  Created by Stephen Panaro on 8/13/23.
//

import Foundation

enum OS: String, CaseIterable {
    case macOS = "macOS"
    case iOS = "iOS"
}

struct Run: Identifiable {
    let os: OS
    let method: Method
    let level: Int?
    let brewDurations: [Duration]

    var meanDuration: Duration {
        brewDurations.reduce(Duration.seconds(0), +) / Double(brewDurations.count)
    }

    var id = UUID()
}

extension Run {
    static var all: [Run] = {
        return rawData
            .split(separator: "\n")
            .compactMap { line -> Run? in
                var fields = line.split(separator: "\t", omittingEmptySubsequences: false)
                    .map { String($0) }
                    .map { $0.replacingOccurrences(of: ",", with: "") } // Int won't parse with commas.

                if fields.count != 6 {
                    print("Invalid field count, fields: \(fields)")
                    return nil
                }

                if
                    let os = OS(rawValue: fields[0]),
                    let method = Method(rawValue: fields[1]),
                    // level is fields[2]
                    let brew1 = Int(fields[3]),
                    let brew2 = Int(fields[4]),
                    let brew3 = Int(fields[5])
                {
                    let level = fields[2].count == 0 ? nil : Int(fields[2])
                    let durations = [brew1, brew2, brew3].map { Duration.microseconds($0) }
                    return Run(os: os, method: method, level: level, brewDurations: durations)
                }

                print("Failed to parse line: \(line)")
                return nil
            }
    }()

    // Paste + Preserve Formatting otherwise the tabs become spaces.
    static let rawData: String = """
macOS	zstd	0	99	37	34
macOS	zstd	1	99	35	37
macOS	zstd	2	115	41	38
macOS	zstd	3	99	37	34
macOS	zstd	4	111	70	71
macOS	zstd	5	301	103	103
macOS	zstd	6	511	175	175
macOS	zstd	7	666	305	376
macOS	zstd	8	799	400	699
macOS	zstd	9	1,145	463	620
macOS	zstd	10	1,713	466	619
macOS	zstd	11	3,112	746	700
macOS	zstd	12	3,159	951	1,096
macOS	zstd	13	3,037	1,195	1,537
macOS	zstd	14	5,158	1,203	1,581
macOS	zstd	15	5,204	1,203	1,548
macOS	zstd	16	6,880	2,366	3,131
macOS	zstd	17	7,120	2,358	3,091
macOS	zstd	18	6,918	2,370	3,099
macOS	zstd	19	13,619	2,359	3,075
macOS	zstd	20	13,659	2,383	3,122
macOS	zstd	21	13,547	2,361	3,077
macOS	zstd	22	13,603	2,376	3,079
macOS	Brotli	0	226	53	53
macOS	Brotli	1	238	64	57
macOS	Brotli	2	246	59	55
macOS	Brotli	3	284	77	66
macOS	Brotli	4	449	140	121
macOS	Brotli	5	788	230	210
macOS	Brotli	6	1,087	355	338
macOS	Brotli	7	1,452	344	353
macOS	Brotli	8	1,975	376	438
macOS	Brotli	9	3,857	1,273	1,233
macOS	Brotli	10	13,975	3,113	3,370
macOS	Brotli	11	44,086	11,101	11,251
macOS	LZMA		11,971	3,200	3,564
macOS	LZFSE		378	148	138
macOS	zlib		992	310	243
iOS	zstd	0	150	69	62
iOS	zstd	1	123	59	62
iOS	zstd	2	145	62	60
iOS	zstd	3	142	63	58
iOS	zstd	4	192	99	91
iOS	zstd	5	411	125	122
iOS	zstd	6	646	202	210
iOS	zstd	7	950	386	491
iOS	zstd	8	1,387	527	1,012
iOS	zstd	9	1,552	603	774
iOS	zstd	10	2,112	560	796
iOS	zstd	11	3,816	880	846
iOS	zstd	12	3,634	1,048	1,321
iOS	zstd	13	3,571	1,347	1,859
iOS	zstd	14	5,919	1,306	1,881
iOS	zstd	15	5,772	1,336	1,816
iOS	zstd	16	7,761	2,507	3,672
iOS	zstd	17	8,224	2,610	3,720
iOS	zstd	18	7,836	2,522	3,783
iOS	zstd	19	15,487	2,655	3,611
iOS	zstd	20	16,042	2,613	3,636
iOS	zstd	21	16,353	2,586	3,711
iOS	zstd	22	14,982	2,496	3,627
iOS	Brotli	0	230	55	56
iOS	Brotli	1	247	65	60
iOS	Brotli	2	315	99	96
iOS	Brotli	3	373	116	115
iOS	Brotli	4	596	199	186
iOS	Brotli	5	1,027	312	328
iOS	Brotli	6	1,268	415	434
iOS	Brotli	7	2,231	846	881
iOS	Brotli	8	3,005	1,173	1,176
iOS	Brotli	9	4,478	1,575	1,571
iOS	Brotli	10	16,009	3,372	3,947
iOS	Brotli	11	51,282	11,906	13,250
iOS	LZMA		12,683	3,543	3,929
iOS	LZFSE		419	144	142
iOS	zlib		1,048	324	259
"""
}
