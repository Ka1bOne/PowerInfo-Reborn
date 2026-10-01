import SwiftUI

/// Something that happened to the Mac's power state and may deserve a popup.
enum PowerEvent: String, CaseIterable, Identifiable {
    case pluggedIn, unplugged, lowPowerOn, lowPowerOff, fullyCharged, lowBattery, slowCharger

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pluggedIn: return "Plugged In"
        case .unplugged: return "Unplugged"
        case .lowPowerOn: return "Low Power On"
        case .lowPowerOff: return "Low Power Off"
        case .fullyCharged: return "Fully Charged"
        case .lowBattery: return "Low Battery"
        case .slowCharger: return "Slow Charger"
        }
    }

    var settingsLabel: String {
        switch self {
        case .pluggedIn: return "Power adapter connected"
        case .unplugged: return "Power adapter disconnected"
        case .lowPowerOn: return "Low Power Mode turned on"
        case .lowPowerOff: return "Low Power Mode turned off"
        case .fullyCharged: return "Battery fully charged"
        case .lowBattery: return "Battery running low"
        case .slowCharger: return "Slow charger connected"
        }
    }

    var symbol: String {
        switch self {
        case .pluggedIn: return "powerplug.fill"
        case .unplugged: return "bolt.slash.fill"
        case .lowPowerOn: return "tortoise.fill"
        case .lowPowerOff: return "hare.fill"
        case .fullyCharged: return "battery.100percent.bolt"
        case .lowBattery: return "battery.25percent"
        case .slowCharger: return "bolt.trianglebadge.exclamationmark.fill"
        }
    }

    func accent(_ style: ColorStyle) -> Color {
        guard style == .vibrant else { return .primary }
        switch self {
        case .pluggedIn, .fullyCharged: return .green
        case .unplugged, .slowCharger: return .orange
        case .lowPowerOn: return .yellow
        case .lowPowerOff: return .cyan
        case .lowBattery: return .red
        }
    }
}

/// A point-in-time reading of the battery and power source.
struct PowerSnapshot: Equatable {
    var hasBattery = false
    var percent = 100
    var isPluggedIn = true
    var isCharging = false
    var isCharged = false
    var lowPowerMode = false
    var minutesToEmpty: Int?
    var minutesToFull: Int?
    var adapterWatts: Int?

    var isFull: Bool { isPluggedIn && (isCharged || percent >= 100) }

    func batteryTint(_ style: ColorStyle) -> Color {
        guard style == .vibrant else { return .primary }
        if lowPowerMode { return .yellow }
        if isPluggedIn { return .green }
        if percent <= 20 { return .red }
        return .primary
    }

    /// Whether the connected adapter supplies less than `watts`.
    func isSlowCharger(below watts: Int) -> Bool {
        guard hasBattery, isPluggedIn, let adapterWatts, adapterWatts > 0 else { return false }
        return adapterWatts < watts
    }

    var sourceText: String {
        guard isPluggedIn else { return "Battery" }
        if let watts = adapterWatts { return "Power Adapter · \(watts)W" }
        return "Power Adapter"
    }

    var statusText: String {
        if !hasBattery { return "No battery" }
        if isPluggedIn {
            if isFull { return "Fully charged" }
            return isCharging ? "Charging" : "Not charging"
        }
        return "Discharging"
    }

    var timeText: String {
        if isPluggedIn {
            if isFull { return "—" }
            if let m = minutesToFull { return "\(Self.format(minutes: m)) until full" }
            return isCharging ? "Calculating…" : "—"
        }
        if let m = minutesToEmpty { return "\(Self.format(minutes: m)) remaining" }
        return "Calculating…"
    }

    static func format(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

/// Everything a popup needs to draw itself.
struct PopupPayload: Equatable {
    var event: PowerEvent
    var snapshot: PowerSnapshot

    var subtitle: String {
        let s = snapshot
        switch event {
        case .pluggedIn:
            if s.isFull { return "Fully charged" }
            if let w = s.adapterWatts { return "Charging · \(w)W" }
            return "Charging"
        case .unplugged:
            return "On battery power"
        case .lowPowerOn:
            return "Saving energy"
        case .lowPowerOff:
            return "Full performance"
        case .fullyCharged:
            return "Ready to unplug"
        case .lowBattery:
            return "Plug in soon"
        case .slowCharger:
            if let w = s.adapterWatts { return "\(w)W · Charging slowly" }
            return "Charging slowly"
        }
    }
}
