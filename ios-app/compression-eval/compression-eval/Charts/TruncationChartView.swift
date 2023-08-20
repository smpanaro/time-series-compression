//
//  TruncationChartView.swift
//  compression-eval
//
//  Created by Stephen Panaro on 8/18/23.
//

import SwiftUI
import Charts

struct TruncationPoint: Identifiable {
    let name: String
    let thousandth: Float
    let hundredth: Float
    let tenth: Float
    let unit: Float

    var id = UUID()

    var granularityPairs: [(Float, Float)] {
        [
            (0.001, thousandth),
            (0.01, hundredth),
            (0.1, tenth),
            (1.0, unit)
        ]
    }
}

extension TruncationPoint {
    var color: Color {
        [
            "simple-8b": Color.purple,
            "gorilla" : Color.orange,
            "lzfse": Color.blue,
        ][name] ?? .gray
    }
}

struct TruncationChartView: View {
    var body: some View {
        Chart {
            ForEach(TruncationPoint.allPoints) { point in
                ForEach(point.granularityPairs, id: \.0) { (granularity, value) in
                    LineMark(x: .value("truncated to", granularity),
                             y: .value("ratio", value),
                             series: .value("algorithm", point.name))
                    .foregroundStyle(point.color)
                    .foregroundStyle(by: .value("algorithm", point.name))
                }
            }
        }
        // No other way to modify font size afaict.
        .chartLegend(position: .bottom) {
            HStack {
                ForEach(TruncationPoint.allPoints) { point in
                    HStack(alignment: .center, spacing: 4) {
                        BasicChartSymbolShape.circle
                            .fill(point.color)
                            .frame(width: 8, height: 8)
                        Text(point.name)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartYAxisLabel("compression ratio")
        .chartXScale(type: .log)
        .chartXAxis {
            AxisMarks(preset: .automatic) { v in
                AxisTick()
                AxisGridLine()
                AxisValueLabel {
                    if let ts = v.as(Float.self) {
                        (Text(ts, format: .number) + Text(v.index == 0 ? "s granularity" : ""))
                            .font(.callout)
                    }
                }
            }
        }
        .padding()
    }
}

extension TruncationPoint {
    static let allPoints: [TruncationPoint] = [
        .init(name: "lzfse", thousandth: 8.80, hundredth: 12.48, tenth: 17.69, unit: 26.76),
        .init(name: "simple-8b", thousandth: 6.92, hundredth: 9.60, tenth: 14.07, unit: 14.15),
        .init(name: "gorilla", thousandth: 6.72, hundredth: 7.21, tenth: 11.39, unit: 12.26)
    ]
}

struct TruncationChartView_Previews: PreviewProvider {
    static var previews: some View {
        TruncationChartView()
    }
}
