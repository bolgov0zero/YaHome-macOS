import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case noData
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Неверный URL"
        case .noData: return "Нет данных"
        case .httpError(let code): return "Ошибка HTTP \(code)"
        case .decodingError(let e): return "Ошибка разбора: \(e.localizedDescription)"
        case .networkError(let e): return e.localizedDescription
        }
    }
}

final class APIService {
    static let shared = APIService()
    private let base = "https://api.iot.yandex.net/v1.0"
    private let session = URLSession.shared

    private func request(_ path: String, token: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let url = URL(string: base + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.networkError(error)
        }
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw APIError.httpError(http.statusCode)
        }
        return data
    }

    func fetchUserInfo(token: String) async throws -> UserInfoResponse {
        let data = try await request("/user/info", token: token)
        do {
            return try JSONDecoder().decode(UserInfoResponse.self, from: data)
        } catch {
            print("DECODE ERROR:", error)
            throw APIError.decodingError(error)
        }
    }

    func toggleDevice(token: String, deviceId: String, newState: Bool) async throws {
        let action = ["devices": [["id": deviceId, "actions": [["type": "devices.capabilities.on_off", "state": ["instance": "on", "value": newState]]]]]]
        let body = try JSONSerialization.data(withJSONObject: action)
        _ = try await request("/devices/actions", token: token, method: "POST", body: body)
    }

    func toggleGroup(token: String, groupId: String, newState: Bool) async throws {
        let action = ["actions": [["type": "devices.capabilities.on_off", "state": ["instance": "on", "value": newState]]]]
        let body = try JSONSerialization.data(withJSONObject: action)
        _ = try await request("/groups/\(groupId)/actions", token: token, method: "POST", body: body)
    }

    func executeScenario(token: String, scenarioId: String) async throws {
        _ = try await request("/scenarios/\(scenarioId)/actions", token: token, method: "POST")
    }

    func setDeviceMode(token: String, deviceId: String, instance: String, value: String, turnOn: Bool?) async throws {
        var actions: [[String: Any]] = [
            ["type": "devices.capabilities.mode", "state": ["instance": instance, "value": value]]
        ]
        if let on = turnOn {
            actions.append(["type": "devices.capabilities.on_off", "state": ["instance": "on", "value": on]])
        }
        let body = try JSONSerialization.data(withJSONObject: ["devices": [["id": deviceId, "actions": actions]]])
        _ = try await request("/devices/actions", token: token, method: "POST", body: body)
    }
}
