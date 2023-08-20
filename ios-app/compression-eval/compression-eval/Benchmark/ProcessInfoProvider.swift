//
//  ProcessInfoProvider.swift
//  compression-eval
//
//  Created by Stephen Panaro on 8/13/23.
//

import Foundation
import Combine
#if os(iOS)
import UIKit
#else
import AppKit
#endif

class ProcessInfoProvider: ObservableObject {
    @Published fileprivate(set) var thermalState: ProcessInfo.ThermalState = .nominal
    @Published fileprivate(set) var isLowPowerModeEnabled: Bool = false

    fileprivate var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                self?.thermalState = ProcessInfo.processInfo.thermalState
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name.NSProcessInfoPowerStateDidChange)
            .map { _ in ProcessInfo.processInfo.isLowPowerModeEnabled }
            .sink { [weak self] isEnabled in
                self?.isLowPowerModeEnabled = isEnabled
            }
            .store(in: &cancellables)

#if os(iOS)
        let becomeActiveNotification = UIApplication.didBecomeActiveNotification
#else
        let becomeActiveNotification = NSApplication.didBecomeActiveNotification
#endif

        NotificationCenter.default.publisher(for: becomeActiveNotification)
            .map { _ in ProcessInfo.processInfo }
            .sink { [weak self] processInfo in
                self?.isLowPowerModeEnabled = processInfo.isLowPowerModeEnabled
                self?.thermalState = processInfo.thermalState
            }
            .store(in: &cancellables)
    }

    deinit {
        cancellables.forEach { $0.cancel() }
    }
}
