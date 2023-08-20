//
//  BenchmarkView.swift
//  compression-eval
//
//  Created by Stephen Panaro on 8/12/23.
//

import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct BenchmarkParams: Equatable, Hashable {
    let method: Method
    let qos: DispatchQoS.QoSClass
    let level: Int?
}

struct BenchmarkView: View {
    static let runner = Runner()
    static let unsetLevel = Int.min

    @State var processInfo = ProcessInfoProvider()

    @State var method: Method = .allCases.last!
    @State var qos: DispatchQoS.QoSClass = .default
    @State var level: Int = Self.unsetLevel // Cannot be Optional. Picker doesn't like it.

    @State var paramResults = [BenchmarkParams: Results]()
    @State var runStartedAt: ContinuousClock.Instant? = nil

    var running: Bool { runStartedAt != nil }
    var params: BenchmarkParams {
        .init(method: method,
              qos: qos,
              level: level == Self.unsetLevel ? nil : level)
    }

    var pickerLevels: ClosedRange<Int>? {
        if let levels = method.levels, levels.contains(level) {
            return levels
        }
        return nil
    }

    var results: Results? {
        paramResults[params]
    }

    var body: some View {
        VStack {
            systemStateView
            Group {
                noResultsView
                resultsView
            }
            .padding(20)
            .background(Color.secondarySystemBackground,
                        in: RoundedRectangle(cornerRadius: 12))
            configView
        }
    }

    var systemStateView: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack {
                Text("Device Temperature")
                    .padding(0)
                Image(systemName: thermometerSystemName)
                    .foregroundColor(thermometerColor)
            }
            .padding(.trailing, 8)

            lowPowerModeView
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    var thermometerSystemName: String {
        switch processInfo.thermalState {
        case .nominal:
            return "checkmark.circle"
        case .fair:
            return "thermometer.low"
        case .serious:
            return "thermometer.medium"
        case .critical:
            return "thermometer.high"
        @unknown default:
            return "thermometer.low"
        }
    }

    var thermometerColor: Color {
        switch processInfo.thermalState {
        case .nominal:
            return .secondary
        case .fair:
            return .yellow
        case .serious:
            return .orange
        case .critical:
            return .red
        @unknown default:
            return .secondary
        }
    }

    @ViewBuilder var lowPowerModeView: some View {
        if processInfo.isLowPowerModeEnabled {
            HStack {
                Text("Low Power Mode")
                Image(systemName: "bolt.slash.fill")
                    .foregroundStyle(.yellow)
            }
        }
        else {
            EmptyView()
        }
    }

    // MARK: Config Section

    var configView: some View {
        configStack
            .disabled(running)
            .onAppear {
                level = method.levels?.lowerBound ?? Self.unsetLevel
            }
            .onChange(of: method) { newMethod in
                level = newMethod.levels?.lowerBound ?? Self.unsetLevel
            }
    }

    var configStack: some View {
#if os(iOS)
        HStack(alignment: .bottom, spacing: 0) {
            methodPicker
                .padding(.leading, -8)
            levelPicker
            qosPicker
            Spacer()
            runButton
        }
#else
        HStack(alignment: .bottom) {
            methodPicker
            levelPicker
            qosPicker
            Spacer()
            runButton
        }
#endif
    }

    @ViewBuilder var levelPicker: some View {
        if let levels = pickerLevels {
            LabeledPicker("Level") {
                Picker("Level", selection: $level) {
                    ForEach(levels, id: \.self) {
                        Text("\($0)")
                    }
                }
                .pickerStyle(.menu)
            }
        }
        else {
            EmptyView()
        }
    }

    var qosPicker: some View {
        LabeledPicker("QoS") {
            Picker("QoS", selection: $qos) {
                ForEach(DispatchQoS.QoSClass.allCases, id: \.self) {
                    Text($0.name)
                }
            }
            .pickerStyle(.menu)
        }
    }

    var methodPicker: some View {
        LabeledPicker("Method") {
            Picker("Method", selection: $method) {
                ForEach(Method.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }
            .pickerStyle(.menu)
        }
    }

    var runButton: some View {
        Button(action: runBenchmark) {
            Image(systemName: running ? "hourglass" : "play.fill")
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: Results Section

    @ViewBuilder var noResultsView: some View {
        if results == nil {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    if let runStartedAt = runStartedAt {
                        StopwatchView(startedAt: runStartedAt)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(running ? "Running..." : "Run to see results.")
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder var resultsView: some View {
        if let results = results {
            VStack {
                HStack {
                    Text("Recording")
                    Spacer()
                    Text("Time")
                }
                .foregroundStyle(.tertiary)
                .font(.caption)
                .padding(.bottom, 4)

                ForEach(results.byFileName.map { $0 }, id: \.0) { name, result in
                    HStack(alignment: .center) {
                        Text(name)
                            .foregroundStyle(.secondary)
                        Text("× \(result.iterationCount)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(result.duration.formatted(.fractionalMilliseconds))
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                }

                HStack {
                    Text("Average")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(results.mean.formatted(.fractionalMilliseconds))
                        .foregroundStyle(.primary)
                }
                .fontWeight(.medium)
                .padding(.top, 4)

                Button(action: {
                    copyResultsCSV(results)
                }) {
                    HStack {
                        Spacer()
                        Text("Copy")
                        Spacer()
                    }
                }
                .buttonStyle(.bordered)
                .tint(.cyan)
            }
            .font(.callout)
        } else {
            EmptyView()
        }
    }

    // MARK: Actions

    func runBenchmark() {
        runStartedAt = .now
        paramResults[params] = nil

        // Access on Main thread.
        let method = method
        let level = level

        DispatchQueue.global(qos: qos).async {
            let results = Self.runner.run(method, level: level)

            DispatchQueue.main.async {
                runStartedAt = nil
                paramResults[params] = results
            }
        }
    }

    func copyResultsCSV(_ results: Results) {
        let style = Duration.UnitsFormatStyle.units(allowed: [.microseconds])

        let cols = (results.byFileName.map {
            $0.1.duration.formatted(style)
        } + [results.mean.formatted(style)])
            .map { String($0.split(separator: " ").first!) }

        let csv = cols.joined(separator: "\t")
        #if os(iOS)
        UIPasteboard.general.string = csv
        #else
        NSPasteboard.general.prepareForNewContents(with: [.currentHostOnly])
        NSPasteboard.general.setString(csv, forType: .string)
        #endif
    }
}

extension FormatStyle where Self == Duration.UnitsFormatStyle {
    static var fractionalMilliseconds: Duration.UnitsFormatStyle {
        .units(allowed: [.milliseconds], fractionalPart: .show(length: 3))
    }
}

// Picker that shows a label on iOS and macOS.
struct LabeledPicker<PickerContent: View>: View {
    let title: String
    let picker: PickerContent

    init(_ title: String,
         @ViewBuilder picker: () -> PickerContent) {
        self.title = title
        self.picker = picker()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: -8) {
            picker

#if os(iOS)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 12)
#endif
        }

    }
}

struct StopwatchView: View {
    let startedAt: ContinuousClock.Instant
    let units: Set<Duration.UnitsFormatStyle.Unit> = [.seconds]

    @State var now: ContinuousClock.Instant = .now
    @State private var displayLink = DisplayLink()

    var elapsed: Duration {
        startedAt.duration(to: now)
    }

    var body: some View {
        Text(elapsed.formatted(.units(allowed: units, width: .narrow, fractionalPart: .show(length: 3))))
            .onAppear {
                displayLink.start { _ in now = .now}
            }
            .onDisappear { displayLink.stop() }
            .fontDesign(.monospaced)
    }
}

// https://stackoverflow.com/questions/67658580
class DisplayLink: NSObject, ObservableObject {
    private var update: ((TimeInterval) -> Void)?

#if os(iOS)
    private var displaylink: CADisplayLink?

    func start(update: @escaping (TimeInterval) -> Void) {
        self.update = update
        displaylink = CADisplayLink(target: self, selector: #selector(frame))
        displaylink?.add(to: .current, forMode: .default)
    }

    func stop() {
        displaylink?.remove(from: .current, forMode: .default)
        update = nil
    }

    @objc func frame(displaylink: CADisplayLink) {
        let frameDuration = displaylink.targetTimestamp - displaylink.timestamp
        update?(frameDuration)
    }
#else
    var timer: Timer? = nil
    func start(update: @escaping (TimeInterval) -> Void) {
        self.update = update
        timer = Timer.scheduledTimer(withTimeInterval: 0.001, repeats: true) { t in
            update(t.timeInterval)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        update = nil
    }

#endif
}

extension DispatchQoS.QoSClass {
    static var allCases: [DispatchQoS.QoSClass] {
        [
            .`default`,
            .background,
            .utility,
            .userInitiated,
            .userInteractive,
            .unspecified,
        ]
    }

    var name: String {
        switch self {
        case .background: return "Background"
        case .utility: return "Utility"
        case .`default`: return "Default"
        case .userInitiated: return "User Initiated"
        case .userInteractive: return "User Interactive"
        case .unspecified: return "Unspecified"
        @unknown default:
            return "Unknown"
        }
    }
}

extension Color {
    static var secondarySystemBackground: Color {
#if os(macOS)
        Color(nsColor: .controlBackgroundColor)
#else
        Color(uiColor: .secondarySystemBackground)
#endif
    }
}

struct BenchmarkView_Previews: PreviewProvider {
    static var previews: some View {
        BenchmarkView()
            .padding()
    }
}
