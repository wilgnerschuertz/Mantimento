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
                    Text(message.role == "user" ? "Você" : (message.modelName ?? "Assistente")).font(.subheadline.weight(.semibold))
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
enum AppPage: String, CaseIterable, Identifiable {
    case chat = "Conversa", models = "Modelos", backup = "Backup offline"
    var id: String { rawValue }
    var icon: String { switch self { case .chat: "bubble.left.and.bubble.right"; case .models: "square.stack.3d.up"; case .backup: "externaldrive" } }
}
@MainActor final class LayoutState:ObservableObject {
    @Published var page:AppPage = .chat
    @Published var columns:NavigationSplitViewVisibility = .all
    @Published var editorWidth:CGFloat = 480
    @Published var compactHeight = false
}
struct ContentView: View {
    @ObservedObject var store: Store
    @StateObject private var layout = LayoutState()
    @AppStorage("appearance") private var appearance = "Sistema"
    var body: some View {
        GeometryReader { geometry in
            NavigationSplitView(columnVisibility:$layout.columns) {
                sidebar.navigationSplitViewColumnWidth(min:200,ideal:225,max:280)
            } detail: {
                VStack(spacing:0) {
                    switch layout.page {
                    case .chat: chat
                    case .models: ModelsView(store:store)
                    case .backup: BackupView(store:store)
                    }
                    OperationStatusView(store:store)
                }.background(Color(nsColor:.windowBackgroundColor))
                .toolbar {
                    ToolbarItem(placement:.principal) { Text(layout.page.rawValue).font(.headline) }
                    ToolbarItem { Button { store.showSettings = true } label: { Label("Ajustes",systemImage:"gearshape") }.help("Ajustes · ⌘ ,").keyboardShortcut(",",modifiers:.command) }
                }
            }.onChange(of:geometry.size.width,initial:true) { old, width in
                if width < 940 && (old >= 940 || old == width) { layout.columns = .detailOnly }
            }.onChange(of:geometry.size.height,initial:true) { _, height in layout.compactHeight = height < 650 }
        }.frame(minWidth:720,minHeight:560)
        .preferredColorScheme(appearance == "Claro" ? .light : appearance == "Escuro" ? .dark : nil)
        .sheet(isPresented:$store.showSettings,onDismiss:{ if store.logsAfterSettings { store.logsAfterSettings = false; store.showLogs = true } }) { SettingsView(store:store) }
        .sheet(item:$store.pending) { proposal in ReviewView(store:store,proposal:proposal).interactiveDismissDisabled() }
    }
    var sidebar: some View {
        VStack(alignment:.leading,spacing:16) {
            Label("Mantimento",systemImage:"sparkles").font(.title3.weight(.semibold)).padding(.top,8)
            VStack(spacing:4) {
                ForEach(AppPage.allCases) { destination in
                    Button { layout.page = destination } label: {
                        Label(destination.rawValue,systemImage:destination.icon).frame(maxWidth:.infinity,alignment:.leading).padding(10)
                            .background(layout.page == destination ? Color.accentColor.opacity(0.14) : Color.clear,in:RoundedRectangle(cornerRadius:9))
                    }.buttonStyle(.plain)
                }
            }
            Divider()
            Button { store.newChat(); layout.page = .chat } label: { Label("Nova conversa",systemImage:"square.and.pencil").frame(maxWidth:.infinity).padding(.vertical,4) }
                .buttonStyle(.borderedProminent).disabled(store.generating).keyboardShortcut("n",modifiers:.command)
            TextField("Buscar conversas",text:$store.chatQuery).textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVStack(alignment:.leading,spacing:4) {
                    ForEach(store.conversations.filter { store.chatQuery.isEmpty || $0.title.localizedCaseInsensitiveContains(store.chatQuery) }) { conversation in
                        Button { store.select(conversation); layout.page = .chat } label: {
                            Text(conversation.title).lineLimit(2).frame(maxWidth:.infinity,alignment:.leading).padding(10)
                                .background(store.selected == conversation.id && layout.page == .chat ? Color.secondary.opacity(0.12) : Color.clear,in:RoundedRectangle(cornerRadius:8))
                        }.buttonStyle(.plain).disabled(store.generating)
                    }
                }
            }
            Label("Conhecimento que fica",systemImage:"lock.shield").font(.caption).foregroundStyle(.secondary)
        }.padding(14)
    }
    var chat: some View {
        VStack(spacing:0) {
            ViewThatFits(in:.horizontal) {
                HStack(spacing:16) { conversationTitle; Spacer(minLength:8); modelControl }
                VStack(alignment:.leading,spacing:10) { conversationTitle; modelControl }
            }.padding(18)
            WorkspaceBar(store:store)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment:.leading,spacing:16) {
                        SetupGuide(store:store,openModels:{ layout.page = .models })
                        if store.messages.isEmpty && store.canStart { welcome }
                        ForEach(store.messages) { message in MessageView(message:message).equatable().id(message.id) }
                        Color.clear.frame(height:1).id("bottom")
                    }.background(ScrollIntentObserver { atBottom in store.autoScroll = atBottom }).frame(maxWidth:760).padding(.horizontal,18).padding(.vertical,20).frame(maxWidth:.infinity)
                }.onChange(of:store.messages.last?.content) { _, _ in
                    if store.autoScroll { proxy.scrollTo("bottom",anchor:.bottom) }
                }.onAppear { proxy.scrollTo("bottom",anchor:.bottom) }.onChange(of:store.selected) { _, _ in
                    store.autoScroll = true; proxy.scrollTo("bottom",anchor:.bottom)
                }.overlay(alignment:.bottom) {
                    if !store.autoScroll {
                        Button { store.autoScroll = true; proxy.scrollTo("bottom",anchor:.bottom) } label: {
                            Label("Última mensagem",systemImage:"arrow.down")
                        }.buttonStyle(.bordered).background(.regularMaterial,in:Capsule()).padding(12)
                    }
                }
            }
            composer
        }
    }
    var conversationTitle: some View {
        VStack(alignment:.leading,spacing:4) {
            Text(store.conversations.first(where:{$0.id == store.selected})?.title ?? "Nova conversa")
                .font(.title3.weight(.semibold)).lineLimit(1).truncationMode(.tail)
            Text(store.displayModel).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).help(store.modelID)
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
    var modelControl: some View {
        HStack(spacing:8) {
            if store.process == nil {
                Button("Iniciar modelo",systemImage:"play.fill") { store.run("start") }.disabled(!store.canStart || store.generating)
            } else {
                Button("Desligar",systemImage:"power") { store.stop() }
            }
            Menu {
                Button("Escolher modelo") { layout.page = .models }
                Button("Exportar conversa…") { store.export() }.disabled(store.messages.isEmpty || store.generating)
            } label: { Image(systemName:"ellipsis.circle") }.menuStyle(.borderlessButton).fixedSize().help("Opções da conversa")
        }.fixedSize()
    }
    var welcome: some View {
        VStack(alignment:.leading,spacing:18) {
            Image(systemName:"sparkles").font(.system(size:32,weight:.light)).foregroundStyle(Color.accentColor)
            Text("Conhecimento, sempre por perto.").font(.system(size:28,weight:.semibold,design:.rounded)).fixedSize(horizontal:false,vertical:true)
            Text("Converse com sua IA ou use o agente para trabalhar com os arquivos da pasta escolhida.").foregroundStyle(.secondary)
            ViewThatFits(in:.horizontal) {
                HStack { suggestion("Resumir documentos",agent:true); suggestion("Criar um projeto",agent:true) }
                VStack(alignment:.leading) { suggestion("Resumir documentos",agent:true); suggestion("Criar um projeto",agent:true) }
            }
        }.padding(.vertical,24)
    }
    func suggestion(_ title:String,agent:Bool) -> some View {
        Button {
            store.agentEnabled = agent
            store.input = title == "Criar um projeto" ? "Crie um CRUD simples em Python e SQLite nesta pasta, sem dependências externas. Teste as operações." : "Leia os documentos desta pasta e resuma os principais pontos."
        } label: { Label(title,systemImage:"arrow.up.left").padding(5) }.buttonStyle(.bordered).disabled(store.generating)
    }
    var composer: some View {
        VStack(spacing:8) {
            HStack(alignment:.bottom,spacing:10) {
                GeometryReader { geometry in
                    GrowingMessageEditor(text:$store.input).accessibilityLabel("Mensagem")
                        .onChange(of:geometry.size.width,initial:true) { _, width in layout.editorWidth = max(120,width - 20) }
                }.frame(height:editorHeight)
                if store.generating {
                    Button { store.cancelReply() } label: { Image(systemName:"stop.fill").frame(width:24,height:26) }.help("Interromper resposta")
                } else {
                    Button { store.autoScroll = true; store.send() } label: { Image(systemName:"arrow.up").font(.body.bold()).frame(width:24,height:26) }
                        .buttonStyle(.borderedProminent).keyboardShortcut(.return,modifiers:.command)
                        .disabled(!store.running || store.input.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty).help("Enviar · ⌘ Return")
                }
            }.padding(10).background(Color(nsColor:.textBackgroundColor),in:RoundedRectangle(cornerRadius:14))
                .overlay(RoundedRectangle(cornerRadius:14).stroke(Color.secondary.opacity(0.18)))
            ViewThatFits(in:.horizontal) {
                HStack { Text("⌘ Return para enviar"); Spacer(); Text(store.generationInfo) }
                Text("⌘ Return para enviar")
            }.font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth:800).padding(.horizontal,16).padding(.vertical,12).frame(maxWidth:.infinity)
    }
    // Width-aware text measurement is supplied by the native editor below.
    var editorHeight: CGFloat { min(layout.compactHeight ? 96 : 160,max(44,GrowingMessageEditor.measuredHeight(text:store.input,width:layout.editorWidth))) }
}

struct GrowingMessageEditor: NSViewRepresentable {
    @Binding var text: String
    static func measuredHeight(text:String,width:CGFloat) -> CGFloat {
        let bounds = (text + "\n").boundingRect(with:NSSize(width:width,height:.greatestFiniteMagnitude),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:[.font:NSFont.systemFont(ofSize:NSFont.systemFontSize)])
        return ceil(bounds.height) + 16
    }
    func makeNSView(context:Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let editor = scroll.documentView as! NSTextView
        editor.delegate = context.coordinator; editor.isRichText = false; editor.font = .systemFont(ofSize:NSFont.systemFontSize)
        editor.drawsBackground = false; scroll.drawsBackground = false
        editor.textContainerInset = NSSize(width:5,height:6); editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false; editor.isAutomaticTextReplacementEnabled = false
        editor.isHorizontallyResizable = false; editor.textContainer?.widthTracksTextView = true
        scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true; editor.setAccessibilityLabel("Mensagem")
        return scroll
    }
    func updateNSView(_ scroll:NSScrollView,context:Context) {
        context.coordinator.parent = self
        if let editor = scroll.documentView as? NSTextView, editor.string != text { editor.string = text }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject,NSTextViewDelegate {
        var parent:GrowingMessageEditor
        init(_ parent:GrowingMessageEditor) { self.parent = parent }
        func textDidChange(_ notification:Notification) { if let editor = notification.object as? NSTextView { parent.text = editor.string } }
    }
}
// Only live user scrolling changes follow mode. Layout and streaming updates do not.
struct ScrollIntentObserver: NSViewRepresentable {
    var onScroll:(Bool)->Void
    func makeNSView(context:Context) -> Marker { let view = Marker(); view.onScroll = onScroll; return view }
    func updateNSView(_ view:Marker,context:Context) { view.onScroll = onScroll }
    class Marker:NSView {
        var onScroll:((Bool)->Void)?
        var token:NSObjectProtocol?
        override func hitTest(_ point:NSPoint)->NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let token { NotificationCenter.default.removeObserver(token) }
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, let scroll = self.enclosingScrollView else { return }
                self.token = NotificationCenter.default.addObserver(forName:NSScrollView.didLiveScrollNotification,object:scroll,queue:.main) { [weak self,weak scroll] _ in
                    guard let scroll, let document = scroll.documentView else { return }
                    self?.onScroll?(document.bounds.height - scroll.contentView.bounds.maxY < 36)
                }
            }
        }
        deinit { if let token { NotificationCenter.default.removeObserver(token) } }
    }
}
