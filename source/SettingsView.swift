import SwiftUI
struct SettingsView: View {
    @ObservedObject var store: Store
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack { Text("Modelos e ajustes").font(.title2.bold()); Spacer(); Button("Concluído") { store.showSettings = false }.keyboardShortcut(.cancelAction) }
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
                    Text("Downloads individuais. Um modelo carregado por vez. O agente foi validado com o 9B; outros modelos podem variar.").font(.caption).foregroundStyle(.secondary)
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
                }

        }.padding(24).frame(width:760,height:650)
    }
}
