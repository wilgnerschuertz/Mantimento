import Foundation
import Network
import Security
import Darwin

struct LANResponse {
    let status: Int
    let body: Data
    var type = "application/json; charset=utf-8"
    var extra: [String:String] = [:]
    static func json(_ status:Int,_ object:[String:Any]) -> LANResponse {
        LANResponse(status:status,body:(try? JSONSerialization.data(withJSONObject:object)) ?? Data())
    }
    static func error(_ status:Int,_ message:String) -> LANResponse {
        json(status,["error":["message":message,"type":"mantimento_error"]])
    }
}
struct LANRequest {
    let method:String
    let path:String
    let headers:[String:String]
    let body:Data
}
enum LANProtocol {
    static let maxBody = 65536
    static func privateIPv4(_ value:String) -> Bool {
        let raw = value.split(separator:".",omittingEmptySubsequences:false)
        let parts = raw.compactMap { UInt8($0) }
        guard raw.count == 4, parts.count == 4, raw.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy({ (48...57).contains($0) }) }) else { return false }
        return parts[0] == 127 || parts[0] == 10 || (parts[0] == 192 && parts[1] == 168) ||
            (parts[0] == 172 && (16...31).contains(parts[1])) || (parts[0] == 169 && parts[1] == 254)
    }
    static func addresses() -> [String] {
        var first:UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0 else { return ["127.0.0.1"] }
        defer { freeifaddrs(first) }
        var result = Set(["127.0.0.1"]); var cursor = first
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            guard entry.pointee.ifa_flags & UInt32(IFF_UP) != 0,
                  let address = entry.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_INET) else { continue }
            var host = [CChar](repeating:0,count:Int(NI_MAXHOST))
            if getnameinfo(address,socklen_t(address.pointee.sa_len),&host,socklen_t(host.count),nil,0,NI_NUMERICHOST) == 0 {
                let ip = String(cString:host)
                if privateIPv4(ip) { result.insert(ip) }
            }
        }
        return result.sorted()
    }
    static func token() throws -> String {
        var bytes = [UInt8](repeating:0,count:32)
        guard SecRandomCopyBytes(kSecRandomDefault,bytes.count,&bytes) == errSecSuccess else {
            throw NSError(domain:"Mantimento",code:1,userInfo:[NSLocalizedDescriptionKey:"Não foi possível gerar a chave de acesso."])
        }
        return bytes.map { String(format:"%02x",$0) }.joined()
    }
    static func authorized(_ value:String?, token:String) -> Bool {
        let expected = Array(("Bearer " + token).utf8), received = Array((value ?? "").utf8)
        guard expected.count == received.count else { return false }
        return zip(expected,received).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }
    static func parseHead(_ data:Data) -> (String,String,[String:String],Int)? {
        guard data.count <= 8192, let text = String(data:data,encoding:.utf8) else { return nil }
        let lines = text.components(separatedBy:"\r\n")
        let first = (lines.first ?? "").split(separator:" ",omittingEmptySubsequences:false)
        guard first.count == 3, first[2] == "HTTP/1.1", ["GET","POST"].contains(String(first[0])) else { return nil }
        var headers:[String:String] = [:]
        for line in lines.dropFirst() where !line.isEmpty {
            guard let colon = line.firstIndex(of:":") else { return nil }
            let name = String(line[..<colon]).lowercased()
            let value = String(line[line.index(after:colon)...]).trimmingCharacters(in:.whitespaces)
            guard !name.isEmpty, name.utf8.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }),
                  value.utf8.allSatisfy({ $0 >= 32 || $0 == 9 }), headers[name] == nil else { return nil }
            headers[name] = value
        }
        guard headers["transfer-encoding"] == nil, headers["expect"] == nil else { return nil }
        let rawLength = headers["content-length"] ?? "0"
        guard !rawLength.isEmpty, rawLength.utf8.allSatisfy({ (48...57).contains($0) }),
              let length = Int(rawLength), length <= maxBody else { return nil }
        if first[0] == "POST" && headers["content-length"] == nil { return nil }
        if first[0] == "GET" && length != 0 { return nil }
        return (String(first[0]),String(first[1]),headers,length)
    }
    static func chatPayload(_ body:Data) throws -> Data {
        func invalid(_ message:String) -> NSError { NSError(domain:"Mantimento",code:400,userInfo:[NSLocalizedDescriptionKey:message]) }
        guard let object = try JSONSerialization.jsonObject(with:body) as? [String:Any],
              Set(object.keys).isSubset(of:["model","messages","max_tokens","temperature","stream"]),
              let messages = object["messages"] as? [[String:Any]], !messages.isEmpty, messages.count <= 100 else {
            throw invalid("Envie messages de texto. Ferramentas, arquivos e parâmetros adicionais não são aceitos.")
        }
        if let model = object["model"] {
            guard let name = model as? String, ["mantimento","default_model"].contains(name) else { throw invalid("Use o modelo mantimento.") }
        }
        if let stream = object["stream"] {
            guard let number = stream as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID(), !number.boolValue else {
                throw invalid("Esta versão aceita apenas stream: false.")
            }
        }
        var count = 0
        for message in messages {
            guard Set(message.keys) == Set(["role","content"]), let role = message["role"] as? String,
                  ["system","user","assistant"].contains(role), let content = message["content"] as? String else {
                throw invalid("Cada mensagem deve conter somente role e content de texto.")
            }
            count += content.utf8.count + 64
        }
        guard count <= 16000 else { throw invalid("Contexto acima do limite de 16 KB. Inicie outra conversa ou reduza o texto.") }
        let limit = object["max_tokens"] as? NSNumber ?? 1024
        let temperature = object["temperature"] as? NSNumber ?? 0.6
        guard CFGetTypeID(limit) != CFBooleanGetTypeID(), limit.doubleValue == Double(limit.intValue), (1...2048).contains(limit.intValue),
              CFGetTypeID(temperature) != CFBooleanGetTypeID(), (0...1).contains(temperature.doubleValue),
              object["max_tokens"] == nil || object["max_tokens"] is NSNumber,
              object["temperature"] == nil || object["temperature"] is NSNumber else { throw invalid("max_tokens deve ser inteiro de 1 a 2048; temperature deve estar entre 0 e 1.") }
        return try JSONSerialization.data(withJSONObject:["model":"default_model","messages":messages,"max_tokens":limit.intValue,"temperature":temperature.doubleValue,"stream":false,"chat_template_kwargs":["enable_thinking":false]])
    }
}

@MainActor final class LANServer {
    let port:UInt16
    let key:String
    let loopbackOnly:Bool
    var onState:((Bool,String)->Void)?
    var handler:((LANRequest) async -> LANResponse)?
    private var listener:NWListener?
    private var peers:[UUID:LANPeer] = [:]
    private var requests:[String:[Date]] = [:]
    private var stopped = false
    init(port:UInt16,key:String,loopbackOnly:Bool = false) { self.port = port; self.key = key; self.loopbackOnly = loopbackOnly }
    func start() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host:.ipv4(loopbackOnly ? .loopback : .any),port:NWEndpoint.Port(rawValue:port)!)
        let listener = try NWListener(using:parameters)
        self.listener = listener
        listener.stateUpdateHandler = { [weak self] state in Task { @MainActor in
            guard let self, !self.stopped else { return }
            switch state {
            case .ready: self.onState?(true,"Acesso pela rede ativo")
            case .waiting: self.onState?(false,"Rede indisponível. Verifique a permissão de rede local e tente ativar novamente."); self.stop()
            case .failed: self.onState?(false,"Não foi possível abrir a porta. Verifique se outro app a utiliza."); self.stop()
            default: break
            }
        }}
        listener.newConnectionHandler = { [weak self] connection in Task { @MainActor in
            guard let self, !self.stopped, self.peers.count < 32,
                  case .hostPort(let host,_) = connection.endpoint, LANProtocol.privateIPv4(String(describing:host)) else { connection.cancel(); return }
            let peer = LANPeer(connection:connection,server:self,ip:String(describing:host))
            self.peers[peer.id] = peer; peer.start()
        }}
        listener.start(queue:.main)
    }
    func stop() {
        stopped = true; listener?.cancel(); listener = nil
        for peer in Array(peers.values) { peer.close() }
        peers.removeAll()
    }
    func remove(_ id:UUID) { peers[id] = nil }
    func respond(_ request:LANRequest,ip:String) async -> LANResponse {
        let now = Date()
        requests = requests.filter { now.timeIntervalSince($0.value.last ?? .distantPast) < 60 }
        if requests[ip] == nil && requests.count >= 128 { return .error(429,"Muitas conexões. Tente depois.") }
        var recent = (requests[ip] ?? []).filter { now.timeIntervalSince($0) < 60 }
        guard recent.count < 60 else { return .error(429,"Limite de pedidos por minuto. Aguarde.") }
        recent.append(now); requests[ip] = recent
        let hosts = LANProtocol.addresses().map { "\($0):\(port)" } + ["localhost:\(port)"]
        guard let host = request.headers["host"], hosts.contains(host) else { return .error(403,"Use o endereço exibido no Mantimento.") }
        if let origin = request.headers["origin"], origin != "http://" + host { return .error(403,"Origem não permitida.") }
        if request.method == "GET" && ["/","/web.js"].contains(request.path) {
            let javascript = request.path == "/web.js"
            guard let url = Bundle.main.url(forResource:"web",withExtension:javascript ? "js" : "html"), let data = try? Data(contentsOf:url) else { return .error(500,"Interface web indisponível.") }
            return LANResponse(status:200,body:data,type:javascript ? "text/javascript; charset=utf-8" : "text/html; charset=utf-8")
        }
        guard LANProtocol.authorized(request.headers["authorization"],token:key) else { return .error(401,"Chave ausente ou inválida. Copie a chave nos Ajustes do Mac.") }
        guard let handler else { return .error(503,"Serviço indisponível.") }
        return await handler(request)
    }
}

@MainActor final class LANPeer {
    let id = UUID()
    let connection:NWConnection
    weak var server:LANServer?
    let ip:String
    private var buffer = Data()
    private var task:Task<Void,Never>?
    private var deadline:Task<Void,Never>?
    private var closed = false
    init(connection:NWConnection,server:LANServer,ip:String) { self.connection = connection; self.server = server; self.ip = ip }
    func start() {
        connection.stateUpdateHandler = { [weak self] state in Task { @MainActor in
            if case .failed = state { self?.close() }
            if case .cancelled = state { self?.close() }
        }}
        connection.start(queue:.main)
        deadline = Task { [weak self] in
            do { try await Task.sleep(nanoseconds:10_000_000_000) } catch { return }
            self?.close()
        }
        receive()
    }
    private func receive() {
        connection.receive(minimumIncompleteLength:1,maximumLength:8192) { [weak self] data,_,complete,error in Task { @MainActor in
            guard let self, !self.closed else { return }
            if let data { self.buffer.append(data) }
            guard error == nil, self.buffer.count <= LANProtocol.maxBody + 8192 else { self.close(); return }
            if let separator = self.buffer.range(of:Data("\r\n\r\n".utf8)) {
                guard let (method,path,headers,length) = LANProtocol.parseHead(self.buffer[..<separator.lowerBound]) else {
                    self.send(.error(400,"Pedido HTTP inválido ou grande demais.")); return
                }
                let body = self.buffer[separator.upperBound...]
                guard body.count <= length else { self.send(.error(400,"Um pedido por conexão.")); return }
                if body.count == length {
                    self.deadline?.cancel(); self.buffer = Data()
                    let request = LANRequest(method:method,path:path,headers:headers,body:Data(body))
                    self.task = Task { [weak self] in
                        guard let self, let server = self.server else { return }
                        let response = await server.respond(request,ip:self.ip)
                        guard !Task.isCancelled else { return }
                        self.send(response)
                    }
                    // Stop delivering to a disconnected browser. Store retains the inference lease until completion.
                    self.connection.receive(minimumIncompleteLength:1,maximumLength:1) { [weak self] _,_,_,_ in Task { @MainActor in self?.close() } }
                    return
                }
            } else if self.buffer.count > 8192 { self.send(.error(431,"Cabeçalhos grandes demais.")); return }
            if complete { self.close() } else { self.receive() }
        }}
    }
    private func send(_ response:LANResponse) {
        guard !closed else { return }
        deadline?.cancel()
        deadline = Task { [weak self] in
            do { try await Task.sleep(nanoseconds:15_000_000_000) } catch { return }
            self?.close()
        }
        let reason = [200:"OK",400:"Bad Request",401:"Unauthorized",403:"Forbidden",404:"Not Found",409:"Conflict",415:"Unsupported Media Type",429:"Too Many Requests",431:"Request Header Fields Too Large",500:"Internal Server Error",503:"Service Unavailable",504:"Gateway Timeout"][response.status] ?? "Error"
        var headers = "HTTP/1.1 \(response.status) \(reason)\r\nContent-Type: \(response.type)\r\nContent-Length: \(response.body.count)\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nX-Frame-Options: DENY\r\nReferrer-Policy: no-referrer\r\nContent-Security-Policy: default-src 'none'; script-src 'self'; style-src 'unsafe-inline'; connect-src 'self'; img-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'\r\n"
        for (key,value) in response.extra { headers += "\(key): \(value)\r\n" }
        var packet = Data((headers + "\r\n").utf8); packet.append(response.body)
        connection.send(content:packet,completion:.contentProcessed { [weak self] _ in Task { @MainActor in self?.close() } })
    }
    func close() {
        guard !closed else { return }
        closed = true; deadline?.cancel(); task?.cancel(); connection.cancel(); server?.remove(id)
    }
}
