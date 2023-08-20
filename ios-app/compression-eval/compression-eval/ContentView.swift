//
//  ContentView.swift
//  compression-eval
//
//  Created by Stephen Panaro on 8/12/23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: BenchmarkContentView()) {
                    Image(systemName: "stopwatch.fill")
                        .foregroundStyle(.teal)
                    Text("Benchmarks")
                }
                NavigationLink(destination: ChartsView()) {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundStyle(.indigo)
                    Text("Comparisons")
                }
            }
            .navigationTitle(Text("Compression"))
        }
    }
}

struct BenchmarkContentView: View {
    var body: some View {
        VStack(alignment: .leading) {
#if os(iOS)
            Spacer()
#endif
            // A little unorthodox but I like bottom-oriented UI.
            Text("Benchmark")
                .font(.title.weight(.bold))
            BenchmarkView()
        }
        .padding()
    }
}

struct ChartsView: View {
    @Environment(\.colorScheme) var colorScheme

    var backgroundColor: Color {
        colorScheme == .dark ? Color.clear : Color.chartBackground
    }

    var body: some View {
        List {
            Text("Note: Drag n Drop to export. Export background color updates based on the system Light/Dark mode.")
                .font(.callout)
            ExportableChartView(size: .init(width: 600, height: 370)) {
                DistributionChartView()
                    .background(backgroundColor)
                    .aspectRatio(1.618, contentMode: .fit)
            }
            ExportableChartView(size: .init(width: 600, height: 370)) {
                CompressionChartView(includeStacked: false)
                    .background(backgroundColor)
                    .aspectRatio(1.618, contentMode: .fit)
            }
            ExportableChartView(size: .init(width: 600, height: 370)) {
                CompressionChartView(includeStacked: true)
                    .background(backgroundColor)
                    .aspectRatio(1.618, contentMode: .fit)
            }
            ExportableChartView(size: .init(width: 600, height: 370)) {
                TruncationChartView()
                    .background(backgroundColor)
                    .aspectRatio(1.618, contentMode: .fit)
            }
        }
        // Re-render snapshots on color change.
        .id(colorScheme)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
