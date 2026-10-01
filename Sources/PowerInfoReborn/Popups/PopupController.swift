import AppKit
import SwiftUI

/// A borderless, click-through panel that floats above everything, on every Space.
final class PopupPanel: NSPanel {
    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        ignoresMouseEvents = true
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct PopupRootView: View {
    @ObservedObject var model: PopupModel
    let style: PopupStyle
    let scale: CGFloat
    let topInset: CGFloat

    var body: some View {
        let base = style.canvasSize
        Group {
            switch style {
            case .classic: ClassicHUDView(model: model)
            case .island: IslandView(model: model, topInset: topInset)
            case .card: CardView(model: model)
            }
        }
        .frame(width: base.width, height: base.height)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: base.width * scale, height: base.height * scale, alignment: .topLeading)
    }
}

/// Shows, updates and dismisses popups.
@MainActor
final class PopupController {
    static let shared = PopupController()

    private let model = PopupModel()
    private var panels: [PopupPanel] = []
    private var shownStyle: PopupStyle = .classic
    private var configKey = ""
    /// Bumped on every show; delayed animation steps from older shows bail out.
    private var generation = 0
    /// False for previews, whose snapshot is made up and shouldn't track the real one.
    private var followsLiveState = false

    /// Called by the power monitor for real events.
    func handle(_ event: PowerEvent, snapshot: PowerSnapshot) {
        let prefs = Preferences.shared
        guard prefs.isEnabled(event) else { return }
        if prefs.playSound { SoundPlayer.play(prefs.soundName) }
        show(PopupPayload(event: event, snapshot: snapshot), live: true)
    }

    /// Keeps a popup that's still on screen in step with the live state. IOKit
    /// reports the plug-in first and the adapter's wattage and charging state a
    /// moment later, which would otherwise leave the popup showing "Not charging".
    func refresh(snapshot: PowerSnapshot) {
        guard followsLiveState, model.phase != .hidden, model.payload.snapshot != snapshot else { return }
        withAnimation(.smooth(duration: 0.35)) { model.payload.snapshot = snapshot }
    }

    /// Shows a popup from the current live state, for the Settings preview buttons.
    func preview(event: PowerEvent? = nil, style: PopupStyle? = nil) {
        let snap = PowerMonitor.shared.snapshot
        let event = event ?? (snap.isPluggedIn ? .pluggedIn : .unplugged)
        var shown = snap
        // Make the preview look like the real event happened.
        switch event {
        case .pluggedIn: shown.isPluggedIn = true; shown.isCharging = !snap.isFull
        case .unplugged: shown.isPluggedIn = false; shown.isCharging = false
        case .lowPowerOn: shown.lowPowerMode = true
        case .lowPowerOff: shown.lowPowerMode = false
        case .fullyCharged: shown.isPluggedIn = true; shown.isCharged = true; shown.percent = 100
        case .lowBattery:
            shown.isPluggedIn = false; shown.isCharging = false
            shown.percent = min(snap.percent, Preferences.shared.lowBatteryThreshold)
        case .slowCharger:
            let threshold = Preferences.shared.slowChargerThreshold
            shown.isPluggedIn = true; shown.isCharging = !snap.isFull
            if !shown.isSlowCharger(below: threshold) { shown.adapterWatts = min(20, threshold - 5) }
        }
        if Preferences.shared.playSound { SoundPlayer.play(Preferences.shared.soundName) }
        show(PopupPayload(event: event, snapshot: shown), style: style)
    }

    private func show(_ payload: PopupPayload, style overrideStyle: PopupStyle? = nil, live: Bool = false) {
        let prefs = Preferences.shared
        followsLiveState = live
        let style = overrideStyle ?? prefs.style
        let screens = targetScreens(prefs.displayTarget)
        let key = ([style.rawValue, prefs.size.rawValue] + screens.map { NSStringFromRect($0.frame) })
            .joined(separator: "|")

        generation += 1
        let gen = generation
        model.colorStyle = prefs.colorStyle
        model.look = prefs.look
        model.reduceMotion = prefs.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if key == configKey && model.phase != .hidden && !panels.isEmpty {
            // Already on screen: morph the content in place rather than re-presenting.
            withAnimation(.smooth(duration: 0.35)) {
                model.payload = payload
                model.phase = .expanded
            }
            fadePanels(to: 1, duration: 0.15)
        } else {
            panels.forEach { $0.orderOut(nil) }
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                model.phase = .hidden
                model.gaugeFilled = false
                model.payload = payload
            }
            panels = screens.map { makePanel(style: style, screen: $0, size: prefs.size) }
            shownStyle = style
            configKey = key
            panels.forEach { $0.orderFrontRegardless() }
            // Let SwiftUI lay out the hidden state for one frame before animating in.
            after(0.03) { [self] in
                guard gen == generation else { return }
                animateIn()
            }
            after(0.2) { [self] in
                guard gen == generation else { return }
                model.gaugeFilled = true
            }
        }

        after(prefs.duration + 0.3) { [self] in hide(gen) }
    }

    private func animateIn() {
        if model.reduceMotion {
            fadePanels(to: 1, duration: 0.2)
            model.phase = .expanded
            return
        }
        switch shownStyle {
        case .island:
            // The island starts fully above the top of the screen, so it needs no
            // fade. It just slides down into place.
            panels.forEach { $0.alphaValue = 1 }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { model.phase = .expanded }
        case .classic, .card:
            fadePanels(to: 1, duration: 0.2)
            withAnimation(.smooth(duration: 0.4)) { model.phase = .expanded }
        }
    }

    private func hide(_ gen: Int) {
        guard gen == generation else { return }
        if model.reduceMotion {
            fadePanels(to: 0, duration: 0.25)
        } else if shownStyle == .island {
            // Slide back up off the top of the screen.
            withAnimation(.spring(response: 0.4, dampingFraction: 1)) { model.phase = .hidden }
        } else {
            fadePanels(to: 0, duration: 0.25)
            withAnimation(.smooth(duration: 0.3)) { model.phase = .hidden }
        }
        after(0.55) { [self] in
            guard gen == generation else { return }
            model.phase = .hidden
            model.gaugeFilled = false
            panels.forEach { $0.orderOut(nil) }
            panels = []
            configKey = ""
        }
    }

    /// Fades whole windows rather than the glass views inside them, which keeps
    /// Liquid Glass from flickering while it appears and disappears.
    private func fadePanels(to alpha: CGFloat, duration: Double) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: alpha > 0 ? .easeOut : .easeIn)
            panels.forEach { $0.animator().alphaValue = alpha }
        }
    }

    private func makePanel(style: PopupStyle, screen: NSScreen, size: PopupSize) -> PopupPanel {
        let scale = size.scale
        let canvas = CGSize(width: style.canvasSize.width * scale, height: style.canvasSize.height * scale)
        let full = screen.frame
        let visible = screen.visibleFrame
        let menuBarHeight = max(0, full.maxY - visible.maxY)

        let origin: CGPoint
        var topInset: CGFloat = 0
        switch style {
        case .classic:
            origin = CGPoint(x: full.midX - canvas.width / 2, y: visible.minY + 40)
        case .island:
            origin = CGPoint(x: full.midX - canvas.width / 2, y: full.maxY - canvas.height)
            topInset = (menuBarHeight + 8) / scale
        case .card:
            origin = CGPoint(x: visible.maxX - canvas.width, y: visible.maxY - canvas.height)
        }

        let panel = PopupPanel(frame: NSRect(origin: origin, size: canvas))
        panel.alphaValue = 0
        let host = NSHostingView(rootView: PopupRootView(model: model, style: style, scale: scale, topInset: topInset))
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: canvas)
        panel.contentView = host
        return panel
    }

    private func targetScreens(_ target: DisplayTarget) -> [NSScreen] {
        let all = NSScreen.screens
        guard let primary = all.first else { return [] }
        switch target {
        case .primary:
            return [primary]
        case .mouse:
            let point = NSEvent.mouseLocation
            return [all.first { NSMouseInRect(point, $0.frame, false) } ?? primary]
        case .all:
            return all
        }
    }

    private func after(_ seconds: Double, _ work: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            work()
        }
    }
}

enum SoundPlayer {
    private static var current: NSSound?

    static var availableSounds: [String] {
        let dir = URL(fileURLWithPath: "/System/Library/Sounds")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path))?
            .map { ($0 as NSString).deletingPathExtension }
            .sorted() ?? []
        return names.isEmpty ? ["Glass", "Hero", "Ping", "Pop", "Purr", "Submarine", "Tink"] : names
    }

    static func play(_ name: String) {
        current?.stop()
        current = NSSound(named: NSSound.Name(name))
        current?.play()
    }
}
