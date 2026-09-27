import SwiftUI

/// A detailed card that glides in from the right edge under the menu bar.
struct CardView: View {
    @ObservedObject var model: PopupModel

    var body: some View {
        let visible = model.isVisible
        let motion = !model.reduceMotion
        let snap = model.payload.snapshot

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(model.accent.opacity(0.18))
                    EventIcon(model: model, size: 17)
                }
                .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text("POWERINFO")
                        .font(.system(size: 9.5, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Text(model.payload.event.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                Spacer()
                Text("now")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            if snap.hasBattery {
                HStack(alignment: .center) {
                    PercentText(percent: snap.percent, size: 42, weight: .bold)
                    Spacer()
                    BatteryGauge(
                        percent: snap.percent, tint: model.batteryTint,
                        charging: snap.isPluggedIn && !snap.isFull, active: model.gaugeFilled,
                        width: 70, height: 30
                    )
                }
            }

            VStack(spacing: 7) {
                row("Source", snap.sourceText, "powerplug")
                row("Status", snap.statusText, "bolt")
                row("Low Power Mode", snap.lowPowerMode ? "On" : "Off", "tortoise")
            }
            .padding(12)
            .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(16)
        .frame(width: 320)
        .popupBackground(model.look, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .offset(x: visible || !motion ? 0 : 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, 10)
        .padding(.trailing, 14)
    }

    private func row(_ label: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .contentTransition(.opacity)
        }
        .font(.system(size: 12))
    }
}
