import SwiftUI
import AppKit

struct RenderBlock: Identifiable {
    let id: Int
    let text: String
    let code: Bool
    static func parse(_ text:String) -> [RenderBlock] {
        text.components(separatedBy:"```").enumerated().map { RenderBlock(id:$0.offset,text:$0.element,code:$0.offset % 2 == 1) }
    }
}
struct MessageView: View, Equatable {
    let message: Message
    static func ==(lhs:Self,rhs:Self) -> Bool { lhs.message == rhs.message }
    var body: some View {
        if message.content.hasPrefix("Ferramenta:") {
            DisclosureGroup {
                ScrollView(.horizontal) { Text(message.content).font(.system(.caption,design:.monospaced)).textSelection(.enabled).padding(.top,8) }
            } label: { Label(String(message.content.components(separatedBy:"\n").first ?? "Ação local"),systemImage:"terminal").font(.callout).foregroundStyle(.secondary) }
            .padding(14).background(Color.secondary.opacity(0.05),in:RoundedRectangle(cornerRadius:12))
        } else {
            VStack(alignment:.leading,spacing:12) {
                HStack(spacing:8) {
                    Image(systemName:message.role == "user" ? "person.crop.circle" : "sparkles").foregroundStyle(message.role == "user" ? Color.secondary : Color.accentColor)
                    Text(message.role == "user" ? "Você" : "Qwen").font(.subheadline.weight(.semibold))
                    Spacer()
                    Button { copy(message.content) } label:{ Image(systemName:"doc.on.doc").font(.caption) }.buttonStyle(.plain).foregroundStyle(.secondary).help("Copiar mensagem")
                }
                if message.content.isEmpty { Text("Preparando resposta…").foregroundStyle(.secondary) }
                ForEach(RenderBlock.parse(message.content)) { block in
                    if block.code { code(block.text) }
                    else {
                        VStack(alignment:.leading,spacing:5) {
                            ForEach(Array(block.text.components(separatedBy:"\n").enumerated()),id:\.offset) { _, line in
                                lineView(line)
                            }
                        }.frame(maxWidth:.infinity,alignment:.leading)
                    }
                }
            }.padding(20).background(message.role == "user" ? Color.accentColor.opacity(0.075) : Color.clear,in:RoundedRectangle(cornerRadius:18))
        }
    }
    func copy(_ text:String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text,forType:.string) }
    func inline(_ text:String) -> Text {
        Text((try? AttributedString(markdown:text,options:.init(interpretedSyntax:.inlineOnlyPreservingWhitespace))) ?? AttributedString(text))
    }
    @ViewBuilder func lineView(_ line:String) -> some View {
        let trimmed = line.trimmingCharacters(in:.whitespaces)
        if trimmed.hasPrefix("#") && trimmed.contains(" ") {
            let heading = String(trimmed.drop(while:{$0 == "#" || $0 == " "}))
            inline(heading).font(.headline).padding(.top,10).textSelection(.enabled)
        } else if trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ") {
            HStack(alignment:.top,spacing:9) { Text("•").foregroundStyle(.secondary); inline(String(trimmed.dropFirst(2))).textSelection(.enabled) }.padding(.leading,4)
        } else if trimmed.isEmpty { Color.clear.frame(height:5) }
        else { inline(line).textSelection(.enabled).lineSpacing(4) }
    }
    func code(_ text:String) -> some View {
        let lines = text.components(separatedBy:"\n")
        let first = lines.first ?? ""
        let language = first.trimmingCharacters(in:.whitespaces)
        let hasLanguage = ["python","py","swift","javascript","js","typescript","ts","json","html","css","sql","bash","sh","zsh","text","txt","markdown","md","yaml","yml","xml","c","cpp","rust","go","java"].contains(language.lowercased())
        let body = hasLanguage ? lines.dropFirst().joined(separator:"\n").trimmingCharacters(in:.newlines) : text.trimmingCharacters(in:.newlines)
        return VStack(spacing:0) {
            HStack { Text(hasLanguage ? language : "Código").font(.caption.weight(.medium)); Spacer(); Button("Copiar código") { copy(body) }.buttonStyle(.plain).font(.caption) }.foregroundStyle(.secondary).padding(.horizontal,14).padding(.vertical,10)
            Divider()
            ScrollView(.horizontal) { Text(body).font(.system(.callout,design:.monospaced)).textSelection(.enabled).padding(14).frame(maxWidth:.infinity,alignment:.leading) }
        }.background(Color(nsColor:.textBackgroundColor),in:RoundedRectangle(cornerRadius:12)).overlay(RoundedRectangle(cornerRadius:12).stroke(Color.secondary.opacity(0.13)))
    }
}
struct ContentView: View {
    @ObservedObject var store: Store
    var chats:[Conversation] { store.conversations.filter { store.chatQuery.isEmpty || $0.title.localizedCaseInsensitiveContains(store.chatQuery) } }
    var body: some View {
        HStack(spacing:0) {
            VStack(alignment:.leading,spacing:16) {
                HStack(spacing:10) {
                    Image(systemName:"sparkles").font(.title2).foregroundStyle(Color.accentColor)
                    VStack(alignment:.leading,spacing:2) { Text("Qwen Local").font(.headline); Text("Seu espaço offline").font(.caption).foregroundStyle(.secondary) }
                }.padding(.top,10)
                Button { store.newChat() } label: { Label("Nova conversa",systemImage:"square.and.pencil").frame(maxWidth:.infinity).padding(.vertical,5) }.buttonStyle(.borderedProminent).disabled(store.generating).keyboardShortcut("n",modifiers:.command)
                TextField("Buscar conversas",text:$store.chatQuery).textFieldStyle(.roundedBorder)
                Text("CONVERSAS").font(.system(size:10,weight:.semibold)).tracking(1.2).foregroundStyle(.secondary)
                ScrollView {
                    LazyVStack(spacing:5) {
                        ForEach(chats) { chat in
                            Button { store.select(chat) } label: {
                                HStack(alignment:.top,spacing:8) { Image(systemName:"bubble.left").font(.caption).padding(.top,2); Text(chat.title).font(.callout).lineLimit(2); Spacer(minLength:0) }
                                .padding(11).frame(maxWidth:.infinity,alignment:.leading).background(store.selected == chat.id ? Color.accentColor.opacity(0.13) : Color.clear,in:RoundedRectangle(cornerRadius:10))
                            }.buttonStyle(.plain).disabled(store.generating)
                        }
                    }
                }
                Divider()
                Label("Dados no seu Mac",systemImage:"lock.shield").font(.caption).foregroundStyle(.secondary)
                Button { store.showSettings = true } label:{ Label("Modelos e ajustes",systemImage:"slider.horizontal.3") }.buttonStyle(.plain).disabled(store.generating)
                Button { store.export() } label:{ Label("Exportar conversa",systemImage:"square.and.arrow.up") }.buttonStyle(.plain).disabled(store.messages.isEmpty || store.generating)
            }.padding(18).frame(width:220).background(.regularMaterial)
            Divider()
            VStack(spacing:0) {
                header
                WorkspaceBar(store:store)
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment:.leading,spacing:16) {
                            if store.messages.isEmpty { welcome }
                            ForEach(store.messages) { message in MessageView(message:message).equatable().id(message.id) }
                            Color.clear.frame(height:1).id("bottom")
                        }.frame(maxWidth:820).padding(.horizontal,28).padding(.vertical,24).frame(maxWidth:.infinity)
                    }.onChange(of:store.messages.last?.content) { _, _ in if store.autoScroll { proxy.scrollTo("bottom",anchor:.bottom) } }
                    .onChange(of:store.selected) { _, _ in proxy.scrollTo("bottom",anchor:.bottom) }
                }
                composer
                HStack(spacing:10) {
                    if store.working || store.generating { ProgressView().controlSize(.mini) }
                    Text(store.status).lineLimit(2)
                    Spacer()
                    Toggle("Acompanhar resposta",isOn:$store.autoScroll).toggleStyle(.checkbox)
                    Button { store.showLogs.toggle() } label: { Image(systemName:"terminal") }.buttonStyle(.plain).help("Registros")
                }.font(.caption).foregroundStyle(.secondary).padding(.horizontal,22).padding(.bottom,12)
                if store.showLogs { ScrollView { Text(store.logs.isEmpty ? "Sem registros." : store.logs).font(.system(.caption,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading).padding(12) }.frame(height:130).background(Color(nsColor:.textBackgroundColor)) }
            }.background(Color(nsColor:.windowBackgroundColor))
        }.frame(minWidth:1020,minHeight:720)
        .sheet(isPresented:$store.showSettings) { SettingsView(store:store) }
        .sheet(item:$store.pending) { proposal in ReviewView(store:store,proposal:proposal).interactiveDismissDisabled() }
    }
    var header:some View {
        HStack(spacing:12) {
            VStack(alignment:.leading,spacing:4) {
                Text(store.conversations.first(where:{$0.id == store.selected})?.title ?? "Nova conversa").font(.title3.weight(.semibold)).lineLimit(1)
                HStack(spacing:6) { Circle().fill(store.running ? Color.green : Color.secondary.opacity(0.4)).frame(width:6,height:6); Text(store.modelID.components(separatedBy:"/").last ?? store.modelID); Text("·"); Text(store.running ? "Local ativo" : "Modelo desligado") }.font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if store.process == nil {
                Button { store.run("start") } label: { Label("Iniciar",systemImage:"play.fill") }.buttonStyle(.bordered).disabled(store.generating)
            } else {
                Button { store.stop() } label: { Label(store.generating ? "Interromper" : "Liberar memória",systemImage:"stop.fill") }.buttonStyle(.bordered)
            }
        }.padding(.horizontal,24).padding(.vertical,18)
    }
    var welcome:some View {
        VStack(alignment:.leading,spacing:18) {
            Image(systemName:"sparkles").font(.system(size:36,weight:.light)).foregroundStyle(Color.accentColor)
            Text("Um espaço para pensar\ne construir.").font(.system(size:32,weight:.semibold,design:.rounded))
            Text("Converse com seu modelo ou ative o agente para trabalhar com os arquivos desta pasta.").font(.body).foregroundStyle(.secondary).lineSpacing(4)
            HStack(spacing:10) {
                suggestion("Consultar documentos","Leia os documentos desta pasta e resuma os principais pontos.")
                suggestion("Criar um projeto","Crie um CRUD simples em Python e SQLite nesta pasta, sem dependências externas. Teste as operações.")
            }
        }.padding(.vertical,45).padding(.horizontal,12)
    }
    func suggestion(_ title:String,_ prompt:String) -> some View {
        Button { store.input = prompt } label: { HStack { Text(title); Image(systemName:"arrow.up.left") }.font(.callout).padding(10) }.buttonStyle(.bordered)
    }
    var composer:some View {
        VStack(spacing:8) {
            HStack(alignment:.bottom,spacing:12) {
                TextEditor(text:$store.input).font(.body).scrollContentBackground(.hidden).frame(height:66).padding(6).accessibilityLabel("Mensagem")
                Button { store.send() } label:{ Image(systemName:"arrow.up").font(.body.bold()).frame(width:24,height:28) }.buttonStyle(.borderedProminent).keyboardShortcut(.return,modifiers:.command).disabled(!store.running || store.generating || store.input.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty).help("Enviar · ⌘ Return")
            }.padding(10).background(Color(nsColor:.textBackgroundColor),in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(Color.secondary.opacity(0.15)))
            HStack { Text(store.agentEnabled ? "Agente local · arquivos e terminal" : "Conversa · ⌘ Return para enviar"); Spacer(); Text(store.generationInfo) }.font(.system(size:10)).foregroundStyle(.secondary)
        }.frame(maxWidth:900).padding(.horizontal,22).padding(.top,8).padding(.bottom,12).frame(maxWidth:.infinity)
    }
}
