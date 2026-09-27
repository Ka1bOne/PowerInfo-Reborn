import SwiftUI

struct AboutView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

            VStack(spacing: 3) {
                Text("PowerInfo Reborn")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(version)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text("Copyright © 2026 Ka1bOne")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(width: 340)
    }
}
