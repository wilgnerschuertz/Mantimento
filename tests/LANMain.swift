import Foundation

@main struct LANTests {
    @MainActor static func main() async throws {
        let s = Store()
        // The test double owns no MLX process and only serves the local test port.
        s.running = true
        let key = try LANProtocol.token()
        let server = LANServer(port:18765,key:key,loopbackOnly:true)
        server.handler = { request in
            // Test desktop contention and lifecycle without exposing these controls in the app.
            if request.path == "/test/local-busy" { s.generating = true; return .json(200,["ok":true]) }
            if request.path == "/test/local-idle" { s.generating = false; return .json(200,["ok":true]) }
            if request.path == "/test/off" { s.running = false; return .json(200,["ok":true]) }
            if request.path == "/test/on" { s.running = true; return .json(200,["ok":true]) }
            if request.path == "/test/assert-local-blocked" {
                s.input = "Local must stay unsent"
                let before = s.messages
                s.send()
                return .json(200,["blocked":s.remoteGenerating && s.messages == before && s.input == "Local must stay unsent"])
            }
            return await s.handleWebRequest(request)
        }
        server.onState = { ready,message in
            if ready {
                let data = try! JSONSerialization.data(withJSONObject:["key":key,"ready":true])
                try! data.write(to:URL(fileURLWithPath:ProcessInfo.processInfo.environment["TEST_READY"]!),options:.atomic)
            } else { print(message) }
        }
        try server.start()
        try await Task.sleep(nanoseconds:1_800_000_000_000)
        server.stop()
    }
}
