import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            PopupsTab()
                .tabItem { Label("Popups", systemImage: "rectangle.on.rectangle") }
            EventsTab()
                .tabItem { Label("Events", systemImage: "bolt.fill") }
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .padding(.top, 10)
        .frame(width: 580, height: 600)
    }
}

// MARK: - Popups

private struct PopupsTab: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    ForEach(PopupStyle.allCases) { style in
                        StyleOptionCard(style: style, selected: prefs.style == style) {
                            withAnimation(.smooth(duration: 0.25)) { prefs.style = style }
                            PopupController.shared.preview(style: style)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            } header: {
                Text("Popup Style")
            } footer: {
                Text("Click a style to select it and see a preview.")
                    .foregroundStyle(.secondary)
            }

            Section("Appearance") {
                Picker("Size", selection: $prefs.size) {
                    ForEach(PopupSize.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Colours", selection: $prefs.colorStyle) {
                    ForEach(ColorStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Look", selection: $prefs.look) {
                    ForEach(PopupLook.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: prefs.look) { _, _ in PopupController.shared.preview() }
                Toggle("Reduce motion", isOn: $prefs.reduceMotion)
            }

            Section("Behaviour") {
                LabeledContent("Stay on screen for") {
                    HStack {
                        Slider(value: $prefs.duration, in: 1...8, step: 0.5)
                            .frame(width: 180)
                        Text(String(format: "%.1f s", prefs.duration))
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                Picker("Show on", selection: $prefs.displayTarget) {
                    ForEach(DisplayTarget.allCases) { Text($0.title).tag($0) }
                }
            }

            Section {
                HStack {
                    Button("Preview Popup") { PopupController.shared.preview() }
                        .buttonStyle(.borderedProminent)
                    Menu("Preview Event") {
                        ForEach(PowerEvent.allCases) { event in
                            Button(event.title) { PopupController.shared.preview(event: event) }
                        }
                    }
                    .fixedSize()
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct StyleOptionCard: View {
    let style: PopupStyle
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    LinearGradient(
                        colors: [.indigo.opacity(0.85), .purple.opacity(0.7), .teal.opacity(0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    VStack {
                        Rectangle().fill(.white.opacity(0.35)).frame(height: 6)
                        Spacer()
                    }
                    miniature
                }
                .frame(width: 140, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor : .secondary.opacity(0.3), lineWidth: selected ? 3 : 1)
                )

                Text(style.title)
                    .font(.callout.weight(selected ? .semibold : .regular))
                Text(style.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 146)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var miniature: some View {
        let glass = Color.white.opacity(0.7)
        switch style {
        case .classic:
            RoundedRectangle(cornerRadius: 7, style: .continuous).fill(glass)
                .frame(width: 28, height: 28)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 10)
        case .island:
            Capsule().fill(glass)
                .frame(width: 58, height: 12)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 10)
        case .card:
            RoundedRectangle(cornerRadius: 5, style: .continuous).fill(glass)
                .frame(width: 40, height: 30)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 10).padding(.trailing, 6)
        }
    }
}

// MARK: - Events

private struct EventsTab: View {
    @ObservedObject private var prefs = Preferences.shared
    private let sounds = SoundPlayer.availableSounds

    var body: some View {
        Form {
            Section("Show a popup when…") {
                ForEach(PowerEvent.allCases) { event in
                    Toggle(isOn: prefs.binding(for: event)) {
                        Label {
                            Text(event.settingsLabel)
                        } icon: {
                            Image(systemName: event.symbol)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(event.accent(.vibrant))
                        }
                    }
                }
            }

            Section {
                LabeledContent("Warn when battery reaches") {
                    HStack {
                        Slider(
                            value: Binding(
                                get: { Double(prefs.lowBatteryThreshold) },
                                set: { prefs.lowBatteryThreshold = Int($0) }
                            ),
                            in: 5...50, step: 5
                        )
                        .frame(width: 160)
                        Text("\(prefs.lowBatteryThreshold)%")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                .disabled(!prefs.isEnabled(.lowBattery))
            } header: {
                Text("Low Battery")
            }

            Section("Sound") {
                Toggle("Play a sound with popups", isOn: $prefs.playSound)
                Picker("Sound", selection: $prefs.soundName) {
                    ForEach(sounds, id: \.self) { Text($0).tag($0) }
                }
                .disabled(!prefs.playSound)
                .onChange(of: prefs.soundName) { _, name in SoundPlayer.play(name) }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var power = PowerMonitor.shared
    @ObservedObject private var login = LaunchAtLogin.shared

    var body: some View {
        Form {
            Section("Startup & Menu Bar") {
                Toggle("Launch at login", isOn: Binding(
                    get: { login.isEnabled },
                    set: { login.set($0) }
                ))
                if let loginError = login.error {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                Toggle("Show battery percentage next to PIR", isOn: $prefs.showPercentInMenuBar)
            }

            Section("Current Status") {
                let s = power.snapshot
                if s.hasBattery {
                    LabeledContent("Battery") {
                        HStack(spacing: 8) {
                            PercentText(percent: s.percent, size: 13, weight: .medium)
                            BatteryGauge(
                                percent: s.percent, tint: s.batteryTint(.vibrant),
                                charging: s.isPluggedIn && !s.isFull, active: true,
                                width: 30, height: 14
                            )
                        }
                    }
                    LabeledContent("Status", value: s.statusText)
                    LabeledContent("Time", value: s.timeText)
                } else {
                    LabeledContent("Battery", value: "None detected")
                }
                LabeledContent("Power source", value: s.sourceText)
                LabeledContent("Low Power Mode", value: s.lowPowerMode ? "On" : "Off")
            }

            Section {
                Button("Reset All Settings", role: .destructive) { prefs.resetToDefaults() }
            }
        }
        .formStyle(.grouped)
    }
}

/// Wraps SMAppService so the toggle reflects the real login-item state.
@MainActor
final class LaunchAtLogin: ObservableObject {
    static let shared = LaunchAtLogin()

    @Published private(set) var isEnabled = SMAppService.mainApp.status == .enabled
    @Published private(set) var error: String?

    func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            error = nil
        } catch {
            self.error = "Couldn't update login item: \(error.localizedDescription)"
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
