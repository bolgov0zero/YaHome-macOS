import Foundation

// MARK: - API Response Models

struct UserInfoResponse: Codable {
    let status: String
    let rooms: [Room]
    let groups: [DeviceGroup]
    let devices: [Device]
    let scenarios: [Scenario]
    let households: [Household]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status     = try c.decodeIfPresent(String.self,        forKey: .status)     ?? "ok"
        rooms      = try c.decodeIfPresent([Room].self,        forKey: .rooms)      ?? []
        groups     = try c.decodeIfPresent([DeviceGroup].self, forKey: .groups)     ?? []
        devices    = try c.decodeIfPresent([Device].self,      forKey: .devices)    ?? []
        scenarios  = try c.decodeIfPresent([Scenario].self,    forKey: .scenarios)  ?? []
        households = try c.decodeIfPresent([Household].self,   forKey: .households) ?? []
    }

    init(status: String, rooms: [Room], groups: [DeviceGroup], devices: [Device], scenarios: [Scenario], households: [Household]) {
        self.status = status; self.rooms = rooms; self.groups = groups
        self.devices = devices; self.scenarios = scenarios; self.households = households
    }
}

struct Room: Codable, Identifiable {
    let id: String
    let name: String
    let householdId: String
    let devices: [String]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self, forKey: .id)
        name        = try c.decode(String.self, forKey: .name)
        householdId = try c.decodeIfPresent(String.self, forKey: .householdId) ?? ""
        devices     = try c.decodeIfPresent([String].self, forKey: .devices) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case id, name, devices
        case householdId = "household_id"
    }
}

struct DeviceGroup: Codable, Identifiable {
    let id: String
    let name: String
    let householdId: String
    let devices: [String]
    let capabilities: [Capability]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(String.self, forKey: .id)
        name         = try c.decode(String.self, forKey: .name)
        householdId  = try c.decodeIfPresent(String.self, forKey: .householdId) ?? ""
        devices      = try c.decodeIfPresent([String].self, forKey: .devices) ?? []
        capabilities = try c.decodeIfPresent([Capability].self, forKey: .capabilities) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case id, name, devices, capabilities
        case householdId = "household_id"
    }
}

struct Device: Codable, Identifiable {
    let id: String
    let name: String
    let type: String
    let room: String?
    let groups: [String]?
    let capabilities: [Capability]
    let properties: [Property]?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(String.self, forKey: .id)
        name         = try c.decode(String.self, forKey: .name)
        type         = try c.decode(String.self, forKey: .type)
        room         = try c.decodeIfPresent(String.self, forKey: .room)
        groups       = try c.decodeIfPresent([String].self, forKey: .groups)
        capabilities = try c.decodeIfPresent([Capability].self, forKey: .capabilities) ?? []
        properties   = try c.decodeIfPresent([Property].self, forKey: .properties)
    }

    init(id: String, name: String, type: String, room: String?, groups: [String]?,
         capabilities: [Capability], properties: [Property]?) {
        self.id = id; self.name = name; self.type = type; self.room = room
        self.groups = groups; self.capabilities = capabilities; self.properties = properties
    }
}

struct Scenario: Codable, Identifiable {
    let id: String
    let name: String
    let isActive: Bool

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decode(String.self, forKey: .id)
        name     = try c.decode(String.self, forKey: .name)
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case isActive = "is_active"
    }
}

struct Household: Codable, Identifiable {
    let id: String
    let name: String
}

// MARK: - Capabilities & Properties

struct Capability: Codable {
    let type: String
    let retrievable: Bool
    let reportable: Bool
    let state: CapabilityState?
    let parameters: CapabilityParameters?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type         = try c.decode(String.self, forKey: .type)
        retrievable  = try c.decodeIfPresent(Bool.self, forKey: .retrievable) ?? false
        reportable   = try c.decodeIfPresent(Bool.self, forKey: .reportable) ?? false
        state        = try c.decodeIfPresent(CapabilityState.self, forKey: .state)
        parameters   = try? c.decodeIfPresent(CapabilityParameters.self, forKey: .parameters)
    }

    init(type: String, retrievable: Bool, reportable: Bool, state: CapabilityState?, parameters: CapabilityParameters?) {
        self.type = type; self.retrievable = retrievable; self.reportable = reportable
        self.state = state; self.parameters = parameters
    }
}

struct CapabilityState: Codable {
    let instance: String?
    let value: AnyCodable

    init(instance: String?, value: AnyCodable) { self.instance = instance; self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        instance = try c.decodeIfPresent(String.self, forKey: .instance)
        value    = try c.decodeIfPresent(AnyCodable.self, forKey: .value) ?? AnyCodable(NSNull())
    }
}

struct CapabilityParameters: Codable {
    let instance: String?
    let modes: [ModeOption]?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        instance = try c.decodeIfPresent(String.self, forKey: .instance)
        modes    = try c.decodeIfPresent([ModeOption].self, forKey: .modes)
    }
}

struct ModeOption: Codable, Identifiable {
    var id: String { value }
    let value: String
    let name: String
}

struct Property: Codable {
    let type: String
    let retrievable: Bool
    let reportable: Bool
    let parameters: PropertyParameters?
    let state: PropertyState?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type        = try c.decode(String.self, forKey: .type)
        retrievable = try c.decodeIfPresent(Bool.self, forKey: .retrievable) ?? false
        reportable  = try c.decodeIfPresent(Bool.self, forKey: .reportable) ?? false
        parameters  = try c.decodeIfPresent(PropertyParameters.self, forKey: .parameters)
        state       = try c.decodeIfPresent(PropertyState.self, forKey: .state)
    }
}

struct PropertyParameters: Codable {
    let instance: String?
    let unit: String?
}

struct PropertyState: Codable {
    let instance: String?
    let value: AnyCodable

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        instance = try c.decodeIfPresent(String.self, forKey: .instance)
        value    = try c.decodeIfPresent(AnyCodable.self, forKey: .value) ?? AnyCodable(NSNull())
    }
}

// MARK: - AnyCodable

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil()                          { value = NSNull() }
        else if let b = try? c.decode(Bool.self)  { value = b }
        else if let i = try? c.decode(Int.self)   { value = i }
        else if let d = try? c.decode(Double.self){ value = d }
        else if let s = try? c.decode(String.self){ value = s }
        else                                       { value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let b as Bool:   try c.encode(b)
        case let i as Int:    try c.encode(i)
        case let d as Double: try c.encode(d)
        case let s as String: try c.encode(s)
        default:              try c.encodeNil()
        }
    }

    var boolValue: Bool?   { value as? Bool }
    var doubleValue: Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int    { return Double(i) }
        return nil
    }
    var stringValue: String? { value as? String }
}

// MARK: - Device Helpers

extension Device {
    var isToggleable: Bool {
        capabilities.contains { $0.type == "devices.capabilities.on_off" }
    }

    var isOn: Bool {
        capabilities
            .first { $0.type == "devices.capabilities.on_off" }?
            .state?.value.boolValue ?? false
    }

    var isSensor: Bool { !isToggleable && (temperature != nil || humidity != nil) }

    var temperature: Double? {
        properties?
            .first { $0.parameters?.instance == "temperature" }?
            .state?.value.doubleValue
    }

    var humidity: Double? {
        properties?
            .first { $0.parameters?.instance == "humidity" }?
            .state?.value.doubleValue
    }

    var formattedSensorValue: String? {
        var parts: [String] = []
        if let t = temperature { parts.append(String(format: "%.1f°C", t)) }
        if let h = humidity    { parts.append(String(format: "%.0f%%", h)) }
        return parts.isEmpty ? nil : parts.joined(separator: " / ")
    }

    var modeCapabilities: [Capability] {
        capabilities.filter { $0.type == "devices.capabilities.mode" }
    }
}

// MARK: - History

struct SensorHistoryEntry: Codable {
    let ts: Double
    var temperature: Double?
    var humidity: Double?
}
