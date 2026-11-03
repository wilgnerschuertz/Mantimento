import SwiftUI
import AppKit

struct WorkspaceBar: View {
    @ObservedObject var store: Store
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {
                Image(systemName:"folder")
                Text(store.workspace).font(.caption).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                Button("Mudar pasta…") { store.changeWorkspace() }.disabled(store.generating)
                Button { NSWorkspace.shared.open(URL(fileURLWithPath:store.workspace)) } label:{ Image(systemName:"arrow.up.forward.square") }.help("Abrir pasta no Finder")
                Spacer()
            }
            HStack {
                Toggle("Agente de arquivos e terminal",isOn:$store.agentEnabled).toggleStyle(.switch).disabled(store.generating)
                Spacer()
                Picker("Permissões",selection:$store.fullControl) {
                    Text("Revisar alterações e comandos").tag(false)
                    Text("Controle total").tag(true)
                }.frame(maxWidth:370).disabled(store.generating || !store.agentEnabled)
            }
            if store.agentEnabled {
                Text(store.fullControl ? "Controle total: arquivos e terminal sem aprovação; comandos têm acesso permitido ao seu usuário no Mac. Não inclui controle visual de aplicativos." : "Leituras na pasta são automáticas. Escritas e comandos exigem revisão. Texto UTF-8 e PDFs textuais; sem OCR.").font(.caption).foregroundStyle(store.fullControl ? Color.orange : Color.secondary)
            }
            if store.generating {
                Button("Interromper agente / geração") { store.stop() }
            }
        }.padding(.horizontal,20).padding(.vertical,10).background(Color.secondary.opacity(0.04))
    }
}
struct ReviewView: View {
    @ObservedObject var store: Store
    let proposal: ToolProposal
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            Text(proposal.title).font(.title2.bold())
            HStack(alignment:.top,spacing:16) {
                panel("Antes / contexto",proposal.before)
                panel("Proposta",proposal.after)
            }
            HStack {
                Text("Revise o conteúdo antes de autorizar.").foregroundStyle(.secondary)
                Spacer()
                Button("Recusar") { store.approve(false) }.keyboardShortcut(.cancelAction)
                Button("Aprovar e executar") { store.approve(true) }.buttonStyle(.borderedProminent)
            }
        }.padding(24).frame(width:900,height:560)
    }
    func panel(_ title:String,_ content:String) -> some View {
        VStack(alignment:.leading) {
            Text(title).font(.headline)
            ScrollView([.horizontal,.vertical]) {
                Text(content).font(.system(.callout,design:.monospaced)).textSelection(.enabled).padding(12).frame(maxWidth:.infinity,alignment:.leading)
            }.frame(maxWidth:.infinity,maxHeight:.infinity).background(Color.secondary.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius:8))
        }.frame(maxWidth:.infinity)
    }
}
