import Foundation
import Combine
@main struct AgentTests {
    @MainActor static func main() async throws {
        defer {
            if let path = ProcessInfo.processInfo.environment["TEST_DATA"] {
                AppIdentity.defaults.removePersistentDomain(forName:"mantimento-isolated-test-" + path)
            }
        }
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
        let legacyConversation = "{\"id\":\"00000000-0000-0000-0000-000000000001\",\"title\":\"Antiga\",\"messages\":[]}"
        guard try JSONDecoder().decode(Conversation.self,from:Data(legacyConversation.utf8)).originID == nil else { fatalError("Origem legada") }
        let unicodeHistory = [Message(role:"user",content:String(repeating:"🌱á漢",count:4000))]
        let chunks = ContextBudget.chunks(unicodeHistory)
        guard chunks.allSatisfy({ $0.utf8.count <= 8000 && $0.utf8.count > 1000 }), chunks.joined() == "user:\n" + unicodeHistory[0].content else { fatalError("Fragmentação Unicode perdeu conteúdo") }
        let shortRecords = (1...60).map { Message(role:"user",content:"Registro \($0): " + String(repeating:"decisão ",count:25)) }
        let packed = ContextBudget.chunks(shortRecords)
        guard packed.allSatisfy({ $0.utf8.count <= 8000 && $0.contains("Registro") }),
              packed.joined() == shortRecords.map({ "\($0.role):\n\($0.content)" }).joined(separator:"\n\n") else { fatalError("Divisão separou mensagens curtas ou perdeu conteúdo") }
        let s = Store()
        let server = Process(); server.executableURL = URL(fileURLWithPath:"/bin/sleep"); server.arguments = ["30"]
        try server.run(); s.process = server; s.running = true
        s.cancelReply()
        guard server.isRunning, s.process === server, s.running else { fatalError("Interromper resposta desligou o servidor") }
        server.terminate(); server.waitUntilExit(); s.process = nil; s.running = false
        let idleServer = Process(); idleServer.executableURL = URL(fileURLWithPath:"/bin/sleep"); idleServer.arguments = ["30"]
        try idleServer.run(); s.process = idleServer; s.running = true
        s.idleUnloadMinutes = 0; s.unloadIfIdle(idleServer)
        guard idleServer.isRunning else { fatalError("Desligamento desativado foi ignorado") }
        s.idleUnloadMinutes = 10; s.generating = true; s.unloadIfIdle(idleServer)
        guard idleServer.isRunning else { fatalError("Desligamento interrompeu resposta") }
        s.generating = false
        s.unloadIfIdle(Process())
        guard idleServer.isRunning else { fatalError("Temporizador antigo desligou outro servidor") }
        s.unloadIfIdle(idleServer); idleServer.waitUntilExit()
        guard !s.running, s.unloadedForIdle, s.idleUnloadTask == nil else { fatalError("Modelo não liberado") }
        s.process = nil
        print("PASSOU: desligamento ocioso, opção Nunca, proteção de resposta e identidade do processo")
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
        let savedMessages = s.messages
        s.messages = unicodeHistory; s.input = "Pergunta preservada"; s.running = true
        for agent in [false,true] {
            s.agentEnabled = agent; s.send()
            guard !s.generating, s.messages == unicodeHistory, s.input == "Pergunta preservada" else { fatalError("Orçamento de contexto perdeu histórico ou rascunho") }
        }
        s.messages = savedMessages; s.input = ""; s.running = false; s.agentEnabled = false
        print("PASSOU: limite UTF-8 impede pedidos excessivos sem perder mensagens ou rascunho")
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
            guard let timing = s.generationInfo.components(separatedBy:" s").first?.components(separatedBy:": ").last,
                  (Double(timing.replacingOccurrences(of:",",with:".")) ?? 0) >= 0.3 else { fatalError("Latência não inclui espera pelo servidor: \(s.generationInfo)") }
            guard updates < 20 else { fatalError("Atualizações não agrupadas: \(updates)") }
            observation.cancel()
            print("PASSOU: 200 trechos UTF-8 preservados; \(updates) publicações de mensagens")
            s.messages = unicodeHistory; s.save()
            let originalID = s.selected!; let originalWorkspace = s.workspace
            let originalContent = s.messages
            s.input = "Minha próxima pergunta"; s.fullControl = true
            s.summarizeConversation()
            for _ in 0..<200 {
                if !s.generating { break }
                try await Task.sleep(nanoseconds:50_000_000)
            }
            guard s.summaryDraft != nil, s.selected == originalID, s.messages == originalContent else { fatalError("Resumo alterou histórico ou não chegou") }
            s.continueFromSummary()
            guard s.selected != originalID, s.originConversation?.id == originalID,
                  s.workspace == originalWorkspace, !s.fullControl,
                  s.input == "Minha próxima pergunta",
                  s.conversations.first(where: { $0.id == originalID })?.messages == originalContent,
                  ContextBudget.size(s.messages) < ContextBudget.warning else { fatalError("Continuação perdeu origem, pasta, rascunho ou permissões") }
            s.save()
            let archive = try JSONDecoder().decode([Conversation].self,from:Data(contentsOf:s.archive))
            guard archive.first?.originID == originalID, archive.first(where: { $0.id == originalID })?.messages == originalContent else { fatalError("Persistência da continuação") }
            let currentID = s.selected
            s.summarizeConversation(); s.cancelReply()
            for _ in 0..<100 {
                if !s.generating { break }
                try await Task.sleep(nanoseconds:20_000_000)
            }
            guard s.summaryDraft == nil, s.selected == currentID else { fatalError("Resumo cancelado criou continuação") }
            for marker in ["__SUMMARY_ERROR__","__SUMMARY_TRUNCATED__","__SUMMARY_OVERSIZE__"] {
                s.messages = [Message(role:"user",content:marker)]; s.save()
                let before = try Data(contentsOf:s.archive)
                s.summarizeConversation()
                for _ in 0..<100 {
                    if !s.generating { break }
                    try await Task.sleep(nanoseconds:20_000_000)
                }
                guard s.summaryDraft == nil, try Data(contentsOf:s.archive) == before else { fatalError("Falha de resumo mudou arquivo ou gerou revisão inválida") }
            }
            s.summaryDraft = SummaryDraft(sourceID:s.selected!); s.summaryText = "Resumo de teste"
            let archiveBackup = s.archive.appendingPathExtension("test-backup")
            try FileManager.default.moveItem(at:s.archive,to:archiveBackup)
            try FileManager.default.createDirectory(at:s.archive,withIntermediateDirectories:false)
            let beforeID = s.selected; let beforeCount = s.conversations.count
            s.continueFromSummary()
            guard s.selected == beforeID, s.conversations.count == beforeCount, s.summaryDraft != nil else { fatalError("Falha de disco alterou continuação") }
            try FileManager.default.removeItem(at:s.archive)
            try FileManager.default.moveItem(at:archiveBackup,to:s.archive)
            s.summaryDraft = nil
            print("PASSOU: resumo em partes Unicode, revisão, cancelamento, origem persistida, histórico intacto e permissões reiniciadas")
            print("PASSOU: erro HTTP, resumo truncado/grande e falha de disco preservam histórico")

        }
        if ProcessInfo.processInfo.environment["TEST_SUMMARY_REAL"] == "1" {
            s.running = true; s.agentEnabled = false
            let decisions = "Projeto Mantimento de teste: usar Python e SQLite, banco tarefas.db, sem serviços externos. Releia os arquivos antes de editar. Pendente: testar restauração dos backups."
            s.messages = (1...60).map { Message(role:$0 % 2 == 0 ? "assistant" : "user",content:"Registro \($0). " + decisions) }
            s.save(); let sourceID = s.selected; let original = s.messages
            s.summarizeConversation()
            for _ in 0..<3000 {
                if !s.generating { break }
                try await Task.sleep(nanoseconds:100_000_000)
            }
            guard !s.generating, s.summaryDraft != nil, s.messages == original,
                  s.summaryText.localizedCaseInsensitiveContains("SQLite"),
                  s.summaryText.contains("tarefas.db") else { fatalError("Resumo real falhou: \(s.status) \(s.summaryText)") }
            let summary = s.summaryText
            s.continueFromSummary()
            guard s.selected != sourceID, s.originConversation?.messages == original else { fatalError("Continuação real perdeu histórico") }
            print("PASSOU: Qwen3.5 9B resumiu histórico em partes, preservou SQLite/tarefas.db e criou continuação. Resumo: \(summary)")
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
