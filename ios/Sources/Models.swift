import Foundation

struct TaskItem: Codable, Identifiable {
    let id: String
    let title: String
    let prompt: String
    let run_at: String
    let status: String
    var result: String?
}

struct ChatReq: Encodable { let text: String }
struct ChatResp: Decodable { let text: String }

struct Health: Decodable {
    let ok: Bool
    let nodes: [String]
    let phones: Int
}

enum APIError: LocalizedError {
    case badURL
    case status(Int)
    case decode

    var errorDescription: String? {
        switch self {
        case .badURL: return "服务器地址无效"
        case .status(let code): return "HTTP \(code)"
        case .decode: return "数据解析失败"
        }
    }
}

struct APIClient {
    var base: String
    var token: String

    private var trimmedBase: String {
        base.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func health() async throws -> Health {
        try await get("/api/health")
    }

    func tasks() async throws -> [TaskItem] {
        try await get("/api/tasks")
    }

    func chat(_ text: String) async throws -> String {
        let body = try JSONEncoder().encode(ChatReq(text: text))
        let resp: ChatResp = try await send("/api/chat", method: "POST", body: body)
        return resp.text
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        try await send(path, method: "GET", body: nil)
    }

    private func send<T: Decodable>(_ path: String, method: String, body: Data?) async throws -> T {
        guard let url = URL(string: trimmedBase + path) else { throw APIError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 60
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
            throw APIError.status(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decode
        }
    }
}
