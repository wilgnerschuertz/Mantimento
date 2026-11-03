import SwiftUI
import AppKit

struct Message: Identifiable, Codable {
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
        DownloadModel(id:"mlx-community/Qwen3.5-9B-4bit", title:"Qwen3.5 9B", detail:"Seu modelo atual · já testado neste Mac")
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
    @Published var input = ""
    @Published var status = "Prepare o ambiente, baixe o modelo e inicie."
    @Published var showLogs = false
    @Published var logs = ""
    @Published var working = false
    @Published var running = false
    @Published var generating = false
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
    func newChat() { guard !generating else { return }; save(); selected = nil; workspace = ""; fullControl = false; messages = []; input = ""; ensureWorkspace(); save() }
    func select(_ chat: Conversation) { guard !generating else { return }; save(); selected = chat.id; messages = chat.messages; workspace = chat.workspace ?? ""; fullControl = false; input = ""; ensureWorkspace() }
    func export() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "conversa.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try messages.map { "\($0.role == "user" ? "Você" : "Qwen")\n\($0.content)" }.joined(separator: "\n\n").write(to: url, atomically: true, encoding: .utf8) }
        catch { status = "Falha ao exportar: \(error.localizedDescription)" }
    }
    func log(_ s: String) { logs = String((logs + s).suffix(18000)) }
    func run(_ action: String) {
        guard process == nil else { return }
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
            self.status = proc.terminationStatus == 0 ? "Etapa concluída." : "Processo encerrado (\(proc.terminationStatus)). Consulte os registros."
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
        messages.append(Message(role: "user", content: text)); input = ""; save(); generating = true; status = "Gerando resposta…"
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
                for try await line in bytes.lines {
                    try Task.checkCancellation()
                    guard line.hasPrefix("data:") else { continue }
                    let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                    if payload == "[DONE]" { finished = true; break }
                    guard let data = payload.data(using: .utf8), let object = try JSONSerialization.jsonObject(with: data) as? [String:Any] else { continue }
                    if let error = object["error"] { throw NSError(domain:"Geração",code:1,userInfo:[NSLocalizedDescriptionKey:String(describing:error)]) }
                    if let choices = object["choices"] as? [[String:Any]], let choice = choices.first {
                        if let delta = choice["delta"] as? [String:Any], let content = delta["content"] as? String,
                           let index = messages.firstIndex(where: { $0.id == answerID }) { messages[index].content += content }
                        if let reason = choice["finish_reason"] as? String { finished = true; if reason == "length" { status = "Resposta atingiu o limite configurado." } }
                    }
                }
                save()
                if status != "Resposta atingiu o limite configurado." { status = finished ? "Resposta em \(Int(Date().timeIntervalSince(started))) s • no seu Mac" : "Conexão interrompida. A resposta parcial foi salva." }

            } catch { save(); if !Task.isCancelled { status = "Falha: \(error.localizedDescription)" } }
        }
    }
}
struct MessageView: View {
    let message: Message
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(message.role == "user" ? "Você" : "Qwen", systemImage: message.role == "user" ? "person.circle" : "sparkles").font(.subheadline.bold()).foregroundStyle(.secondary)
                Spacer()
                Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(message.content, forType: .string) } label: { Image(systemName:"doc.on.doc") }.buttonStyle(.borderless).help("Copiar mensagem")
            }
            ForEach(Array(message.content.components(separatedBy: "```").enumerated()), id: \.offset) { index, part in
                if index % 2 == 1 {
                    ScrollView(.horizontal) { Text(part.trimmingCharacters(in:.newlines)).font(.system(.callout,design:.monospaced)).textSelection(.enabled).padding(14) }.background(Color.black.opacity(0.18)).clipShape(RoundedRectangle(cornerRadius:8))
                } else {
                    Text((try? AttributedString(markdown:part, options:.init(interpretedSyntax:.inlineOnlyPreservingWhitespace))) ?? AttributedString(part)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)
                }
            }
        }.padding(20).background(message.role == "user" ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.045)).clipShape(RoundedRectangle(cornerRadius:14))
    }
}
struct ContentView: View {
    @ObservedObject var store: Store
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment:.leading, spacing:16) {
                Label("Qwen Local", systemImage:"sparkles").font(.title3.bold()).padding(.top,12)
                Button { store.newChat() } label: { Label("Nova conversa", systemImage:"square.and.pencil").frame(maxWidth:.infinity) }.disabled(store.generating).keyboardShortcut("n",modifiers:.command)
                Text("CONVERSAS").font(.caption2.bold()).foregroundStyle(.secondary)
                ScrollView {
                    VStack(spacing:6) {
                        ForEach(store.conversations) { chat in
                            Button { store.select(chat) } label: {
                                Text(chat.title).lineLimit(2).frame(maxWidth:.infinity,alignment:.leading).padding(10).background(store.selected == chat.id ? Color.accentColor.opacity(0.15) : Color.clear).clipShape(RoundedRectangle(cornerRadius:8))
                            }.buttonStyle(.plain).disabled(store.generating)
                        }
                    }
                }
                Divider()
                Label("Processamento local",systemImage:"lock.shield").font(.caption).foregroundStyle(.secondary)
                Button("Configurações") { store.showSettings.toggle() }
                Button("Exportar conversa") { store.export() }.disabled(store.messages.isEmpty || store.generating)
            }.padding(16).frame(width:210).background(Color.secondary.opacity(0.04))
            Divider()
            VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Qwen Local").font(.title2.bold())
                    Text("MLX · processamento no Mac").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Circle().fill(store.running ? Color.green : Color.gray).frame(width: 8, height: 8)
                Text(store.running ? "Local ativo" : "Desligado").font(.caption)
            }.padding(20)
            HStack {
                Text(store.modelID.components(separatedBy:"/").last ?? store.modelID).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if store.process == nil {
                    Button("Iniciar modelo") { store.run("start") }.buttonStyle(.borderedProminent)
                } else {
                    Button(store.generating ? "Interromper e liberar RAM" : "Desligar modelo") { store.stop() }
                }
            }.padding(.horizontal,24).padding(.bottom,16)
            WorkspaceBar(store:store)
            if store.showSettings {
                ScrollView {
                VStack(alignment:.leading,spacing:12) {
                    HStack {
                        Text("Modelos para download").font(.headline)
                        Spacer()
                        Link("Catálogo MLX ↗",destination:URL(string:"https://huggingface.co/mlx-community")!)
                    }
                    ForEach(DownloadModel.catalog) { entry in
                        HStack(spacing:12) {
                            Image(systemName:store.availableModels.contains(entry.id) ? "checkmark.circle.fill" : "arrow.down.circle").foregroundStyle(store.availableModels.contains(entry.id) ? Color.green : Color.secondary)
                            VStack(alignment:.leading,spacing:3) {
                                Text(entry.title).font(.subheadline.bold())
                                Text(entry.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Link("Detalhes",destination:URL(string:"https://huggingface.co/" + entry.id)!).font(.caption)
                            if store.availableModels.contains(entry.id) {
                                Button(store.modelID == entry.id ? "Selecionado" : "Usar") { store.modelID = entry.id }.disabled(store.process != nil || store.modelID == entry.id)
                            } else {
                                Button("Baixar") { store.download(entry.id) }.disabled(store.process != nil)
                            }
                        }.padding(10).background(Color.secondary.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius:8))
                    }
                    Text("Downloads individuais. Apenas um modelo é carregado por vez. Os modelos 2B e 4B ainda não foram testados neste aplicativo.").font(.caption).foregroundStyle(.secondary)
                    Divider()
                    Text("Selecionar ou adicionar outro modelo MLX").font(.subheadline.bold())
                    Picker("Modelo",selection:$store.modelID) {
                        ForEach(store.models,id: \.self) { model in Text(model).tag(model) }
                    }.disabled(store.process != nil)
                    HStack {
                        TextField("Hugging Face: organização/modelo",text:$store.newModel)
                        Button("Adicionar") { store.addModel() }.disabled(store.newModel.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                        Button("Escolher pasta…") { store.chooseFolder() }
                    }.disabled(store.process != nil)
                    Text(store.process == nil ? "Adicione modelos compatíveis com MLX. GGUF exige outro motor. Para modelos novos, baixe antes de iniciar." : "Desligue o modelo atual para selecionar outro.").font(.caption).foregroundStyle(.secondary)
                    Divider()
                    HStack {
                        Text("Tamanho máximo da resposta")
                        Picker("",selection:$store.maxTokens) { Text("Curta · 1024").tag(1024); Text("Padrão · 2048").tag(2048); Text("Longa · 4096").tag(4096) }.labelsHidden().frame(width:180)
                    }
                    HStack { Text("Criatividade"); Slider(value:$store.temperature,in:0...1).frame(width:180); Text(store.temperature,format:.number.precision(.fractionLength(1))) }
                    HStack { Button("Preparar ambiente") { store.run("setup") }; Button("Baixar modelo") { store.run("download") }; Button("Registros") { store.showLogs.toggle() } }.disabled(store.process != nil)
                    Text("API local: http://127.0.0.1:12345/v1").font(.caption).textSelection(.enabled).foregroundStyle(.secondary)
                }.padding(16).frame(maxWidth:.infinity,alignment:.leading).disabled(store.generating)
                }.frame(maxHeight:400).background(Color.secondary.opacity(0.06))
            }
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        if store.messages.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Sua IA, no seu Mac.").font(.largeTitle.bold())
                                Text("Prepare o ambiente uma vez e baixe o modelo. Depois, inicie e converse offline.").foregroundStyle(.secondary)
                                Text("O download ocupa vários GB. O primeiro pedido carrega o modelo na memória. Ative o agente para consultar documentos, editar arquivos e executar comandos na pasta de trabalho.").font(.callout).foregroundStyle(.secondary)
                            }.padding(.vertical,50)
                        }
                        ForEach(store.messages) { m in
                            MessageView(message:m).id(m.id)
                        }
                        if store.generating { ProgressView("Processando…").padding() }
                    }.frame(maxWidth:900).frame(maxWidth:.infinity).padding(20)
                }.onChange(of: store.messages.last?.content) { _, _ in if let id = store.messages.last?.id { proxy.scrollTo(id, anchor: .bottom) } }
            }
            Divider()
            HStack(alignment:.bottom) {
                TextEditor(text:$store.input).font(.body).frame(height:65).padding(6).overlay(RoundedRectangle(cornerRadius:8).stroke(Color.secondary.opacity(0.25)))
                Button("Enviar") { store.send() }.keyboardShortcut(.return,modifiers:.command).disabled(!store.running || store.generating || store.input.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
            }.padding(16)
            HStack {
                if store.working { ProgressView().controlSize(.small) }
                Text(store.status).font(.caption).lineLimit(2)
                Spacer()
                Text("⌘ ↵ para enviar").font(.caption).foregroundStyle(.secondary)
                Button("Registros") { store.showLogs.toggle() }
            }.padding(.horizontal,16).padding(.bottom,12)
            if store.showLogs { ScrollView { Text(store.logs.isEmpty ? "Sem registros." : store.logs).font(.system(.caption,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }.frame(height:140).padding(12) }
            }
        }.frame(minWidth:1080,minHeight:760)
        .sheet(item:$store.pending) { proposal in ReviewView(store:store,proposal:proposal).interactiveDismissDisabled() }
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
