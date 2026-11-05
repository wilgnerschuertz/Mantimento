import Foundation

extension Store {
    func startWebAccess(loopbackOnly:Bool = false) {
        guard webServer == nil else { return }
        do {
            let key = try LANProtocol.token()
            let server = LANServer(port:webPort,key:key,loopbackOnly:loopbackOnly)
            server.onState = { [weak self,weak server] ready,message in
                guard let self, self.webServer === server else { return }
                self.webEnabled = ready; self.webStarting = false; self.webStatus = message
                if !ready { self.webServer = nil; self.webKey = ""; self.webAddresses = [] }
                else { self.webAddresses = LANProtocol.addresses().filter { !$0.hasPrefix("127.") }.map { "http://\($0):\(self.webPort)" }
                    if self.webAddresses.isEmpty { self.webAddresses = ["http://127.0.0.1:\(self.webPort)"] }
                }
            }
            server.handler = { [weak self] request in
                guard let self else { return .error(503,"Aplicativo encerrando.") }
                return await self.handleWebRequest(request)
            }
            webKey = key; webServer = server; webStarting = true; webStatus = "Abrindo acesso pela rede…"
            try server.start()
        } catch { webServer?.stop(); webServer = nil; webKey = ""; webStarting = false; webStatus = error.localizedDescription }
    }
    func stopWebAccess() {
        webServer?.stop(); webServer = nil; webEnabled = false; webStarting = false; webKey = ""; webAddresses = []
        webStatus = "Acesso pela rede desligado"
        // No other inference can be active while the remote lease is held.
        if remoteGenerating { stop() }
    }
    func handleWebRequest(_ request:LANRequest) async -> LANResponse {
        if request.method == "GET" && request.path == "/api/status" {
            return .json(200,["ready":running,"busy":inferenceBusy,"model":"mantimento"])
        }
        if request.method == "GET" && request.path == "/v1/models" {
            return .json(200,["object":"list","data":running ? [["id":"mantimento","object":"model","owned_by":"local"]] : []])
        }
        guard request.method == "POST", request.path == "/v1/chat/completions" else { return .error(404,"Rota não disponível.") }
        guard request.headers["content-type"]?.split(separator:";").first?.trimmingCharacters(in:.whitespaces).lowercased() == "application/json" else { return .error(415,"Use Content-Type: application/json.") }
        let payload:Data
        do { payload = try LANProtocol.chatPayload(request.body) }
        catch { return .error(400,error.localizedDescription) }
        guard running else { return .error(503,"Inicie o modelo no Mantimento deste Mac.") }
        guard !inferenceBusy else { return .error(409,"O modelo está ocupado. Aguarde a resposta atual.") }
        remoteGenerating = true
        let task = Task { @MainActor [weak self] () -> LANResponse in
            guard let self else { return .error(503,"Aplicativo encerrando.") }
            defer { self.remoteGenerating = false; self.webRequest = nil }
            do {
                var upstream = URLRequest(url:self.base.appendingPathComponent("v1/chat/completions"))
                upstream.httpMethod = "POST"; upstream.timeoutInterval = 600; upstream.httpBody = payload
                upstream.setValue("application/json",forHTTPHeaderField:"Content-Type")
                let (data,response) = try await URLSession.shared.data(for:upstream)
                try Task.checkCancellation()
                guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 2_000_000,
                      var object = try JSONSerialization.jsonObject(with:data) as? [String:Any],
                      let choices = object["choices"] as? [[String:Any]],
                      let message = choices.first?["message"] as? [String:Any], let text = message["content"] as? String else {
                    return .error(503,"O servidor local não concluiu a resposta. Consulte o Mac.")
                }
                object = ["id":"chatcmpl-" + UUID().uuidString,"object":"chat.completion","model":"mantimento", "created":Int(Date().timeIntervalSince1970),
                          "choices":[["index":0,"message":["role":"assistant","content":text],"finish_reason":choices.first?["finish_reason"] as? String ?? "stop"]],
                          "usage":object["usage"] as? [String:Any] ?? [:]]
                return .json(200,object)
            } catch {
                return .error(Task.isCancelled ? 503 : 504,Task.isCancelled ? "Pedido interrompido no Mac." : "Não foi possível obter a resposta do modelo.")
            }
        }
        webRequest = task
        // A browser can stop waiting, but retain the lease until the engine completes.
        // This avoids queuing more inference jobs after a client disconnects.
        return await task.value
    }
}
