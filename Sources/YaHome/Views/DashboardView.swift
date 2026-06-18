import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @State private var showAllDevices = false
    @State private var showSettings = false

    var info: UserInfoResponse { state.userInfo! }

    private var favSensors: [Device] {
        info.devices.filter { $0.isSensor && state.favorites.contains($0.id) }
    }
    private var favDevices: [Device] {
        info.devices.filter { $0.isToggleable && state.favorites.contains($0.id) }
    }
    private var favScenarios: [Scenario] {
        info.scenarios.filter { state.favorites.contains($0.id) }
    }
    private var hasFavorites: Bool {
        !favSensors.isEmpty || !favDevices.isEmpty || !favScenarios.isEmpty
    }

    let columns = [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if hasFavorites {
                        favoritesContent
                    } else {
                        emptyFavoritesHint
                    }
                }
                .padding(18)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { Task { await state.refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }.help("Обновить")
            }
            ToolbarItem(placement: .automatic) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }.help("Настройки")
            }
            ToolbarItem(placement: .automatic) {
                Button { state.logout() } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }.help("Выйти")
            }
        }
        .sheet(isPresented: $showAllDevices) {
            AllDevicesSheet().environmentObject(state)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(state)
        }
    }

    // MARK: - Top bar
    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Умный дом").font(.system(size: 15, weight: .semibold))
                Text("\(info.devices.count) устройств · \(info.scenarios.count) сценариев")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { showAllDevices = true } label: {
                Label("Все устройства", systemImage: "square.grid.2x2")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(nsColor: .controlColor))
            .foregroundStyle(.primary)
            .controlSize(.small)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Favorites content
    @ViewBuilder
    private var favoritesContent: some View {
        if !favSensors.isEmpty {
            sectionHeader("Датчики")
            VStack(spacing: 6) {
                ForEach(favSensors) { CompactSensorRow(device: $0).environmentObject(state) }
            }
        }
        if !favDevices.isEmpty {
            sectionHeader(favSensors.isEmpty ? "Устройства" : "Устройства")
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(favDevices) { DeviceCardView(device: $0).environmentObject(state) }
            }
        }
        if !favScenarios.isEmpty {
            sectionHeader("Сценарии")
            VStack(spacing: 6) {
                ForEach(favScenarios) { ScenarioCardView(scenario: $0).environmentObject(state) }
            }
        }
    }

    // MARK: - Empty hint
    private var emptyFavoritesHint: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.square.on.square")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(.secondary.opacity(0.4))
            VStack(spacing: 6) {
                Text("Нет избранных").font(.headline)
                Text("Откройте все устройства и отметьте нужные звёздочкой.")
                    .font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: 300)
            }
            Button { showAllDevices = true } label: {
                Label("Открыть все устройства", systemImage: "square.grid.2x2")
            }
            .buttonStyle(.borderedProminent).tint(.orange)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .kerning(0.5)
            .padding(.horizontal, 2)
    }
}

// MARK: - All Devices Sheet

struct AllDevicesSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var selectedRoomId: String? = nil

    var info: UserInfoResponse { state.userInfo! }

    private var filteredDevices: [Device] {
        var devices = info.devices
        if let roomId = selectedRoomId {
            let ids = Set(info.rooms.first { $0.id == roomId }?.devices ?? [])
            devices = devices.filter { ids.contains($0.id) }
        }
        if !searchText.isEmpty {
            devices = devices.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return devices
    }

    private var sensors: [Device] { filteredDevices.filter { $0.isSensor } }
    private var toggleables: [Device] { filteredDevices.filter { $0.isToggleable } }
    private var scenarios: [Scenario] {
        guard searchText.isEmpty else {
            return info.scenarios.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return selectedRoomId == nil ? info.scenarios : []
    }

    let columns = [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            sheetToolbar
            Divider()
            roomFilter
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !sensors.isEmpty {
                        sheetSection("Датчики") {
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(sensors) { DeviceCardView(device: $0).environmentObject(state) }
                            }
                        }
                    }
                    if !toggleables.isEmpty {
                        sheetSection("Устройства") {
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(toggleables) { DeviceCardView(device: $0).environmentObject(state) }
                            }
                        }
                    }
                    if !scenarios.isEmpty {
                        sheetSection("Сценарии") {
                            VStack(spacing: 6) {
                                ForEach(scenarios) { ScenarioCardView(scenario: $0).environmentObject(state) }
                            }
                        }
                    }
                    if sensors.isEmpty && toggleables.isEmpty && scenarios.isEmpty {
                        Text("Ничего не найдено")
                            .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 40)
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 760, height: 600)
    }

    private var sheetToolbar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Все устройства").font(.headline)
                Text("\(info.devices.count) устройств").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Поиск...", text: $searchText).textFieldStyle(.plain).frame(width: 160)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(Capsule())

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var roomFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                roomChip(id: nil, name: "Все комнаты")
                ForEach(info.rooms) { room in roomChip(id: room.id, name: room.name) }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }

    private func roomChip(id: String?, name: String) -> some View {
        let selected = selectedRoomId == id
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedRoomId = id }
        } label: {
            Text(name)
                .font(.caption.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(selected ? Color.orange : Color(nsColor: .controlBackgroundColor))
                .foregroundStyle(selected ? .white : .primary)
                .clipShape(Capsule())
        }.buttonStyle(.plain)
    }

    @ViewBuilder
    private func sheetSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary).textCase(.uppercase).kerning(0.5)
            content()
        }
    }
}
