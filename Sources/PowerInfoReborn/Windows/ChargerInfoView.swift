import AppKit
import SwiftUI

enum ChargerInfoTab: String, CaseIterable, Identifiable {
    case charger, power, battery
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// The popover shown when the menu bar item is clicked: everything known
/// about the connected charger, live power flow and the battery.
struct ChargerInfoView: View {
    @ObservedObject var model: ChargerInfoModel
    @ObservedObject private var monitor = PowerMonitor.shared
    @AppStorage("chargerInfoTab") private var tab: ChargerInfoTab = .charger

    var onSettings: () -> Void
    var onAbout: () -> Void
    var onQuit: () -> Void

    var body: some View {
        let info = model.info
        let snap = monitor.snapshot

        VStack(alignment: .leading, spacing: 12) {
            header(info, snap)
            tiles(info, snap)

            Picker("", selection: $tab) {
                ForEach(ChargerInfoTab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch tab {
            case .charger: chargerTab(info)
            case .power: section(info.powerItems(snap))
            case .battery:
                if snap.hasBattery {
                    section(info.batteryItems(snap))
                } else {
                    placeholder("battery.0percent", "No battery", "This Mac doesn't have a battery.")
                }
            }

            footer(info, snap)
        }
        .padding(14)
        .frame(width: 360)
        .animation(.smooth(duration: 0.25), value: tab)
        .animation(.smooth(duration: 0.25), value: info.connected)
    }

    // MARK: Header

    private func header(_ info: ChargerInfo, _ snap: PowerSnapshot) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill((info.connected ? Color.green : Color.orange).opacity(0.18))
                    Image(systemName: info.connected ? (info.isWireless == true ? "wave.3.right" : "powerplug.fill") : "bolt.slash.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(info.connected ? Color.green : Color.orange)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 1) {
                    Text(info.connected ? "CHARGER CONNECTED" : "ON BATTERY")
                        .font(.system(size: 9.5, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Text(info.connected ? info.displayName : "No charger connected")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if info.connected, let sub = [info.manufacturer, info.typeText].compactMap({ $0 }).joined(separator: " · ").nilIfEmpty {
                        Text(sub)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                if info.connected, let watts = info.ratedWatts {
                    Text("\(watts)W")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(watts)))
                }
            }

            if snap.hasBattery {
                HStack(spacing: 10) {
                    BatteryGauge(
                        percent: snap.percent, tint: snap.batteryTint(Preferences.shared.colorStyle),
                        charging: snap.isPluggedIn && !snap.isFull, active: true, width: 40, height: 18
                    )
                    PercentText(percent: snap.percent, size: 15)
                    Spacer()
                    Text("\(snap.statusText) · \(snap.timeText)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Live tiles

    private func tiles(_ info: ChargerInfo, _ snap: PowerSnapshot) -> some View {
        let values = tileValues(info)
        return HStack(spacing: 8) {
            ForEach(values, id: \.0) { label, value, symbol in
                VStack(alignment: .leading, spacing: 3) {
                    Label(label, systemImage: symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
        }
        .animation(.smooth(duration: 0.4), value: values.map(\.1))
    }

    private func tileValues(_ info: ChargerInfo) -> [(String, String, String)] {
        func text(_ value: Int?, _ format: (Int) -> String) -> String { value.map(format) ?? "—" }
        if info.connected {
            return [
                ("Input", text(info.inputMilliwatts, Units.watts), "bolt.fill"),
                ("Voltage", text(info.inputMillivolts ?? info.adapterMillivolts) { Units.volts($0) }, "bolt.horizontal.fill"),
                ("Current", text(info.inputMilliamps ?? info.adapterMilliamps, Units.amps), "gauge.with.dots.needle.67percent"),
            ]
        }
        let draw = info.systemLoadMilliwatts ?? info.batteryMilliwatts.map(abs)
        return [
            ("Draw", text(draw, Units.watts), "laptopcomputer"),
            ("Voltage", text(info.batteryMillivolts) { Units.volts($0) }, "bolt.horizontal.fill"),
            ("Current", text(info.batteryMilliamps.map(abs), Units.amps), "gauge.with.dots.needle.67percent"),
        ]
    }

    // MARK: Tabs

    @ViewBuilder
    private func chargerTab(_ info: ChargerInfo) -> some View {
        if !info.connected {
            placeholder("powerplug", "No charger connected", "Plug in a charger to see its name, power profiles, serial number and more.")
        } else {
            VStack(alignment: .leading, spacing: 10) {
                section(info.chargerItems)
                if !info.profiles.isEmpty {
                    profiles(info)
                }
            }
        }
    }

    private func profiles(_ info: ChargerInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("POWER PROFILES")
                .font(.system(size: 9.5, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(spacing: 5) {
                ForEach(info.profiles) { p in
                    let active = p.id == info.activeProfile
                    HStack(spacing: 8) {
                        Image(systemName: active ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(active ? Color.green : Color.secondary.opacity(0.5))
                            .frame(width: 16)
                        Text(p.voltageText)
                            .fontWeight(.medium)
                            .monospacedDigit()
                        if p.kind != .fixed {
                            Text(p.kind.rawValue)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.primary.opacity(0.1), in: Capsule())
                        }
                        Spacer()
                        if let current = p.currentText {
                            Text(current)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Text("\(p.watts) W")
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .frame(minWidth: 44, alignment: .trailing)
                    }
                    .font(.system(size: 12))
                }
            }
            .padding(12)
            .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func section(_ items: [DetailItem]) -> some View {
        VStack(spacing: 7) {
            ForEach(items) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Text(item.label)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    Spacer(minLength: 12)
                    Text(item.value)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                        .contentTransition(.numericText())
                }
                .font(.system(size: 12))
            }
        }
        .padding(12)
        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func placeholder(_ symbol: String, _ title: String, _ message: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 12)
        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Footer

    private func footer(_ info: ChargerInfo, _ snap: PowerSnapshot) -> some View {
        HStack(spacing: 4) {
            footerButton(model.copied ? "Copied" : "Copy", model.copied ? "checkmark" : "doc.on.doc") {
                model.copyReport(snap)
            }
            Spacer()
            footerButton("Settings", "gearshape", action: onSettings)
            footerButton("About", "info.circle", action: onAbout)
            footerButton("Quit", "power", action: onQuit)
        }
    }

    private func footerButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .medium))
                .fixedSize()
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(title == "Copy" ? "Copy all details as text" : title)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
