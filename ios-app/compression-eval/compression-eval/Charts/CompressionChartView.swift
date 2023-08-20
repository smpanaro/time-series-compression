//
//  CompressionChartView.swift
//  compression-eval
//
//  Created by Stephen Panaro on 8/17/23.
//

import SwiftUI
import Charts


struct CompressionChartView: View {
    let includeStacked: Bool
    let insetBorderColor: Color = .indigo

    enum Series: String {
        case specialist = "Specialist"
        case generalist = "Generalist"
        case stackedGeneralist = "Single-Column Generalist"

        static var colors: KeyValuePairs<String, Color> = [
            Series.stackedGeneralist.rawValue: .purple,
            Series.generalist.rawValue: .orange,
            Series.specialist.rawValue: .blue,
        ]
        static var withoutStackedColors: KeyValuePairs<String, Color> = [
            Series.generalist.rawValue: .orange,
            Series.specialist.rawValue: .blue,
        ]
    }

    var body: some View {
        VStack {
            Spacer()
            Chart {
                chartContents(includeNameAnnotations: false)
            }
            .chartForegroundStyleScale(
                includeStacked ? Series.colors : Series.withoutStackedColors
            )
            // No other way to modify font size afaict.
            .chartLegend(position: .bottom) {
                let series = includeStacked ? Series.colors : Series.withoutStackedColors
                HStack {
                    ForEach(series, id: \.key) { name, color in
                        HStack(alignment: .center, spacing: 4) {
                            BasicChartSymbolShape.circle
                                .fill(color)
                                .frame(width: 8, height: 8)
                            Text(name)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartXScale(domain: 0...32)
            .chartYScale(domain: -0.1...0.6) // Don't center this, so the labels have room.
            .chartYAxis(Visibility.hidden)
            .chartXAxis {
                AxisMarks(preset: .automatic) { v in
                    AxisTick()
                    AxisValueLabel {
                        if let ts = v.as(Double.self) {
                            Text(ts, format: .number) + Text(v.index != 0 ? "MB" : "")
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    if let minX = proxy.position(forX: 0),
                       let maxX = proxy.position(forX: 6),
                       let centerY = proxy.position(forY: 0)
                    {
                        let height = proxy.plotAreaSize.height / 8
                        let midX = (maxX - minX) / 2
                        let minY = centerY - height / 2
                        let maxY = centerY + height / 2
                        let width = maxX - minX
                        let ratio = width / height

                        let geoFrame = geo.frame(in: .local)

                        let chartHeight = minY * 0.65

                        Group {
                            Chart {
                                chartContents(includeUncompressed: false)
                            }
                            .chartXAxis {
                                AxisMarks(preset: .automatic) { v in
                                    if v.index != 0 && v.index != v.count - 1 {
                                        AxisTick()
                                        AxisGridLine()
                                    }
                                    AxisValueLabel {
                                        if let ts = v.as(Double.self) {
                                            Text(ts, format: .number) + Text(v.index != 0 ? "MB" : "")
                                        }
                                    }
                                }
                            }
                            .chartForegroundStyleScale(Series.colors)
                            .chartLegend(.hidden)
                            .frame(width: ratio * chartHeight, height: chartHeight)
                            .border(insetBorderColor, width: 2)
                            .overlay {
                                // Leo we have to go deeper.
                                GeometryReader { insetGeo in
                                    let insetFrame  = insetGeo.frame(in: .local)
                                    let fullChartFrame = insetGeo.frame(in: .named("fullChart"))
                                    Path { path in
                                        path.move(to: .init(x: insetFrame.minX + 1, y: 0))
                                        path.addLine(to: .init(x: -fullChartFrame.minX + 1, y: -fullChartFrame.minY + minY + 1))

                                        path.move(to: .init(x: insetFrame.maxX - 1, y: insetFrame.maxY - 1))
                                        path.addLine(to: .init(x: -fullChartFrame.minX + maxX - 1, y: -fullChartFrame.minY + maxY - 1))
                                    }
                                    .stroke(insetBorderColor.opacity(0.8), style: .init(lineWidth: 1, dash: [3]))

                                }
                            }
                            .position(x: geoFrame.midX, y: minY / 2)


                            Rectangle()
                                .fill(.clear)
                                .border(insetBorderColor, width: 2)
                                .position(x: midX, y: centerY)
                                .frame(width: maxX-minX, height: height)
                        }
                        .coordinateSpace(name: "fullChart")

                    }
                }
            }

            Spacer()
        }
        .padding()
    }

    @ChartContentBuilder func chartContents(
        includeUncompressed: Bool = true,
        includeNameAnnotations: Bool = true
    ) -> some ChartContent {
            RuleMark(y: .value("rule", 0))
                .lineStyle(.init(lineWidth: 1))
                .foregroundStyle(Color.secondary.opacity(0.6))

            if includeUncompressed {
                PointMark(x: .value("size", 26),
                          y: .value("group", 0))
                .foregroundStyle(.pink.opacity(0.7))
                .annotation(position: .topTrailing, spacing: -1) {
                    HStack(spacing: 6) {
                        Rectangle().frame(width: 8, height: 0.5)
                        Text("Uncompressed")
                    }
                    .rotationEffect(.degrees(-45), anchor: .bottomLeading)
                    .offset(x: 8)
                }
            }

            ForEach(PointGroup.specialist.points) { pt in
                PointMark(x: .value("size", pt.yearlyStorage.value),
                          y: .value("group", 0))
                .position(by: .value("name", pt.name))
                .opacity(0.5)
                .annotation(position: .topTrailing, spacing: -1) {
                    if includeNameAnnotations && PointGroup.specialist.extremaNames.contains(pt.name) {
                        HStack(spacing: 6) {
                            Rectangle().frame(width: 8, height: 0.5)
                                .opacity(0.6)
                            Text(pt.name)
                        }
                        .rotationEffect(.degrees(-45), anchor: .bottomLeading)
                        .offset(x: 8)
                    }
                }
            }
            .foregroundStyle(by: .value("group", Series.specialist.rawValue))

            ForEach(PointGroup.generalist.points) { pt in
                PointMark(x: .value("size", pt.yearlyStorage.value),
                          y: .value("group", 0))
                .position(by: .value("name", pt.name))
                .opacity(0.5)
                .annotation(position: .topTrailing, spacing: -1) {
                    if includeNameAnnotations && PointGroup.generalist.extremaNames.contains(pt.name) {
                        HStack(spacing: 6) {
                            Rectangle().frame(width: 8, height: 0.5)
                                .opacity(0.6)
                            Text(pt.name)
                        }
                        .rotationEffect(.degrees(-45), anchor: .bottomLeading)
                        .offset(x: pt.name == "zlib" ? 10 : 8)
                    }
                }
            }
            .foregroundStyle(by: .value("group", Series.generalist.rawValue))


            if includeStacked {
                ForEach(PointGroup.stackedGeneralist.points) { pt in
                    PointMark(x: .value("size", pt.yearlyStorage.value),
                              y: .value("group", 0))
                    .position(by: .value("name", pt.name))
                    .opacity(0.5)
                    .annotation(position: .topTrailing, spacing: -1) {
                        if includeNameAnnotations && PointGroup.stackedGeneralist.extremaNames.contains(pt.name) {
                            HStack(spacing: 6) {
                                Rectangle().frame(width: 8, height: 0.5)
                                    .opacity(0.6)
                                Text(pt.name)
                            }
                            .rotationEffect(.degrees(-45), anchor: .bottomLeading)
                            .offset(x: pt.name == "lzfse" ? 2 : 8)
                        }
                    }
                }
                .foregroundStyle(by: .value("group", Series.stackedGeneralist.rawValue))
            }
        }
}

struct CompressionChartView_Previews: PreviewProvider {
    static var previews: some View {
        CompressionChartView(includeStacked: false)
        CompressionChartView(includeStacked: true)
    }
}

struct CompressionPoint: Identifiable {
    let name: String
    let yearlyStorage: Measurement<UnitInformationStorage>
    var id = UUID()
}

struct PointGroup: Identifiable {
    let points: [CompressionPoint]
    var id = UUID()

    var min: CompressionPoint {
        points.min(by: { $0.yearlyStorage < $1.yearlyStorage} )!
    }
    var max: CompressionPoint {
        points.max(by: { $0.yearlyStorage < $1.yearlyStorage} )!
    }
    var extremaNames: [String] {
        [min, max].map { $0.name }
    }

    static let specialist: Self = .init(points: CompressionPoint.specialistPoints)
    static let generalist: Self = .init(points: CompressionPoint.generalistPoints)
    static let stackedGeneralist: Self = .init(points: CompressionPoint.stackedGeneralistPoints)
}

extension CompressionPoint {
    static let specialistPoints: [CompressionPoint] = [
        .init(name: "simple-8b", yearlyStorage: .init(value: 4, unit: .megabytes)),
        .init(name: "Gorilla", yearlyStorage: .init(value: 4.4, unit: .megabytes)),
    ]

    static let generalistPoints: [CompressionPoint] = [
        .init(name: "zlib", yearlyStorage: .init(value: 3.47, unit: .megabytes)),
        .init(name: "lzma", yearlyStorage: .init(value: 3.7, unit: .megabytes)),
        .init(name: "zstd", yearlyStorage: .init(value: 3.72, unit: .megabytes)),
        .init(name: "brotli", yearlyStorage: .init(value: 3.74, unit: .megabytes)),
        .init(name: "lzfse", yearlyStorage: .init(value: 3.8, unit: .megabytes)),
    ]

    // Single-column "stacked" CSV.
    static let stackedGeneralistPoints: [CompressionPoint] = [
        .init(name: "zlib", yearlyStorage: .init(value: 3.1, unit: .megabytes)),
        .init(name: "lzma", yearlyStorage: .init(value: 3.25, unit: .megabytes)),
        .init(name: "zstd", yearlyStorage: .init(value: 2.86, unit: .megabytes)),
        .init(name: "brotli", yearlyStorage: .init(value: 2.9, unit: .megabytes)),
        .init(name: "lzfse", yearlyStorage: .init(value: 3.39, unit: .megabytes)),
    ]
}
