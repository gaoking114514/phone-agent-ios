import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        TabView {
            ChatView()
                .tabItem { Label("对话", systemImage: "bubble.left.and.bubble.right.fill") }
            TasksView()
                .tabItem { Label("任务", systemImage: "alarm.fill") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .onAppear { store.start() }
    }
}

// MARK: - 对话

struct ChatView: View {
    @EnvironmentObject var store: AppStore
    @State private var input = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(store.status == "已连接" ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(store.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(store.keepAliveOn ? "保活中" : "未保活")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if store.messages.isEmpty {
                            Text("说点什么，比如「明天早上八点提醒我交电费」")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        }
                        ForEach(store.messages) { message in
                            MessageRow(message: message)
                        }
                        if store.busy {
                            Text("正在思考…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding()
                }
                .onChange(of: store.messages.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }

            Divider()

            HStack(spacing: 8) {
                TextField("说点什么…", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    store.send(input)
                    input = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                }
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || store.busy)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }
}

private struct MessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.mine { Spacer(minLength: 40) }
            Text(message.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(message.mine ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(message.mine ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            if !message.mine { Spacer(minLength: 40) }
        }
    }
}

// MARK: - 任务

struct TasksView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        NavigationStack {
            List {
                if store.tasks.isEmpty {
                    Text("还没有任务。在对话里说「明天八点提醒我…」就能建。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(store.tasks) { task in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(task.title).font(.headline)
                            Spacer()
                            Text(statusLabel(task.status))
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                        }
                        Text(task.prompt)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(formatRunAt(task.run_at))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 3)
                }
            }
            .navigationTitle("任务")
            .refreshable { await store.refresh() }
        }
    }
}

// MARK: - 设置

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @State private var testResult = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("服务器") {
                    TextField("http://103.236.88.39:55110", text: $store.server)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("API_TOKEN", text: $store.token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    Button("保存并重连") {
                        store.save()
                        store.restart()
                        testResult = ""
                    }
                    Button("测试连接") {
                        Task { testResult = await store.testConnection() }
                    }
                    if !testResult.isEmpty {
                        Text(testResult)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("后台") {
                    Toggle("保活（静音音频）", isOn: Binding(
                        get: { store.keepAliveOn },
                        set: { _ in store.toggleKeepAlive() }
                    ))
                    Text("开启后 App 常驻后台，任务到点才有机会弹出来电界面；关闭后只能靠本地通知兜底。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("说明") {
                    Text("免费证书每 7 天需要续签一次，续签完重新打开 App 即可。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
        }
    }
}
