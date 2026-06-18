import AppKit
import Combine

@MainActor
final class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()
    private weak var appState: AppState?
    private weak var appDelegate: AppDelegate?
    private var isMenuVisible = false

    init(appState: AppState, appDelegate: AppDelegate) {
        self.appState = appState
        self.appDelegate = appDelegate
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        setupButton()
        observe(appState)
    }

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "house.fill", accessibilityDescription: "YaHome")
        button.image?.isTemplate = true
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.target = self
    }

    private func observe(_ state: AppState) {
        state.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self?.updateTitle() }
            }
            .store(in: &cancellables)
    }

    private func updateTitle() {
        guard let state = appState,
              let id = state.pinnedSensorId,
              let device = state.userInfo?.devices.first(where: { $0.id == id })
        else { statusItem.button?.title = ""; return }

        let key = state.pinnedPropKey
        var parts: [String] = []
        if key != .humidity, let t = device.temperature { parts.append(String(format: "%.1f°C", t)) }
        if key != .temperature, let h = device.humidity { parts.append(String(format: "%.0f%%", h)) }
        statusItem.button?.title = parts.isEmpty ? "" : " \(parts.joined(separator: " / "))"
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp { showAppMenu() } else { toggleFavoritesMenu() }
    }

    private func toggleFavoritesMenu() {
        if isMenuVisible {
            statusItem.menu?.cancelTracking(); statusItem.menu = nil; isMenuVisible = false; return
        }
        let menu = buildFavoritesMenu()
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    private func buildFavoritesMenu() -> NSMenu {
        let menu = NSMenu()
        guard let state = appState, let info = state.userInfo else {
            menu.addItem(NSMenuItem(title: "Нет данных", action: nil, keyEquivalent: ""))
            return menu
        }

        let favIds = state.favorites
        let favDevices = info.devices.filter { favIds.contains($0.id) }
        let favScenarios = info.scenarios.filter { favIds.contains($0.id) }
        let sensors = favDevices.filter { $0.isSensor }
        let toggleables = favDevices.filter { $0.isToggleable }

        if sensors.isEmpty && toggleables.isEmpty && favScenarios.isEmpty {
            menu.addItem(NSMenuItem(title: "Нет избранного", action: nil, keyEquivalent: ""))
            menu.addItem(.separator())
        } else {
            for device in sensors {
                let fp = state.favProp(for: device.id)
                let isPinned = state.pinnedSensorId == device.id
                let item = NSMenuItem()
                item.title = isPinned ? "✓ \(device.name)" : device.name
                var sub = state.roomName(for: device) ?? ""
                var valParts: [String] = []
                if fp?.property != .humidity, let t = device.temperature { valParts.append(String(format: "%.1f°C", t)) }
                if fp?.property != .temperature, let h = device.humidity { valParts.append(String(format: "%.0f%%", h)) }
                if !valParts.isEmpty { sub += sub.isEmpty ? valParts.joined(separator: " / ") : "   \(valParts.joined(separator: " / "))" }
                if !sub.isEmpty, #available(macOS 14.4, *) { item.subtitle = sub }
                item.representedObject = device.id
                item.action = #selector(togglePinnedSensor(_:))
                item.target = self
                menu.addItem(item)
            }

            if !sensors.isEmpty && (!toggleables.isEmpty || !favScenarios.isEmpty) { menu.addItem(.separator()) }

            for device in toggleables {
                let item = NSMenuItem()
                item.title = device.isOn ? "✓ \(device.name)" : device.name
                if let room = state.roomName(for: device), #available(macOS 14.4, *) { item.subtitle = room }
                item.representedObject = device.id
                item.action = #selector(toggleDeviceById(_:))
                item.target = self
                menu.addItem(item)
            }

            if !favScenarios.isEmpty {
                if !toggleables.isEmpty { menu.addItem(.separator()) }
                for scenario in favScenarios {
                    let item = NSMenuItem(title: scenario.name, action: #selector(runScenarioById(_:)), keyEquivalent: "")
                    item.representedObject = scenario.id; item.target = self
                    menu.addItem(item)
                }
            }
            menu.addItem(.separator())
        }

        let open = NSMenuItem(title: "Открыть YaHome", action: #selector(openWindow), keyEquivalent: "o")
        open.target = self
        menu.addItem(open)
        menu.addItem(NSMenuItem(title: "Выйти", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @objc private func togglePinnedSensor(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        let key = appState?.favProp(for: id)?.property ?? .all
        appState?.setPinnedSensor(appState?.pinnedSensorId == id ? nil : id, prop: key)
        updateTitle()
    }

    @objc private func toggleDeviceById(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let device = appState?.userInfo?.devices.first(where: { $0.id == id }) else { return }
        Task { await appState?.toggle(device: device) }
    }

    @objc private func runScenarioById(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let scenario = appState?.userInfo?.scenarios.first(where: { $0.id == id }) else { return }
        Task { await appState?.execute(scenario: scenario) }
    }

    @objc private func openWindow() {
        appDelegate?.showMainWindow()
    }

    private func showAppMenu() {
        let menu = NSMenu()
        let open = NSMenuItem(title: "Открыть YaHome", action: #selector(openWindow), keyEquivalent: "")
        open.target = self; menu.addItem(open)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Выйти", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu; statusItem.button?.performClick(nil); statusItem.menu = nil
    }
}

extension MenuBarManager: NSMenuDelegate {
    nonisolated func menuDidClose(_ menu: NSMenu) {
        Task { @MainActor in self.isMenuVisible = false; self.statusItem.menu = nil }
    }
    nonisolated func menuWillOpen(_ menu: NSMenu) {
        Task { @MainActor in self.isMenuVisible = true }
    }
}
