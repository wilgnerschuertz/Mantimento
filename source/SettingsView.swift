import SwiftUI

struct PageIntro: View {
    let title:String
    let subtitle:String
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            Text(title).font(.largeTitle.weight(.semibold))
            Text(subtitle).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
}
struct Surface<Content:View>: View {
    @ViewBuilder var content:Content
    var body:some View { VStack(alignment:.leading,spacing:14) { content }.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(Color(nsColor:.controlBackgroundColor),in:RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).stroke(Color.secondary.opacity(0.12))) }
}
struct ModelsView: View {
    @ObservedObject var store:Store
    var filtered:[DownloadModel] {
        DownloadModel.catalog.filter { (store.catalogFamily == "Todos" || $0.family == store.catalogFamily) && (store.catalogQuery.isEmpty || ($0.title + " " + $0.detail).localizedCaseInsensitiveContains(store.catalogQuery)) }
    }
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:22) {
                PageIntro(title:"Sua biblioteca de IA",subtitle:"Escolha um modelo para baixar e usar no seu Mac. Um modelo fica carregado por vez.")
                SetupGuide(store:store,openModels:nil)
                ViewThatFits(in:.horizontal) {
                    HStack(spacing:12) { search; family }
                    VStack(alignment:.leading,spacing:10) { search; family }
                }
                if store.operation == "download" {
                    Surface {
                        Label("Baixando \(store.displayModel)",systemImage:"arrow.down.circle").font(.headline)
                        if store.downloadTotal > 0 {
                            ProgressView(value:min(store.downloadReceived,store.downloadTotal),total:store.downloadTotal)
                            Text("\(bytes(store.downloadReceived)) de \(bytes(store.downloadTotal)) no cache. Verificação final ao concluir.").font(.caption).foregroundStyle(.secondary)
                        } else { ProgressView("Consultando o tamanho…") }
                        Button("Interromper download") { store.stop() }
                        Text("Você pode tentar novamente depois; os arquivos recebidos ficam no cache.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                LazyVGrid(columns:[GridItem(.adaptive(minimum:280),spacing:16)],alignment:.leading,spacing:16) {
                    ForEach(filtered) { entry in ModelCard(store:store,entry:entry) }
                }
                if filtered.isEmpty { ContentUnavailableView.search(text:store.catalogQuery) }
                Text("Tamanhos aproximados. O espaço é verificado antes do download. A memória necessária varia com o tamanho da conversa; modelos experimentais ainda precisam de avaliação no Mantimento.").font(.caption).foregroundStyle(.secondary)
                Surface {
                    DisclosureGroup("Adicionar outro modelo MLX") {
                        VStack(alignment:.leading,spacing:12) {
                            TextField("organização/modelo do Hugging Face",text:$store.newModel).textFieldStyle(.roundedBorder)
                            ViewThatFits(in:.horizontal) {
                                HStack { addButton; folderButton; catalogLink }
                                VStack(alignment:.leading) { addButton; folderButton; catalogLink }
                            }
                            Picker("Selecionado",selection:$store.modelID) { ForEach(store.models,id:\.self) { Text($0).tag($0) } }
                            HStack {
                                Button("Baixar selecionado") { store.run("download") }
                                if store.availableModels.contains(store.modelID) && !store.modelID.hasPrefix("/") {
                                    Button("Remover…") { store.removeModel(store.modelID) }
                                }
                            }
                            Text("Use modelos de texto compatíveis com MLX-LM. GGUF e modelos de visão exigem outros motores.").font(.caption).foregroundStyle(.secondary)
                        }.padding(.top,12).disabled(store.process != nil || store.generating)
                    }
                }
            }.padding(24).frame(maxWidth:980).frame(maxWidth:.infinity)
        }
    }
    var search:some View { TextField("Buscar modelos ou finalidade",text:$store.catalogQuery).textFieldStyle(.roundedBorder).frame(minWidth:180) }
    var family:some View { Picker("Família",selection:$store.catalogFamily) { ForEach(["Todos","Qwen","Llama","Phi"],id:\.self) { Text($0) } }.frame(width:180) }
    var addButton:some View { Button("Adicionar") { store.addModel() }.disabled(store.newModel.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty) }
    var folderButton:some View { Button("Escolher pasta…") { store.chooseFolder() } }
    var catalogLink:some View { Link("Explorar catálogo ↗",destination:URL(string:"https://huggingface.co/mlx-community")!) }
    func bytes(_ value:Double)->String { ByteCountFormatter.string(fromByteCount:Int64(value),countStyle:.file) }
}
struct ModelCard:View {
    @ObservedObject var store:Store
    let entry:DownloadModel
    var installed:Bool { store.availableModels.contains(entry.id) }
    var selected:Bool { store.modelID == entry.id }
    var body:some View {
        Surface {
            HStack(alignment:.top) {
                VStack(alignment:.leading,spacing:5) {
                    Text(entry.family.uppercased()).font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
                    Text(entry.title).font(.title3.weight(.semibold)).fixedSize(horizontal:false,vertical:true)
                }
                Spacer(minLength:4)
                Menu {
                    Link("Detalhes e licença ↗",destination:URL(string:"https://huggingface.co/" + entry.id)!)
                    if installed { Button("Mover para a Lixeira…") { store.removeModel(entry.id) }.disabled(store.process != nil || store.generating) }
                } label: { Image(systemName:"ellipsis") }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Opções de \(entry.title)")
            }
            Text(entry.detail).font(.callout).foregroundStyle(.secondary).frame(minHeight:38,alignment:.topLeading).fixedSize(horizontal:false,vertical:true)
            HStack {
                Label(String(format:"%.1f GB",entry.sizeGB),systemImage:"arrow.down")
                Spacer(minLength:4)
                Label(entry.memory,systemImage:"memorychip")
            }.font(.caption).foregroundStyle(.secondary)
            Text(entry.validation).font(.caption).padding(.horizontal,8).padding(.vertical,4).background(Color.secondary.opacity(0.08),in:Capsule())
            Divider()
            HStack {
                Label(installed ? "No seu Mac" : "Disponível",systemImage:installed ? "checkmark.circle.fill" : "arrow.down.circle").font(.caption).foregroundStyle(installed ? Color.green : Color.secondary)
                Spacer(minLength:4)
                if installed {
                    Button(selected ? "Selecionado" : "Usar") { store.modelID = entry.id }.disabled(selected || store.process != nil || store.generating)
                } else {
                    Button("Baixar") { store.download(entry.id) }.buttonStyle(.borderedProminent).disabled(!store.environmentReady || store.process != nil || store.generating)
                }
            }
        }.overlay(RoundedRectangle(cornerRadius:14).stroke(selected ? Color.accentColor.opacity(0.7) : .clear,lineWidth:1.5))
    }
}
struct SetupGuide:View {
    @ObservedObject var store:Store
    let openModels:(()->Void)?
    var downloaded:Bool { store.availableModels.contains(store.modelID) }
    var body:some View {
        if !store.environmentReady || !downloaded {
            Surface {
                Text("Vamos preparar seu Mac").font(.headline)
                Text("Internet é necessária nesta etapa. Depois do preparo e download, as conversas podem funcionar offline.").font(.callout).foregroundStyle(.secondary)
                step(1,"Preparar ambiente",complete:store.environmentReady)
                if !store.environmentReady {
                    Button("Preparar ambiente") { store.run("setup") }.buttonStyle(.borderedProminent).disabled(store.process != nil)
                }
                step(2,"Escolher e baixar um modelo",complete:downloaded)
                if let openModels { Button("Escolher modelo") { openModels() } }
                step(3,"Iniciar e conversar",complete:store.running)
            }
        }
    }
    func step(_ number:Int,_ title:String,complete:Bool)->some View {
        Label(complete ? "\(title) · concluído" : "\(number). \(title)",systemImage:complete ? "checkmark.circle.fill" : "circle").font(.callout).foregroundStyle(complete ? Color.green : Color.primary)
    }
}
struct BackupView:View {
    @ObservedObject var store:Store
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:22) {
                PageIntro(title:"Guarde uma cópia offline",subtitle:"Leve o aplicativo, o ambiente e os modelos já baixados para outro Mac Apple Silicon.")
                Surface {
                    Label("1. Preparar os pacotes",systemImage:"shippingbox").font(.headline)
                    Text("Esta etapa usa internet para reunir as dependências. É necessária antes de exportar o primeiro kit.").foregroundStyle(.secondary)
                    Button("Preparar pacotes") { store.run("packages") }.disabled(store.process != nil)
                }
                Surface {
                    Label("2. Escolher o conteúdo",systemImage:"checklist").font(.headline)
                    Label("Aplicativo, Python e dependências",systemImage:"checkmark")
                    Label("Modelos já baixados",systemImage:"checkmark")
                    Toggle("Incluir conversas e pastas internas",isOn:$store.includePersonalBackup).disabled(store.process != nil)
                    Text("Documentos de pastas externas não são incluídos. O kit não é criptografado; confira o conteúdo antes de compartilhar.").font(.caption).foregroundStyle(.secondary)
                }
                Surface {
                    Label("3. Exportar o kit",systemImage:"externaldrive.badge.plus").font(.headline)
                    Text("Escolha uma pasta com espaço livre. O kit pode ocupar vários GB e inclui instruções de restauração sem conexão.").foregroundStyle(.secondary)
                    Button("Escolher destino e exportar…") { store.exportKit() }.buttonStyle(.borderedProminent).disabled(store.process != nil)
                }
                if store.process != nil { Text("Desligue o modelo ou aguarde a tarefa atual para preparar e exportar.").font(.caption).foregroundStyle(.secondary) }
            }.padding(24).frame(maxWidth:780).frame(maxWidth:.infinity)
        }
    }
}
struct SettingsView:View {
    @ObservedObject var store:Store
    @AppStorage("appearance") private var appearance = "Sistema"
    var body:some View {
        VStack(spacing:0) {
            HStack { Text("Ajustes").font(.title2.weight(.semibold)); Spacer(); Button("Concluído") { store.showSettings = false }.keyboardShortcut(.cancelAction) }.padding(20)
            Divider()
            Form {
                Section("Aparência") {
                    Picker("Tema",selection:$appearance) { ForEach(["Sistema","Claro","Escuro"],id:\.self) { Text($0) } }
                }
                Section("Respostas") {
                    Picker("Tamanho máximo",selection:$store.maxTokens) { Text("Curta · 1024 tokens").tag(1024); Text("Padrão · 2048 tokens").tag(2048); Text("Longa · 4096 tokens").tag(4096) }
                    LabeledContent("Criatividade") { HStack { Slider(value:$store.temperature,in:0...1); Text(store.temperature,format:.number.precision(.fractionLength(1))).monospacedDigit().frame(width:28) }.frame(maxWidth:220) }
                }
                Section("Memória") {
                    Picker("Desligar modelo sem uso",selection:$store.idleUnloadMinutes) {
                        Text("Nunca").tag(0)
                        Text("Após 5 minutos").tag(5)
                        Text("Após 10 minutos").tag(10)
                        Text("Após 30 minutos").tag(30)
                    }
                    Text("Encerra o servidor para liberar a memória do modelo. Respostas e ações em andamento não são interrompidas. Para voltar, clique em Iniciar modelo; a primeira resposta precisará carregar os pesos novamente.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Diagnóstico") {
                    Button("Ver registros") { store.logsAfterSettings = true; store.showSettings = false }
                    Text("Os registros podem conter caminhos e conteúdo de arquivos. Revise antes de compartilhar.").font(.caption).foregroundStyle(.secondary)
                    Text("API: http://127.0.0.1:12345/v1").font(.caption).textSelection(.enabled)
                    Button("Reparar ambiente") { store.run("setup") }.disabled(store.process != nil)
                    Link("Relatar problema ou sugestão ↗",destination:URL(string:"https://github.com/wilgnerschuertz/Mantimento/issues/new/choose")!)
                }
            }.formStyle(.grouped)
        }.frame(minWidth:480,idealWidth:540,maxWidth:640,minHeight:440,idealHeight:520,maxHeight:620)
    }
}
struct OperationStatusView:View {
    @ObservedObject var store:Store
    var title:String {
        if store.summarizing { return "Resumindo conversa" }
        if store.generating { return "Respondendo" }
        if store.replyFailed { return "Não foi possível responder" }
        if store.lastActionFailed { return "Não foi possível concluir" }
        switch store.operation {
        case "setup": return "Preparando ambiente"
        case "download": return "Baixando modelo"
        case "packages": return "Preparando pacotes"
        case "kit": return "Exportando kit"
        case "remove": return "Removendo modelo"
        case "start": return store.running ? "Pronto no seu Mac" : "Iniciando modelo"
        default: return "Modelo desligado"
        }
    }
    var body:some View {
        VStack(spacing:0) {
            Divider()
            HStack(spacing:10) {
                if store.working || store.generating { ProgressView().controlSize(.small) }
                else { Image(systemName:store.lastActionFailed ? "exclamationmark.circle" : store.running ? "checkmark.circle" : "circle").foregroundStyle(store.lastActionFailed ? Color.orange : Color.secondary) }
                VStack(alignment:.leading,spacing:3) {
                    Text(title).font(.caption.weight(.semibold))
                    Text(store.status).font(.caption).foregroundStyle(.secondary).lineLimit(2).help(store.status)
                }.frame(maxWidth:.infinity,alignment:.leading)
                if store.lastActionFailed {
                    Button("Tentar novamente") { store.retryLastAction() }.disabled(store.process != nil)
                }
                Button { store.showLogs.toggle() } label: { Image(systemName:"terminal") }.help("Mostrar ou ocultar registros").accessibilityLabel("Registros")
            }.padding(.horizontal,16).padding(.vertical,10)

        }.sheet(isPresented:$store.showLogs) {
            VStack(alignment:.leading,spacing:12) {
                HStack { Text("Registros").font(.title2.weight(.semibold)); Spacer(); Button("Concluído") { store.showLogs = false }.keyboardShortcut(.cancelAction) }
                Text("Revise caminhos e conteúdo antes de compartilhar.").font(.caption).foregroundStyle(.secondary)
                ScrollView([.horizontal,.vertical]) { Text(store.logs.isEmpty ? "Sem registros." : store.logs).font(.system(.caption,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading).padding(12) }.background(Color(nsColor:.textBackgroundColor),in:RoundedRectangle(cornerRadius:10))
            }.padding(20).frame(minWidth:480,idealWidth:640,maxWidth:800,minHeight:340,idealHeight:440,maxHeight:560)
        }
    }
}
