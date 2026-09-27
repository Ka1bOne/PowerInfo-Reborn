import SwiftUI

/// Rounded square at the bottom centre of the screen, like the system volume HUD.
struct ClassicHUDView: View {
    @ObservedObject var model: PopupModel

    var body: some View {
        let visible = model.isVisible
        let motion = !model.reduceMotion
        let snap = model.payload.snapshot

        VStack(spacing: 10) {
            EventIcon(model: model, size: 56)
                .frame(height: 70)

            VStack(spacing: 2) {
                Text(model.payload.event.title)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.opacity)
                Text(model.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            HStack(spacing: 8) {
                BatteryGauge(
                    percent: snap.percent, tint: model.batteryTint,
                    charging: snap.isPluggedIn && !snap.isFull, active: model.gaugeFilled,
                    width: 50, height: 23
                )
                PercentText(percent: snap.percent, size: 17)
            }
            .opacity(snap.hasBattery ? 1 : 0)
        }
        .padding(18)
        .frame(width: 210, height: 210)
        .popupBackground(model.look, in: RoundedRectangle(cornerRadius: 44, style: .continuous))
        .scaleEffect(visible || !motion ? 1 : 0.94, anchor: .bottom)
        .offset(y: visible || !motion ? 0 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 36)
    }
}
