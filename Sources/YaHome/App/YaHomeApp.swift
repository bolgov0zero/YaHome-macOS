import SwiftUI
import AppKit

@main
struct YaHomeApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("YaHome") {
            ContentView()
                .environmentObject(appState)
                .onAppear { appDelegate.setup(appState: appState) }
                .background(WindowAccessor { appDelegate.mainWindow = $0 })
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 880, height: 620)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack {
            if state.token == nil {
                AuthView().frame(width: 420)
            } else if state.userInfo == nil {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Загрузка…").foregroundStyle(.secondary)
                }.frame(width: 420, height: 300)
            } else {
                DashboardView().frame(minWidth: 720, minHeight: 500)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.token)
    }
}

// MARK: - Window accessor (captures NSWindow reference)
struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            if let w = v.window { self.callback(w) }
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let w = nsView.window { self.callback(w) }
        }
    }
}

// MARK: - App Delegate
final class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarManager: MenuBarManager?
    weak var mainWindow: NSWindow? {
        didSet { mainWindow?.delegate = windowDelegate }
    }
    private let windowDelegate = HideOnCloseDelegate()

    @MainActor func setup(appState: AppState) {
        guard menuBarManager == nil else { return }
        menuBarManager = MenuBarManager(appState: appState, appDelegate: self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let w = mainWindow {
            w.makeKeyAndOrderFront(nil)
        } else if let w = NSApp.windows.first {
            w.makeKeyAndOrderFront(nil)
        }
    }
}

// Intercept window close → hide instead
final class HideOnCloseDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
