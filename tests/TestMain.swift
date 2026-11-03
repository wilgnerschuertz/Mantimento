import Foundation
import Combine
@main struct AgentTests {
    @MainActor static func main() async throws {
        let s = Store()
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
