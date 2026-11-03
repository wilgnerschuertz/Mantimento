import SwiftUI
import AppKit

struct Message: Identifiable, Codable, Equatable {
    var id = UUID()
    var role: String
    var content: String
}
struct Conversation: Identifiable, Codable {
    var id = UUID()
    var title: String
    var messages: [Message]
    var workspace: String? = nil
}
struct DownloadModel: Identifiable {
    let id: String
    let title: String
    let detail: String
    static let catalog = [
        DownloadModel(id:"mlx-community/Qwen3.5-2B-4bit", title:"Qwen3.5 2B", detail:"Leve · tarefas curtas e menor uso de memória"),
        DownloadModel(id:"mlx-community/Qwen3.5-4B-4bit", title:"Qwen3.5 4B", detail:"Intermediário · alternativa menor ao 9B"),
        DownloadModel(id:"mlx-community/Qwen3.5-9B-4bit", title:"Qwen3.5 9B", detail:"Mais capacidade · validado com ferramentas")
    ]
}
@MainActor final class Store: ObservableObject {
    @Published var messages: [Message] = []
    @Published var conversations: [Conversation] = []
    @Published var selected: UUID?
    @Published var workspace = ""
    @Published var agentEnabled = false
    @Published var fullControl = false
    @Published var pending: ToolProposal?
    var approval: CheckedContinuation<Bool,Never>?
    var commandProcess: Process?
    @Published var modelID = UserDefaults.standard.string(forKey:"modelID") ?? "mlx-community/Qwen3.5-9B-4bit" {
        didSet { UserDefaults.standard.set(modelID, forKey:"modelID") }
    }
    @Published var models = UserDefaults.standard.stringArray(forKey:"models") ?? ["mlx-community/Qwen3.5-9B-4bit"]
    @Published var availableModels: Set<String> = []
    @Published var newModel = ""
    @Published var showSettings = false
    @Published var maxTokens = 2048
    @Published var temperature = 0.6
    @Published var chatQuery = ""
    @Published var autoScroll = true
    @Published var generationInfo = ""
    @Published var input = ""
    @Published var status = "Prepare o ambiente, baixe o modelo e inicie."
    @Published var showLogs = false
    @Published var logs = ""
    @Published var working = false
    @Published var running = false
    @Published var generating = false
    var stopping = false
    var process: Process?
    var request: Task<Void, Never>?
    let base = URL(string: "http://127.0.0.1:12345")!
    let dataDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("QwenLocal")
    var archive: URL { dataDir.appendingPathComponent("conversations.json") }
    var history: URL { dataDir.appendingPathComponent("history.json") }
    init() {
        for entry in DownloadModel.catalog where !models.contains(entry.id) { models.append(entry.id) }
        UserDefaults.standard.set(models,forKey:"models")
        refreshDownloads()
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: archive), let saved = try? JSONDecoder().decode([Conversation].self, from: data), !saved.isEmpty {
            conversations = saved; selected = saved[0].id; messages = saved[0].messages; workspace = saved[0].workspace ?? ""
            ensureWorkspace(); return
        }
        if let data = try? Data(contentsOf: history), let saved = try? JSONDecoder().decode([Message].self, from: data) { messages = saved }
        ensureWorkspace()
        if !messages.isEmpty { save() }
    }
    func refreshDownloads() {
        availableModels = Set(DownloadModel.catalog.compactMap { entry in
            let repo = "models--" + entry.id.replacingOccurrences(of:"/",with:"--")
            let root = dataDir.appendingPathComponent("cache/hub").appendingPathComponent(repo).appendingPathComponent("snapshots")
            let snapshots = (try? FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:nil)) ?? []
            let ready = snapshots.contains { folder in
                guard FileManager.default.fileExists(atPath:folder.appendingPathComponent("config.json").path),
                      FileManager.default.fileExists(atPath:folder.appendingPathComponent("tokenizer.json").path) else { return false }
                let index = folder.appendingPathComponent("model.safetensors.index.json")
                if let data = try? Data(contentsOf:index), let object = try? JSONSerialization.jsonObject(with:data) as? [String:Any], let map = object["weight_map"] as? [String:String] {
                    return !map.isEmpty && Set(map.values).allSatisfy { FileManager.default.fileExists(atPath:folder.appendingPathComponent($0).path) }
                }
                return FileManager.default.fileExists(atPath:folder.appendingPathComponent("model.safetensors").path)
            }
            return ready ? entry.id : nil
        })
    }
    func download(_ id: String) { guard process == nil else { return }; modelID = id; run("download") }
    func addModel() {
        let value = newModel.trimmingCharacters(in:.whitespacesAndNewlines)
        let parts = value.split(separator:"/")
        guard !value.isEmpty, value.hasPrefix("/") || (parts.count == 2 && !value.contains(" ")) else { status = "Informe organização/modelo do Hugging Face ou uma pasta absoluta."; return }
        if !models.contains(value) { models.append(value); UserDefaults.standard.set(models,forKey:"models") }
        modelID = value; newModel = ""; status = "Modelo selecionado. Baixe-o ou inicie se já estiver disponível."
    }
    func chooseFolder() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        newModel = url.path; addModel()
    }
    func save() {
        if let data = try? JSONEncoder().encode(messages) { try? data.write(to: history, options: .atomic) }
        if selected == nil { selected = UUID() }
        let title = String(messages.first(where: { $0.role == "user" })?.content.prefix(45) ?? "Nova conversa")
        let conversation = Conversation(id: selected!, title: title, messages: messages, workspace:workspace)
        if let i = conversations.firstIndex(where: { $0.id == selected }) { conversations[i] = conversation }
        else { conversations.insert(conversation, at: 0) }
        if let data = try? JSONEncoder().encode(conversations) { try? data.write(to: archive, options: .atomic) }
    }
    func newChat() { guard !generating else { return }; save(); selected = nil; workspace = ""; generationInfo = ""; fullControl = false; messages = []; input = ""; ensureWorkspace(); save() }
    func select(_ chat: Conversation) { guard !generating else { return }; save(); generationInfo = ""; selected = chat.id; messages = chat.messages; workspace = chat.workspace ?? ""; fullControl = false; input = ""; ensureWorkspace() }
    func export() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "conversa.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try messages.map { "\($0.role == "user" ? "Você" : "Qwen")\n\($0.content)" }.joined(separator: "\n\n").write(to: url, atomically: true, encoding: .utf8) }
        catch { status = "Falha ao exportar: \(error.localizedDescription)" }
    }
    func log(_ s: String) { logs = String((logs + s).suffix(18000)) }
    func run(_ action: String) {
        guard process == nil else { return }
        stopping = false
        guard let script = Bundle.main.url(forResource: "runtime", withExtension: "sh") else { status = "Script de execução ausente."; return }
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/bash"); p.arguments = [script.path, action, modelID]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil; return }
            let string = String(decoding: data, as: UTF8.self)
            Task { @MainActor in self?.log(string) }
        }
        p.terminationHandler = { [weak self] proc in Task { @MainActor in
            guard let self else { return }
            self.process = nil; self.working = false; self.running = false; self.refreshDownloads()
            self.status = self.stopping ? "Processo desligado." : proc.terminationStatus == 0 ? "Etapa concluída." : "Processo encerrado (\(proc.terminationStatus)). Consulte os registros."
        }}
        do {
            try p.run(); process = p; working = true
            status = action == "start" ? "Iniciando servidor local…" : action == "setup" ? "Preparando Python e MLX…" : "Baixando modelo; pode levar vários minutos…"
            if action == "start" { Task { await readiness(p) } }
        } catch { status = error.localizedDescription; pipe.fileHandleForReading.readabilityHandler = nil }
    }
    func readiness(_ p: Process) async {
        for _ in 0..<180 {
            guard process === p, p.isRunning else { return }
            do {
                var r = URLRequest(url: base.appendingPathComponent("v1/models")); r.timeoutInterval = 2
                let (_, response) = try await URLSession.shared.data(for: r)
                if (response as? HTTPURLResponse)?.statusCode == 200 {
                    working = false; running = true; status = "Servidor pronto • modelo carrega no primeiro pedido"; return
                }
            } catch {}
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        if process === p { status = "Inicialização demorada. Consulte os registros ou pare o processo." }
    }
    func stop() {
        stopping = true
        request?.cancel(); approve(false); commandProcess?.terminate()
        process?.terminate(); running = false; status = "Encerrando processo…"
    }
    func send() {
        if agentEnabled { sendAgent(); return }
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard running, !generating, !text.isEmpty else { return }
        guard messages.reduce(0, { $0 + $1.content.count }) + text.count < 16000 else {
            status = "Conversa longa para este modo econômico. Inicie uma nova conversa."; return
        }
        generationInfo = ""; messages.append(Message(role: "user", content: text)); input = ""; save(); generating = true; status = "Gerando resposta…"
        let context = messages.map { ["role": $0.role, "content": $0.content] }
        request = Task {
            defer { generating = false; request = nil }
            do {
                var r = URLRequest(url: base.appendingPathComponent("v1/chat/completions"))
                r.httpMethod = "POST"; r.timeoutInterval = 600; r.setValue("application/json", forHTTPHeaderField: "Content-Type")
                r.httpBody = try JSONSerialization.data(withJSONObject: ["model":"default_model", "messages": [["role":"system","content":"Responda em português de forma clara e útil."]] + context, "max_tokens": maxTokens, "temperature": temperature, "stream": true, "chat_template_kwargs": ["enable_thinking": false]])
                let (bytes, response) = try await URLSession.shared.bytes(for: r)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw NSError(domain: "Servidor", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: "O servidor recusou o pedido. Consulte os registros."]) }
                let answerID = UUID()
                messages.append(Message(id: answerID, role: "assistant", content: ""))
                var finished = false
                let started = Date()
                var firstContent: Date?
                var buffer = ""
                var lastFlush = Date.distantPast
                @MainActor func flush() {
                    guard !buffer.isEmpty, let index = messages.firstIndex(where: { $0.id == answerID }) else { return }
                    messages[index].content += buffer; buffer = ""; lastFlush = Date()
                }
                defer { flush() }
                for try await line in bytes.lines {
                    try Task.checkCancellation()
                    guard line.hasPrefix("data:") else { continue }
                    let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                    if payload == "[DONE]" { finished = true; break }
                    guard let data = payload.data(using: .utf8), let object = try JSONSerialization.jsonObject(with: data) as? [String:Any] else { continue }
                    if let error = object["error"] { throw NSError(domain:"Geração",code:1,userInfo:[NSLocalizedDescriptionKey:String(describing:error)]) }
                    if let choices = object["choices"] as? [[String:Any]], let choice = choices.first {
                        if let delta = choice["delta"] as? [String:Any], let content = delta["content"] as? String,
                           !content.isEmpty {
                            if firstContent == nil { firstContent = Date() }
                            buffer += content
                            if Date().timeIntervalSince(lastFlush) >= 0.1 { flush() }
                        }
                        if let reason = choice["finish_reason"] as? String { finished = true; if reason == "length" { status = "Resposta atingiu o limite configurado." } }
                    }
                }
                flush(); save()
                let latency = firstContent?.timeIntervalSince(started) ?? 0
                generationInfo = String(format:"Primeiro texto: %.1f s · Total: %.1f s",latency,Date().timeIntervalSince(started))
                if status != "Resposta atingiu o limite configurado." { status = finished ? "Resposta em \(Int(Date().timeIntervalSince(started))) s • no seu Mac" : "Conexão interrompida. A resposta parcial foi salva." }

            } catch { save(); if !Task.isCancelled { status = "Falha: \(error.localizedDescription)" } }
        }
    }
}
final class Delegate: NSObject, NSApplicationDelegate {
    var store: Store?
    func applicationWillTerminate(_ notification: Notification) { MainActor.assumeIsolated { store?.request?.cancel(); store?.approve(false); store?.commandProcess?.terminate(); store?.process?.terminate() } }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
@main struct QwenLocalApp: App {
    @NSApplicationDelegateAdaptor(Delegate.self) var delegate
    @StateObject var store = Store()
    var body: some Scene { WindowGroup { ContentView(store:store).onAppear { delegate.store = store; NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps:true) } }.defaultSize(width:1120,height:800) }
}
