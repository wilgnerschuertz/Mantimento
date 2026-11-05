import SwiftUI
import AppKit

struct WorkspaceBar: View {
    @ObservedObject var store: Store
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            ViewThatFits(in:.horizontal) {
                HStack(spacing:12) { folder; Spacer(minLength:8); modes; permissions }
                VStack(alignment:.leading,spacing:10) { HStack { folder; Spacer(minLength:0) }; HStack { modes; permissions; Spacer(minLength:0) } }
            }
            if store.agentEnabled {
                Label(store.fullControl ? "Arquivos e terminal sem aprovação, com as permissões do seu usuário. Não inclui controle visual de aplicativos." : "Leitura local automática. Revise arquivos e comandos antes de executar.",systemImage:store.fullControl ? "bolt.shield" : "checkmark.shield").font(.caption).foregroundStyle(store.fullControl ? Color.orange : Color.secondary)
            }
        }.padding(.horizontal,24).padding(.vertical,10).background(Color.secondary.opacity(0.035))
    }
    var folder:some View {
        Menu {
            Button("Mudar pasta…") { store.changeWorkspace() }
            Button("Abrir no Finder") { NSWorkspace.shared.open(URL(fileURLWithPath:store.workspace)) }
            Button("Copiar caminho") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(store.workspace,forType:.string) }
        } label: {
            Label(store.workspace.hasPrefix(store.dataDir.appendingPathComponent("Workspaces").path + "/") ? "Pasta desta conversa" : URL(fileURLWithPath:store.workspace).lastPathComponent,systemImage:"folder").font(.caption).lineLimit(1).truncationMode(.middle)
        }.menuStyle(.borderlessButton).frame(idealWidth:200,maxWidth:230,alignment:.leading).help(store.workspace).disabled(store.inferenceBusy)
    }
    var modes:some View { Picker("Modo",selection:$store.agentEnabled) { Text("Conversa").tag(false); Text("Agente").tag(true) }.pickerStyle(.segmented).labelsHidden().frame(width:170).disabled(store.inferenceBusy) }
    @ViewBuilder var permissions:some View {
        if store.agentEnabled { Picker("Permissões",selection:$store.fullControl) { Text("Revisar ações").tag(false); Text("Controle total").tag(true) }.labelsHidden().frame(width:165).disabled(store.inferenceBusy) }
    }

}
struct ReviewView: View {
    @ObservedObject var store: Store
    let proposal: ToolProposal
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            Text(proposal.title).font(.title2.bold())
            GeometryReader { geometry in
                if geometry.size.width >= 760 {
                    HStack(alignment:.top,spacing:16) { panel("Antes / contexto",proposal.before); panel("Proposta",proposal.after) }
                } else {
                    VStack(alignment:.leading,spacing:16) { panel("Antes / contexto",proposal.before); panel("Proposta",proposal.after) }
                }
            }
            HStack {
                Text("Revise o conteúdo antes de autorizar.").foregroundStyle(.secondary)
                Spacer()
                Button("Recusar") { store.approve(false) }.keyboardShortcut(.cancelAction)
                Button("Aprovar e executar") { store.approve(true) }.buttonStyle(.borderedProminent)
            }
        }.padding(24).frame(minWidth:600,idealWidth:840,maxWidth:960,minHeight:480,idealHeight:560,maxHeight:700)
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
