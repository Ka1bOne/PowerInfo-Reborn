import SwiftUI

extension View {
    /// Liquid Glass on macOS 26+, falling back to a translucent material on older systems.
    @ViewBuilder
    func liquidGlass(in shape: some Shape, tint: Color? = nil) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.tint(tint), in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.22), lineWidth: 0.6))
                .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
        }
    }
}

extension View {
    /// The popup's background for the chosen look. Light and Dark are solid and
    /// force their colour scheme so text stays readable on them.
    @ViewBuilder
    func popupBackground(_ look: PopupLook, in shape: some InsettableShape) -> some View {
        switch look {
        case .glass:
            self.liquidGlass(in: shape)
        case .light:
            self
                .environment(\.colorScheme, .light)
                .background(shape.fill(Color(white: 0.98)))
                .overlay(shape.strokeBorder(.black.opacity(0.08), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.18), radius: 14, y: 5)
        case .dark:
            self
                .environment(\.colorScheme, .dark)
                .background(shape.fill(.black))
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 14, y: 5)
        }
    }
}

/// Shared state the popup views observe. Phases drive every animation.
@MainActor
final class PopupModel: ObservableObject {
    @Published var payload = PopupPayload(event: .pluggedIn, snapshot: PowerSnapshot())
    @Published var phase: PopupPhase = .hidden
    @Published var colorStyle: ColorStyle = .vibrant
    @Published var reduceMotion = false
    @Published var look: PopupLook = .glass
    /// Fills the battery gauges. Set on its own, after the popup starts moving,
    /// so the gauge's fill animation never picks up the slide.
    @Published var gaugeFilled = false

    var isVisible: Bool { phase != .hidden }
    var subtitle: String { payload.subtitle }
    var accent: Color { payload.event.accent(colorStyle) }
    var batteryTint: Color { payload.snapshot.batteryTint(colorStyle) }
}

enum PopupPhase {
    /// Off screen / transparent.
    case hidden
    /// Fully presented.
    case expanded
}

/// A drawn battery whose fill animates to the current level.
struct BatteryGauge: View {
    var percent: Int
    var tint: Color
    var charging: Bool
    var active: Bool
    var width: CGFloat = 46
    var height: CGFloat = 21

    var body: some View {
        let radius = height * 0.32
        let level = active ? CGFloat(min(max(percent, 0), 100)) / 100 : 0
        HStack(spacing: height * 0.08) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.primary.opacity(0.4), lineWidth: max(1, height * 0.06))
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: max(1, radius - height * 0.12), style: .continuous)
                        .fill(tint.gradient)
                        .frame(width: max(height * 0.2, geo.size.width * level))
                        .opacity(level > 0 ? 1 : 0)
                }
                .padding(height * 0.12)
                if charging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: height * 0.58, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 1.5)
                        .frame(maxWidth: .infinity)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: width, height: height)
            RoundedRectangle(cornerRadius: height * 0.1, style: .continuous)
                .fill(.primary.opacity(0.4))
                .frame(width: height * 0.12, height: height * 0.36)
        }
        // `active` must never flip in the same transaction that moves the popup,
        // or this animation would drag the gauge behind it (see PopupModel.gaugeFilled).
        .animation(.smooth(duration: 0.7), value: level)
        .animation(.smooth(duration: 0.3), value: charging)
    }
}

/// The large SF Symbol for an event; swaps smoothly when the event changes.
struct EventIcon: View {
    @ObservedObject var model: PopupModel
    var size: CGFloat

    var body: some View {
        Image(systemName: model.payload.event.symbol)
            .font(.system(size: size, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(model.accent)
            .contentTransition(.symbolEffect(.replace))
    }
}

struct PercentText: View {
    var percent: Int
    var size: CGFloat
    var weight: Font.Weight = .semibold

    var body: some View {
        Text("\(percent)%")
            .font(.system(size: size, weight: weight, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(percent)))
    }
}
