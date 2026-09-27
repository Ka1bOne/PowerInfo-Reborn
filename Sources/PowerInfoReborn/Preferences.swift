import SwiftUI

enum PopupStyle: String, CaseIterable, Identifiable {
    case classic, island, card

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Classic HUD"
        case .island: return "Island"
        case .card: return "Detail Card"
        }
    }

    var subtitle: String {
        switch self {
        case .classic: return "Rounded square, bottom centre"
        case .island: return "Slides down from the top"
        case .card: return "Full details, top right"
        }
    }

    /// Unscaled size of the transparent canvas each popup is drawn in.
    /// Larger than the popup itself so slide-in motion and shadows are never clipped.
    var canvasSize: CGSize {
        switch self {
        case .classic: return CGSize(width: 300, height: 300)
        case .island: return CGSize(width: 520, height: 170)
        case .card: return CGSize(width: 380, height: 330)
        }
    }
}

enum PopupSize: String, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var scale: CGFloat {
        switch self {
        case .small: return 0.82
        case .medium: return 1
        case .large: return 1.22
        }
    }
}

enum DisplayTarget: String, CaseIterable, Identifiable {
    case primary, mouse, all
    var id: String { rawValue }
    var title: String {
        switch self {
        case .primary: return "Main display"
        case .mouse: return "Display with pointer"
        case .all: return "All displays"
        }
    }
}

enum PopupLook: String, CaseIterable, Identifiable {
    case glass, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .glass: return "Liquid Glass"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum ColorStyle: String, CaseIterable, Identifiable {
    case vibrant, monochrome
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// User settings, persisted to UserDefaults on every change.
@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    @Published var style: PopupStyle = .classic { didSet { save(style.rawValue, "style") } }
    @Published var size: PopupSize = .medium { didSet { save(size.rawValue, "size") } }
    @Published var displayTarget: DisplayTarget = .mouse { didSet { save(displayTarget.rawValue, "displayTarget") } }
    @Published var colorStyle: ColorStyle = .vibrant { didSet { save(colorStyle.rawValue, "colorStyle") } }
    @Published var look: PopupLook = .glass { didSet { save(look.rawValue, "look") } }
    @Published var duration: Double = 2.5 { didSet { save(duration, "duration") } }
    @Published var reduceMotion = false { didSet { save(reduceMotion, "reduceMotion") } }
    @Published var playSound = true { didSet { save(playSound, "playSound") } }
    @Published var soundName = "Pop" { didSet { save(soundName, "soundName") } }
    @Published var lowBatteryThreshold = 20 { didSet { save(lowBatteryThreshold, "lowBatteryThreshold") } }
    @Published var showPercentInMenuBar = false { didSet { save(showPercentInMenuBar, "showPercentInMenuBar") } }
    @Published var enabledEvents: Set<PowerEvent> = Set(PowerEvent.allCases) {
        didSet { save(enabledEvents.map(\.rawValue).sorted(), "enabledEvents") }
    }

    private init() { load() }

    func isEnabled(_ event: PowerEvent) -> Bool { enabledEvents.contains(event) }

    func binding(for event: PowerEvent) -> Binding<Bool> {
        Binding(
            get: { self.enabledEvents.contains(event) },
            set: { on in
                if on { self.enabledEvents.insert(event) } else { self.enabledEvents.remove(event) }
            }
        )
    }

    func resetToDefaults() {
        for key in Self.keys { defaults.removeObject(forKey: key) }
        style = .classic
        size = .medium
        displayTarget = .mouse
        colorStyle = .vibrant
        look = .glass
        duration = 2.5
        reduceMotion = false
        playSound = true
        soundName = "Pop"
        lowBatteryThreshold = 20
        showPercentInMenuBar = false
        enabledEvents = Set(PowerEvent.allCases)
    }

    private static let keys = [
        "style", "size", "displayTarget", "colorStyle", "look", "duration", "reduceMotion",
        "playSound", "soundName", "lowBatteryThreshold", "showPercentInMenuBar", "enabledEvents",
    ]

    private func load() {
        let d = defaults
        if let v = d.string(forKey: "style").flatMap(PopupStyle.init) { style = v }
        if let v = d.string(forKey: "size").flatMap(PopupSize.init) { size = v }
        if let v = d.string(forKey: "displayTarget").flatMap(DisplayTarget.init) { displayTarget = v }
        if let v = d.string(forKey: "colorStyle").flatMap(ColorStyle.init) { colorStyle = v }
        if let v = d.string(forKey: "look").flatMap(PopupLook.init) { look = v }
        if d.object(forKey: "duration") != nil { duration = d.double(forKey: "duration") }
        if d.object(forKey: "reduceMotion") != nil { reduceMotion = d.bool(forKey: "reduceMotion") }
        if d.object(forKey: "playSound") != nil { playSound = d.bool(forKey: "playSound") }
        if let v = d.string(forKey: "soundName") { soundName = v }
        if d.object(forKey: "lowBatteryThreshold") != nil { lowBatteryThreshold = d.integer(forKey: "lowBatteryThreshold") }
        if d.object(forKey: "showPercentInMenuBar") != nil { showPercentInMenuBar = d.bool(forKey: "showPercentInMenuBar") }
        if let v = d.stringArray(forKey: "enabledEvents") { enabledEvents = Set(v.compactMap(PowerEvent.init)) }
    }

    private func save(_ value: Any, _ key: String) { defaults.set(value, forKey: key) }
}
