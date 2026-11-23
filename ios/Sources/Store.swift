import Combine
import Foundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let mine: Bool
    let text: String
}

@MainActor
final class AppStore: ObservableObject {

    @Published var server: String
    @Published var token: String
    @Published var tasks: [TaskItem] = []
    @Published var messages: [ChatMessage] = []
    @Published var status: String = "未配置"
    @Published var busy = false
    @Published var keepAliveOn = false

    private var socket: URLSessionWebSocketTask?
    private var running = false

    init() {
        server = UserDefaults.standard.string(forKey: "server") ?? ""
        token = UserDefaults.standard.string(forKey: "token") ?? ""
    }

    // MARK: - 生命周期

    func start() {
        guard !running else { return }
        running = true

        guard !server.isEmpty, !token.isEmpty else {
            status = "未配置"
            return
        }

        Notify.setup()
        KeepAlive.shared.start()
        keepAliveOn = KeepAlive.shared.isRunning
        connect()
        Task { await refresh() }
    }

    func restart() {
        socket?.cancel(with: .goingAway, reason: nil)
        running = true
        connect()
        Task { await refresh() }
    }

    func save() {
        UserDefaults.standard.set(server, forKey: "server")
        UserDefaults.standard.set(token, forKey: "token")
    }

    func toggleKeepAlive() {
        if keepAliveOn {
            KeepAlive.shared.stop()
        } else {
            KeepAlive.shared.start()
        }
        keepAliveOn = KeepAlive.shared.isRunning
    }

    // MARK: - 数据

    func refresh() async {
        guard !server.isEmpty, !token.isEmpty else { return }
        do {
            tasks = try await APIClient(base: server, token: token).tasks()
            Notify.sync(tasks)
        } catch {
            print("拉取任务失败: \(error)")
        }
    }

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !busy else { return }

        messages.append(ChatMessage(mine: true, text: trimmed))
        busy = true

        Task {
            do {
                let reply = try await APIClient(base: server, token: token).chat(trimmed)
                messages.append(ChatMessage(mine: false, text: reply.isEmpty ? "（无回复）" : reply))
                await refresh()
            } catch {
                messages.append(ChatMessage(mine: false, text: "出错：\(error.localizedDescription)"))
            }
            busy = false
        }
    }

    func testConnection() async -> String {
        do {
            let health = try await APIClient(base: server, token: token).health()
            return "连接成功 · 手机在线 \(health.phones) · 节点 \(health.nodes.count)"
        } catch {
            return "失败：\(error.localizedDescription)"
        }
    }

    // MARK: - WebSocket

    private var socketURL: String {
        var base = server.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.hasPrefix("https://") {
            base = "wss://" + String(base.dropFirst(8))
        } else if base.hasPrefix("http://") {
            base = "ws://" + String(base.dropFirst(7))
        }
        while base.hasSuffix("/") { base.removeLast() }
        let safeToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
        return base + "/ws/phone?token=" + safeToken
    }

    private func connect() {
        guard let url = URL(string: socketURL) else {
            status = "地址无效"
            return
        }
        let task = URLSession.shared.webSocketTask(with: url)
        socket = task
        task.resume()
        status = "已连接"
        listen(task)
    }

    private func listen(_ task: URLSessionWebSocketTask) {
        Task {
            while true {
                do {
                    let message = try await task.receive()
                    handle(message)
                } catch {
                    guard running else { return }
                    status = "已断开，重连中"
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    connect()
                    return
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        guard
            case .string(let text) = message,
            let data = text.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = object["type"] as? String
        else { return }

        if type == "incoming_call" {
            let title = object["title"] as? String ?? "私人助理"
            let body = object["text"] as? String ?? ""
            let taskID = object["task_id"] as? String ?? UUID().uuidString
            CallManager.shared.ring(title: title, body: body, id: "task-" + taskID)
            Task { await refresh() }
        }
    }
}

func formatRunAt(_ iso: String) -> String {
    guard let date = Notify.parse(iso) else { return iso }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "M月d日 HH:mm"
    return formatter.string(from: date)
}

func statusLabel(_ status: String) -> String {
    switch status {
    case "pending": return "待执行"
    case "done": return "已执行"
    case "cancelled": return "已取消"
    case "failed": return "失败"
    default: return status
    }
}
