import SwiftUI
import Combine

// Property-level favorite: which sensor value to show
struct FavoriteProp: Codable, Hashable {
    let deviceId: String
    let property: PropKey // "temperature", "humidity", or "all"
    enum PropKey: String, Codable { case temperature, humidity, all }
}

@MainActor
final class AppState: ObservableObject {
    @Published var token: String? = nil
    @Published var userInfo: UserInfoResponse? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var favorites: [String] = []           // device/scenario IDs, ordered by insertion
    @Published var favProps: [FavoriteProp] = []     // property-level sensor favorites
    @Published var pinnedSensorId: String? = nil
    @Published var pinnedPropKey: FavoriteProp.PropKey = .all

    private var pollingTask: Task<Void, Never>?

    init() {
        token = KeychainService.load()
        loadPreferences()
        if token != nil { startPolling() }
    }

    // MARK: - Auth
    func authenticate(token: String) async {
        isLoading = true; errorMessage = nil
        do {
            let info = try await APIService.shared.fetchUserInfo(token: token)
            KeychainService.save(token)
            self.token = token; self.userInfo = info
            recordHistory(from: info)
            startPolling()
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    func logout() {
        pollingTask?.cancel(); pollingTask = nil
        KeychainService.delete()
        token = nil; userInfo = nil
    }

    // MARK: - Refresh
    func refresh() async {
        guard let token else { return }
        do {
            let info = try await APIService.shared.fetchUserInfo(token: token)
            userInfo = info
            recordHistory(from: info)
        } catch {}
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                if Task.isCancelled { break }
                await refresh()
            }
        }
    }

    // MARK: - History
    private func recordHistory(from info: UserInfoResponse) {
        for device in info.devices where device.isSensor {
            if device.temperature != nil || device.humidity != nil {
                HistoryService.shared.record(deviceId: device.id,
                    temperature: device.temperature, humidity: device.humidity)
            }
        }
    }

    // MARK: - Actions
    func toggle(device: Device) async {
        guard let token else { return }
        let newState = !device.isOn
        updateDeviceState(deviceId: device.id, isOn: newState)
        do { try await APIService.shared.toggleDevice(token: token, deviceId: device.id, newState: newState) }
        catch { updateDeviceState(deviceId: device.id, isOn: !newState) }
    }

    func toggle(group: DeviceGroup) async {
        guard let token else { return }
        let isOn = group.capabilities.first { $0.type == "devices.capabilities.on_off" }?.state?.value.boolValue ?? false
        do { try await APIService.shared.toggleGroup(token: token, groupId: group.id, newState: !isOn); await refresh() }
        catch {}
    }

    func execute(scenario: Scenario) async {
        guard let token else { return }
        do { try await APIService.shared.executeScenario(token: token, scenarioId: scenario.id) } catch {}
    }

    func setMode(device: Device, instance: String, value: String, turnOn: Bool? = nil) async {
        guard let token else { return }
        do { try await APIService.shared.setDeviceMode(token: token, deviceId: device.id, instance: instance, value: value, turnOn: turnOn); await refresh() }
        catch {}
    }

    private func updateDeviceState(deviceId: String, isOn: Bool) {
        guard let info = userInfo else { return }
        userInfo = UserInfoResponse(
            status: info.status, rooms: info.rooms, groups: info.groups,
            devices: info.devices.map { d in
                guard d.id == deviceId else { return d }
                let caps = d.capabilities.map { cap -> Capability in
                    guard cap.type == "devices.capabilities.on_off" else { return cap }
                    return Capability(type: cap.type, retrievable: cap.retrievable, reportable: cap.reportable,
                                      state: CapabilityState(instance: "on", value: AnyCodable(isOn)), parameters: cap.parameters)
                }
                return Device(id: d.id, name: d.name, type: d.type, room: d.room,
                              groups: d.groups, capabilities: caps, properties: d.properties)
            },
            scenarios: info.scenarios, households: info.households)
    }

    // MARK: - Favorites
    func toggleFavorite(_ id: String) {
        if let idx = favorites.firstIndex(of: id) {
            favorites.remove(at: idx)
            favProps.removeAll { $0.deviceId == id }
        } else {
            favorites.append(id)
        }
        savePreferences()
    }

    func toggleFavProp(deviceId: String, key: FavoriteProp.PropKey) {
        if let idx = favProps.firstIndex(where: { $0.deviceId == deviceId && $0.property == key }) {
            favProps.remove(at: idx)
        } else {
            favProps.removeAll { $0.deviceId == deviceId } // one prop per device
            favProps.append(FavoriteProp(deviceId: deviceId, property: key))
            if !favorites.contains(deviceId) { favorites.append(deviceId) }
        }
        savePreferences()
    }

    func favProp(for deviceId: String) -> FavoriteProp? {
        favProps.first { $0.deviceId == deviceId }
    }

    func setPinnedSensor(_ id: String?, prop: FavoriteProp.PropKey = .all) {
        pinnedSensorId = id; pinnedPropKey = prop
        savePreferences()
    }

    // MARK: - Helpers
    func roomName(for device: Device) -> String? {
        userInfo?.rooms.first { $0.devices.contains(device.id) }?.name
    }

    // MARK: - Persistence
    private let prefsURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("YaHome", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("preferences.json")
    }()

    private struct Prefs: Codable {
        var favorites: [String] = []
        var favProps: [FavoriteProp] = []
        var pinnedSensorId: String?
        var pinnedPropKey: FavoriteProp.PropKey = .all
    }

    private func savePreferences() {
        let p = Prefs(favorites: favorites, favProps: favProps,
                      pinnedSensorId: pinnedSensorId, pinnedPropKey: pinnedPropKey)
        if let data = try? JSONEncoder().encode(p) { try? data.write(to: prefsURL) }
    }

    private func loadPreferences() {
        guard let data = try? Data(contentsOf: prefsURL),
              let p = try? JSONDecoder().decode(Prefs.self, from: data) else { return }
        favorites = p.favorites; favProps = p.favProps
        pinnedSensorId = p.pinnedSensorId; pinnedPropKey = p.pinnedPropKey
    }
}
