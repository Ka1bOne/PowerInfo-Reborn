import Foundation
import IOKit.ps

/// Watches IOKit power-source notifications and Low Power Mode, and turns
/// state changes into `PowerEvent`s.
@MainActor
final class PowerMonitor: ObservableObject {
    static let shared = PowerMonitor()

    @Published private(set) var snapshot = PowerSnapshot()

    var onEvent: ((PowerEvent, PowerSnapshot) -> Void)?

    private var runLoopSource: CFRunLoopSource?
    private var refreshTimer: Timer?
    private var lowBatteryWarned = false
    private var slowChargerWarned = false

    func start() {
        snapshot = Self.read()
        lowBatteryWarned = !snapshot.isPluggedIn && snapshot.percent <= Preferences.shared.lowBatteryThreshold
        slowChargerWarned = snapshot.isSlowCharger(below: Preferences.shared.slowChargerThreshold)

        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.refresh() }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }

        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }

        // Keeps time-remaining estimates fresh between IOKit notifications.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func refresh() {
        let old = snapshot
        let new = Self.read()
        snapshot = new

        let prefs = Preferences.shared

        // Several things can change at once (e.g. unplugging below the low-battery
        // threshold); only the most important one that's switched on gets a popup.
        var events: [PowerEvent] = []
        // The adapter's wattage often arrives a moment after the plug-in itself,
        // so this is tracked separately from the plugged-in change.
        if !new.isSlowCharger(below: prefs.slowChargerThreshold) {
            slowChargerWarned = false
        } else if !slowChargerWarned {
            slowChargerWarned = true
            events.append(.slowCharger)
        }
        if old.isPluggedIn != new.isPluggedIn {
            events.append(new.isPluggedIn ? .pluggedIn : .unplugged)
        }
        if old.lowPowerMode != new.lowPowerMode {
            events.append(new.lowPowerMode ? .lowPowerOn : .lowPowerOff)
        }
        if new.hasBattery && new.isFull && !old.isFull && old.isPluggedIn {
            events.append(.fullyCharged)
        }
        let threshold = prefs.lowBatteryThreshold
        if new.isPluggedIn || new.percent > threshold {
            lowBatteryWarned = false
        } else if new.hasBattery && !lowBatteryWarned {
            lowBatteryWarned = true
            events.append(.lowBattery)
        }

        if let event = events.first(where: prefs.isEnabled) { onEvent?(event, new) }
    }

    static func read() -> PowerSnapshot {
        var s = PowerSnapshot()
        s.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return s }

        if let providing = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String? {
            s.isPluggedIn = providing == kIOPSACPowerValue
        }

        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  desc[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
            else { continue }

            s.hasBattery = true
            let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            s.percent = max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : current
            s.isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            s.isCharged = desc[kIOPSIsChargedKey] as? Bool ?? false
            if let state = desc[kIOPSPowerSourceStateKey] as? String {
                s.isPluggedIn = state == kIOPSACPowerValue
            }
            if let t = desc[kIOPSTimeToEmptyKey] as? Int, t > 0 { s.minutesToEmpty = t }
            if let t = desc[kIOPSTimeToFullChargeKey] as? Int, t > 0 { s.minutesToFull = t }
        }

        if s.isPluggedIn,
           let details = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any] {
            s.adapterWatts = details[kIOPSPowerAdapterWattsKey] as? Int
        }
        return s
    }
}
