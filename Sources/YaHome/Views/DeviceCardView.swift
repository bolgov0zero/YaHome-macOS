import SwiftUI

// MARK: - Compact Sensor Tile (for favorites grid)

struct CompactSensorTile: View {
    let device: Device
    @EnvironmentObject var state: AppState

    private var favProp: FavoriteProp? { state.favProp(for: device.id) }
    private var prop: FavoriteProp.PropKey { favProp?.property ?? .all }
    private var room: String? { state.roomName(for: device) }
    private var isFav: Bool { state.favorites.contains(device.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.10))
                        .frame(width: 28, height: 28)
                    Image(systemName: "sensor.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.blue)
                }
                Spacer()
                favMenuButton
            }
            .padding(.horizontal, 10).padding(.top, 10)

            Spacer(minLength: 6)

            VStack(alignment: .leading, spacing: 2) {
                if prop != .humidity, let t = device.temperature {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.1f", t))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                        Text("°C")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.orange.opacity(0.7))
                    }
                }
                if prop != .temperature, let h = device.humidity {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.0f", h))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.blue)
                        Text("%")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.blue.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 6)

            VStack(alignment: .leading, spacing: 1) {
                Text(device.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                if let r = room {
                    Text(r).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .padding(.horizontal, 10).padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
        )
    }

    @ViewBuilder
    private var favMenuButton: some View {
        if device.temperature != nil && device.humidity != nil {
            Menu {
                Button { state.toggleFavProp(deviceId: device.id, key: .all) } label: {
                    Label("Оба значения", systemImage: prop == .all ? "checkmark" : "")
                }
                Button { state.toggleFavProp(deviceId: device.id, key: .temperature) } label: {
                    Label("Только температура", systemImage: prop == .temperature ? "checkmark" : "")
                }
                Button { state.toggleFavProp(deviceId: device.id, key: .humidity) } label: {
                    Label("Только влажность", systemImage: prop == .humidity ? "checkmark" : "")
                }
                Divider()
                Button(role: .destructive) { state.toggleFavorite(device.id) } label: {
                    Label("Убрать из избранного", systemImage: "star.slash")
                }
            } label: {
                Image(systemName: "star.fill").font(.system(size: 11)).foregroundStyle(.yellow)
            }
            .menuStyle(.borderlessButton).fixedSize()
        } else {
            Button { state.toggleFavorite(device.id) } label: {
                Image(systemName: isFav ? "star.fill" : "star")
                    .font(.system(size: 11)).foregroundStyle(isFav ? .yellow : .secondary)
            }.buttonStyle(.plain)
        }
    }
}

// MARK: - Device Card (full, used in AllDevicesSheet)

struct DeviceCardView: View {
    let device: Device
    @EnvironmentObject var state: AppState
    @State private var showHistory = false
    @State private var showModePopover = false

    private var isFav: Bool { state.favorites.contains(device.id) }
    private var favProp: FavoriteProp? { state.favProp(for: device.id) }
    private var room: String? { state.roomName(for: device) }

    var body: some View {
        if device.isSensor { sensorCard } else { toggleCard }
    }

    private var sensorCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "sensor.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.blue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    if let r = room { Text(r).font(.system(size: 11)).foregroundStyle(.secondary) }
                }
                Spacer()
                favButton
            }
            .padding(.horizontal, 14).padding(.top, 14)

            Spacer(minLength: 10)

            HStack(spacing: 16) {
                if let t = device.temperature {
                    valueChip(value: String(format: "%.1f°", t), icon: "thermometer.medium", color: .orange)
                }
                if let h = device.humidity {
                    valueChip(value: String(format: "%.0f%%", h), icon: "humidity.fill", color: .blue)
                }
            }
            .padding(.horizontal, 14)

            Button { showHistory = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chart.xyaxis.line").font(.system(size: 10))
                    Text("График").font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.secondary.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .background(cardBG(color: .blue, active: false))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showHistory) { historySheet }
    }

    private var toggleCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(device.isOn ? Color.orange.opacity(0.18) : Color.secondary.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: iconName(for: device.type))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(device.isOn ? .orange : .secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    if !device.modeCapabilities.isEmpty {
                        Button { showModePopover = true } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showModePopover) {
                            ModeMenuView(device: device).environmentObject(state)
                        }
                    }
                    favButton
                }
            }
            .padding(.horizontal, 14).padding(.top, 14)

            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(.system(size: 13, weight: .semibold)).lineLimit(2)
                if let r = room { Text(r).font(.system(size: 11)).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, 14)

            Spacer(minLength: 8)

            HStack {
                Text(device.isOn ? "Вкл" : "Выкл")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(device.isOn ? .orange : .secondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { device.isOn },
                    set: { _ in Task { await state.toggle(device: device) } }
                ))
                .toggleStyle(.switch).controlSize(.mini).tint(.orange)
            }
            .padding(.horizontal, 14).padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .background(cardBG(color: .orange, active: device.isOn))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture { Task { await state.toggle(device: device) } }
    }

    @ViewBuilder
    private var favButton: some View {
        if device.isSensor && device.temperature != nil && device.humidity != nil {
            Menu {
                Button { state.toggleFavProp(deviceId: device.id, key: .all) } label: {
                    Label("Оба значения", systemImage: favProp?.property == .all ? "checkmark" : "")
                }
                Button { state.toggleFavProp(deviceId: device.id, key: .temperature) } label: {
                    Label("Только температура", systemImage: favProp?.property == .temperature ? "checkmark" : "")
                }
                Button { state.toggleFavProp(deviceId: device.id, key: .humidity) } label: {
                    Label("Только влажность", systemImage: favProp?.property == .humidity ? "checkmark" : "")
                }
                Divider()
                if isFav {
                    Button(role: .destructive) { state.toggleFavorite(device.id) } label: {
                        Label("Убрать из избранного", systemImage: "star.slash")
                    }
                }
            } label: {
                Image(systemName: isFav ? "star.fill" : "star")
                    .font(.system(size: 13)).foregroundStyle(isFav ? .yellow : .secondary)
            }
            .menuStyle(.borderlessButton).fixedSize()
        } else {
            Button { state.toggleFavorite(device.id) } label: {
                Image(systemName: isFav ? "star.fill" : "star")
                    .font(.system(size: 13)).foregroundStyle(isFav ? .yellow : .secondary)
            }.buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func valueChip(value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11))
            Text(value).font(.system(size: 15, weight: .semibold, design: .rounded))
        }.foregroundStyle(color)
    }

    private func cardBG(color: Color, active: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .controlBackgroundColor))
            if active { RoundedRectangle(cornerRadius: 16).fill(color.opacity(0.07)) }
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(active ? color.opacity(0.25) : Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private func iconName(for type: String) -> String {
        switch type {
        case let t where t.contains("light"):      return "lightbulb.fill"
        case let t where t.contains("socket"):     return "powerplug.fill"
        case let t where t.contains("switch"):     return "switch.2"
        case let t where t.contains("thermostat"): return "thermometer.medium"
        case let t where t.contains("vacuum"):     return "cloud.fill"
        case let t where t.contains("humidifier"): return "humidity.fill"
        case let t where t.contains("fan"):        return "fan.fill"
        case let t where t.contains("cover"):      return "blinds.horizontal.closed"
        case let t where t.contains("openable"):   return "door.left.hand.open"
        default:                                    return "powerplug.fill"
        }
    }

    @ViewBuilder
    private var historySheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name).font(.headline)
                    Text("История показаний").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button { showHistory = false } label: {
                    Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
            .padding()
            Divider()
            SensorHistoryView(device: device,
                singleProperty: favProp.flatMap {
                    $0.property == .temperature ? "temperature" :
                    $0.property == .humidity    ? "humidity" : nil
                })
            .padding()
        }
        .frame(width: 580, height: 360)
    }
}

// MARK: - Scenario Card

struct ScenarioCardView: View {
    let scenario: Scenario
    @EnvironmentObject var state: AppState
    @State private var isRunning = false

    private var isFav: Bool { state.favorites.contains(scenario.id) }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: "play.fill").font(.system(size: 12)).foregroundStyle(.purple)
            }
            Text(scenario.name).font(.system(size: 13, weight: .medium))
            Spacer()
            Button { state.toggleFavorite(scenario.id) } label: {
                Image(systemName: isFav ? "star.fill" : "star")
                    .font(.system(size: 11)).foregroundStyle(isFav ? .yellow : .secondary)
            }.buttonStyle(.plain)
            Button {
                isRunning = true
                Task {
                    await state.execute(scenario: scenario)
                    try? await Task.sleep(for: .milliseconds(800))
                    isRunning = false
                }
            } label: {
                Group {
                    if isRunning { ProgressView().controlSize(.small) }
                    else { Text("Запустить").font(.system(size: 12, weight: .medium)) }
                }.frame(width: 72)
            }
            .buttonStyle(.borderedProminent).tint(.purple).controlSize(.small).disabled(isRunning)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
        )
    }
}

// MARK: - Mode Menu

struct ModeMenuView: View {
    let device: Device
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(device.modeCapabilities.enumerated()), id: \.offset) { _, cap in
                if let params = cap.parameters, let modes = params.modes, let inst = params.instance {
                    Text(inst.capitalized).font(.caption.bold()).foregroundStyle(.secondary)
                    ForEach(modes) { mode in
                        let isCurrent = cap.state?.value.stringValue == mode.value
                        Button {
                            Task { await state.setMode(device: device, instance: inst, value: mode.value); dismiss() }
                        } label: {
                            HStack {
                                Text(mode.name).font(.system(size: 13))
                                Spacer()
                                if isCurrent { Image(systemName: "checkmark").foregroundStyle(.orange) }
                            }
                        }
                        .buttonStyle(.plain).padding(.vertical, 3)
                    }
                }
            }
        }
        .padding(14).frame(minWidth: 180)
    }
}
