import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = makeMainMenu()
        setUpStatusItem()

        let monitor = PowerMonitor.shared
        monitor.onEvent = { event, snapshot in
            PopupController.shared.handle(event, snapshot: snapshot)
        }
        monitor.start()

        monitor.$snapshot
            .sink { PopupController.shared.refresh(snapshot: $0) }
            .store(in: &cancellables)

        monitor.$snapshot
            .combineLatest(Preferences.shared.$showPercentInMenuBar)
            .sink { [weak self] snapshot, showPercent in self?.updateTitle(snapshot, showPercent) }
            .store(in: &cancellables)

        // `--preview <style>` shows a popup on launch (handy for testing).
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--preview") {
            let style = args.indices.contains(i + 1) ? PopupStyle(rawValue: args[i + 1]) : nil
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.6))
                PopupController.shared.preview(style: style)
            }
        }
    }

    // MARK: Menu bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        statusItem.button?.toolTip = "PowerInfo Reborn"

        let menu = NSMenu()
        menu.addItem(item("Settings…", #selector(openSettings), key: ","))
        menu.addItem(item("About PowerInfo Reborn", #selector(openAbout)))
        menu.addItem(.separator())
        menu.addItem(item("Quit PowerInfo Reborn", #selector(quit), key: "q"))
        statusItem.menu = menu
    }

    private func updateTitle(_ snapshot: PowerSnapshot, _ showPercent: Bool) {
        statusItem.button?.title = showPercent && snapshot.hasBattery ? "PIR \(snapshot.percent)%" : "PIR"
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    /// Hidden for an accessory app, but gives the Settings window ⌘W / ⌘Q.
    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(item("Settings…", #selector(openSettings), key: ","))
        appMenu.addItem(NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        appMenu.addItem(item("Quit PowerInfo Reborn", #selector(quit), key: "q"))
        appItem.submenu = appMenu
        main.addItem(appItem)
        return main
    }

    // MARK: Windows

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = makeWindow(SettingsView(), title: "PowerInfo Reborn Settings")
        }
        present(settingsWindow)
    }

    @objc private func openAbout() {
        if aboutWindow == nil {
            aboutWindow = makeWindow(AboutView(), title: "About PowerInfo Reborn")
            aboutWindow?.styleMask.insert(.fullSizeContentView)
            aboutWindow?.titlebarAppearsTransparent = true
            aboutWindow?.titleVisibility = .hidden
        }
        present(aboutWindow)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func makeWindow(_ view: some View, title: String) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = title
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func present(_ window: NSWindow?) {
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
