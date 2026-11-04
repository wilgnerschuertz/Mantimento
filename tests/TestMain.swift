import Foundation
import Combine
@main struct AgentTests {
    @MainActor static func main() async throws {
        let compatibility = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:compatibility,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:compatibility) }
        guard StoragePaths.dataDirectory(in:compatibility).lastPathComponent == "Mantimento" else { fatalError("Nome de dados novos") }
        try FileManager.default.createDirectory(at:compatibility.appendingPathComponent("QwenLocal"),withIntermediateDirectories:true)
        guard StoragePaths.dataDirectory(in:compatibility).lastPathComponent == "QwenLocal" else { fatalError("Dados antigos perdidos") }
        try FileManager.default.createDirectory(at:compatibility.appendingPathComponent("Mantimento"),withIntermediateDirectories:true)
        guard StoragePaths.dataDirectory(in:compatibility).lastPathComponent == "Mantimento" else { fatalError("Preferência por dados novos") }
        let suite = "mantimento-test-\(UUID().uuidString)"
        let prefs = UserDefaults(suiteName:suite)!
        defer { prefs.removePersistentDomain(forName:suite) }
        AppIdentity.migratePreferences(from:["modelID":"modelo-antigo", "models":["modelo-antigo"]],to:prefs)
        guard prefs.string(forKey:"modelID") == "modelo-antigo" else { fatalError("Preferência antiga perdida") }
        prefs.set("modelo-novo",forKey:"modelID")
        AppIdentity.migratePreferences(from:["modelID":"modelo-antigo"],to:prefs)
        guard prefs.string(forKey:"modelID") == "modelo-novo" else { fatalError("Preferência atual sobrescrita") }
        print("PASSOU: Mantimento novo, dados legados e migração de preferências sem sobrescrita")
        let oldJSON = "{\"id\":\"00000000-0000-0000-0000-000000000001\",\"role\":\"assistant\",\"content\":\"Resposta antiga\"}"
        let oldMessage = try JSONDecoder().decode(Message.self,from:Data(oldJSON.utf8))
        guard oldMessage.modelName == nil else { fatalError("Conversa legada não abriu") }
        let named = Message(role:"assistant",content:"Resposta",modelName:"Llama 3.2 3B")
        let restored = try JSONDecoder().decode(Message.self,from:JSONEncoder().encode(named))
        guard restored.modelName == "Llama 3.2 3B" else { fatalError("Identidade do modelo perdida") }
        let s = Store()
        let server = Process(); server.executableURL = URL(fileURLWithPath:"/bin/sleep"); server.arguments = ["30"]
        try server.run(); s.process = server; s.running = true
        s.cancelReply()
        guard server.isRunning, s.process === server, s.running else { fatalError("Interromper resposta desligou o servidor") }
        server.terminate(); server.waitUntilExit(); s.process = nil; s.running = false
        s.ensureWorkspace()
        let root = URL(fileURLWithPath:s.workspace)
        for path in ["../escape.txt", "../outside/no.txt", ".git/config"] {
            do { _ = try LocalTools.resolve(path,workspace:s.workspace); fatalError("Traversal aceito") } catch {}
        }
        try FileManager.default.createSymbolicLink(at:root.appendingPathComponent("outside"),withDestinationURL:root.deletingLastPathComponent())
        do { _ = try LocalTools.resolve("outside/escape.txt",workspace:s.workspace); fatalError("Symlink aceito") } catch {}
        s.fullControl = false
        let pendingWrite = Task { try await s.tool("write_file",args:["path":"note.txt","content":"Primeira versão"]) }
        while s.pending == nil { try await Task.sleep(nanoseconds:10_000_000) }
        guard !FileManager.default.fileExists(atPath:root.appendingPathComponent("note.txt").path) else { fatalError("Escrita antes de aprovação") }
        s.approve(false)
        _ = try await pendingWrite.value
        guard !FileManager.default.fileExists(atPath:root.appendingPathComponent("note.txt").path) else { fatalError("Recusa ignorada") }
        let approvedWrite = Task { try await s.tool("write_file",args:["path":"note.txt","content":"Primeira versão"]) }
        while s.pending == nil { try await Task.sleep(nanoseconds:10_000_000) }
        s.approve(true); _ = try await approvedWrite.value
        s.fullControl = true
        _ = try await s.tool("write_file",args:["path":"note.txt","content":"Segunda versão"])
        guard try LocalTools.read("note.txt",workspace:s.workspace).contains("Segunda versão") else { fatalError("Leitura") }
        let search = try await s.tool("search_files",args:["query":"Segunda"])
        guard search.contains("note.txt") else { fatalError("Pesquisa: \(search) arquivos=\(LocalTools.files(s.workspace)) raiz=\(s.workspace)") }
        guard FileManager.default.fileExists(atPath:root.appendingPathComponent(".qwen-backups").path) else { fatalError("Backup ausente") }
        let command = try await s.tool("run_command",args:["command":"printf 'terminal funcionando'"])
        guard command.contains("terminal funcionando"), command.contains("\"exit_code\": 0") else { fatalError("Terminal falhou: \(command)") }
        let previous = s.workspace; s.save(); s.newChat()
        guard s.workspace != previous else { fatalError("Pasta default compartilhada") }
        s.select(s.conversations.first(where:{$0.workspace == previous})!)
        guard s.workspace == previous else { fatalError("Pasta não restaurada") }
        print("PASSOU: confinamento, symlink, recusa, aprovação, escrita, backup, leitura, pesquisa, terminal e pastas por conversa")
        if ProcessInfo.processInfo.environment["TEST_STREAM"] == "1" {
            s.messages = []; s.running = true; s.agentEnabled = false; s.input = "Teste de streaming"
            var updates = 0
            let observation = s.$messages.sink { _ in updates += 1 }
            s.send()
            for _ in 0..<200 {
                if !s.generating { break }
                try await Task.sleep(nanoseconds:100_000_000)
            }
            guard s.messages.last?.content == String(repeating:"á",count:200), !s.generating else { fatalError("Streaming perdeu conteúdo: \(s.messages.last?.content ?? "vazio") \(s.status)") }
            let author = s.messages.last?.modelName
            guard author == s.displayModel else { fatalError("Identidade ausente no streaming") }
            s.modelID = "mlx-community/Phi-4-mini-instruct-4bit"
            guard s.messages.last?.modelName == author else { fatalError("Troca de modelo alterou autoria antiga") }
            guard updates < 20 else { fatalError("Atualizações não agrupadas: \(updates)") }
            observation.cancel()
            print("PASSOU: 200 trechos UTF-8 preservados; \(updates) publicações de mensagens")
        }
        if ProcessInfo.processInfo.environment["TEST_MODEL"] == "1" {
            s.fullControl = true; s.agentEnabled = true; s.running = true
            s.messages = []; s.input = "Use write_file para criar o arquivo agent-proof.txt com o conteúdo exato: agente offline funcionando. Depois use read_file para confirmar e conclua."
            s.send()
            for _ in 0..<2400 {
                if !s.generating { break }
                try await Task.sleep(nanoseconds:100_000_000)
            }
            guard !s.generating, let content = try? String(contentsOf:root.appendingPathComponent("agent-proof.txt"),encoding:.utf8), content.contains("agente offline funcionando") else { fatalError("Agente real falhou: \(s.status) \(s.messages)") }
            print("PASSOU: agente Qwen9B real criou arquivo com chamada de ferramenta. Status: \(s.status)")
        }
    }
}
