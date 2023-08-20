//
//  DistributionChartView.swift
//  compression-eval
//
//  Created by Stephen Panaro on 8/13/23.
//

import SwiftUI
import Charts

extension Method {
    static let appleMethods = [Method.lzma, Method.lzfse, Method.zlib]
    var isApple: Bool {
        Self.appleMethods.contains(self)
    }
}

struct DistributionChartView: View {
    let sortedRuns: [Run]
    let appleAverages: [(Method, Measurement<UnitDuration>)]
    let closestRuns: [Run] // Non-Apple Runs closest to the Apple Runs.

    init() {
        self.sortedRuns = Self.computeSortedRuns()
        self.appleAverages = Self.computeAppleAverages()
        self.closestRuns = Self.computeClosestRuns(to: self.appleAverages)
    }

    static func computeSortedRuns(runs: [Run] = Run.all) -> [Run] {
        runs.sorted(by: {
            $0.method == $1.method ?
            $0.os.rawValue < $1.os.rawValue :
            $0.method.rawValue < $1.method.rawValue
        })
    }

    static func computeAppleAverages(runs: [Run] = Run.all) -> [(Method, Measurement<UnitDuration>)] {
        Dictionary(grouping: Run.all, by: { $0.method })
            .filter { $0.key.isApple }
            .mapValues { runs -> Double in
                runs
                    .map { run in
                        run.meanDuration.measurement.converted(to: UnitDuration.milliseconds).value }
                    .mean
            }
            .mapValues { Measurement(value: $0, unit: .milliseconds)}
            .map {
                ($0, $1)
            }
            .sorted(by: { $0.1 < $1.1 })
    }

    // Compute the list of non-Apple method runs (per method and OS) that are the closest
    // to the Apple methods.
    static func computeClosestRuns(
        runs: [Run] = Run.all,
        to appleAverages: [(Method, Measurement<UnitDuration>)]) -> [Run] {
            let appleMethodToDuration = Dictionary(appleAverages, uniquingKeysWith: { a,b in a })
            let byOtherMethod = Dictionary(grouping: runs, by: { $0.segment })
                .filter { !$0.key.method.isApple }
            return byOtherMethod
                .flatMap { _, runs in
                    return appleMethodToDuration.values.flatMap {
                        closestRuns(to: $0, from: runs)
                    }
                }
        }

    // Returns a list of 0 to 2 elements: one that is the closest but less than duration
    // and the other that is the closest but above.
    static func closestRuns(to duration: Measurement<UnitDuration>, from runs: [Run]) -> [Run] {
        let sorted = runs.sorted(by: { $0.meanDuration < $1.meanDuration })
        let lastBelow = sorted.last { run in
            run.meanDuration.measurement <= duration
        }
        let firstAfter = sorted.first { run in
            run.meanDuration.measurement >= duration
        }
        if lastBelow?.method == firstAfter?.method && lastBelow?.level == firstAfter?.level {
            return [firstAfter].compactMap { $0 }
        }

        return [lastBelow, firstAfter].compactMap { $0 }
    }

    var body: some View {
        Chart {
            ForEach(appleAverages.map { $0 }, id: \.0) { method, average in
                RuleMark(x: .value(method.rawValue, average.milliseconds))
                    .annotation(position: .bottom, alignment: .center) {
                        Text("\(method.rawValue)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.orange.opacity(0.9))
                    .lineStyle(.init(lineWidth: 1))
//                    .foregroundStyle(by: .value("method", method.rawValue))
            }

            ForEach(sortedRuns.filter { !$0.method.isApple }) { run in
                PointMark(
                    x: .value("speed", run.meanDuration.measurement.milliseconds),
                    y: .value("segment", run.segment)
                )
                .foregroundStyle(.purple.opacity(0.3))
                .annotation(position: .top, spacing: 3) {
                    levelAnnotation(run: run)
                }
            }
        }
        .chartYAxis {
            AxisMarks(preset: .automatic) { _ in
                AxisTick()
                AxisGridLine()
                AxisValueLabel()
                    .font(.callout)
            }
        }
        .chartXAxis {
            AxisMarks(preset: .automatic) { v in
                AxisTick()
                AxisGridLine()
                AxisValueLabel {
                    if let ts = v.as(Double.self) {
                        (Text(ts, format: .number) + Text(v.index == 0 ? " ms" : ""))
                            .font(.callout)
                    }
                }
            }

        }
//        .chartYAxis {
//            AxisMarks(preset: .automatic) { v in
//                AxisTick()
//                AxisGridLine()
//                AxisValueLabel(orientation: .horizontal)
//            }
//        }
        .chartXScale(type: .log)
        .padding()
    }

    @ViewBuilder
    func levelAnnotation(run: Run) -> some View {
        if let level = run.level,
           closestRuns.contains(where: {
               $0.segment == run.segment && $0.level == run.level })
        {
            VStack(spacing: 1) {
                Text("\(level)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Rectangle()
                    .frame(width: 1, height: 4)
                    .foregroundColor(.purple.opacity(0.5))
            }
        }
        else {
            EmptyView()
        }
    }
}

extension Measurement where UnitType == UnitDuration {
    var milliseconds: Double {
        converted(to: .milliseconds).value
    }
}

extension Array where Element == Double {
    var mean: Double {
        reduce(0.0, +) / Double(count)
    }
}

struct Segment: Plottable, Hashable {
    let method: Method
    let os: OS

    var primitivePlottable: String {
        "\(method.rawValue) - \(os.rawValue)"
    }

    init?(primitivePlottable: String) {
        let parts = primitivePlottable.split(separator: " - ")
        if
            let method = Method(rawValue: String(parts[0])),
            let os = OS(rawValue: String(parts[1]))
        {
            self.method = method
            self.os = os
        }
        else {
            return nil
        }
    }

    init(method: Method, os: OS) {
        self.method = method
        self.os = os
    }
}

extension Run {
    var segment: Segment {
        .init(method: method, os: os)
    }
}

struct DistributionChartView_Previews: PreviewProvider {
    static var previews: some View {
        DistributionChartView()
    }
}
