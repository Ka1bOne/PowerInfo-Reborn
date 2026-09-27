import SwiftUI

/// Pill-shaped popup that slides down from the top of the screen to
/// rest just under the menu bar, then slides back up when it's done.
struct IslandView: View {
    @ObservedObject var model: PopupModel
    /// Distance from the top of the canvas to where the island rests.
    var topInset: CGFloat

    private static let size = CGSize(width: 390, height: 70)

    var body: some View {
        let hidden = model.phase == .hidden && !model.reduceMotion
        let snap = model.payload.snapshot

        HStack(spacing: 12) {
            ZStack {
                Circle().fill(model.accent.opacity(0.18))
                EventIcon(model: model, size: 21)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 1) {
                Text(model.payload.event.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(model.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)

            Spacer(minLength: 8)

            if snap.hasBattery {
                HStack(spacing: 8) {
                    PercentText(percent: snap.percent, size: 16)
                    BatteryGauge(
                        percent: snap.percent, tint: model.batteryTint,
                        charging: snap.isPluggedIn && !snap.isFull, active: model.gaugeFilled,
                        width: 38, height: 18
                    )
                }
            }
        }
        .padding(.leading, 13)
        .padding(.trailing, 20)
        .frame(width: Self.size.width, height: Self.size.height)
        .popupBackground(model.look, in: Capsule(style: .continuous))
        // Hidden: parked entirely above the top edge of the screen (plus room for the shadow).
        .offset(y: hidden ? -(topInset + Self.size.height + 24) : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, topInset)
    }
}
