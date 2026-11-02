import Foundation
import Testing

@testable import Buddr

struct CoreClientTests {
    @Test func listsTerminalsWithOneJSONRPCLine() async throws {
        let transport = try FakeCoreTransport.fixture("core-terminal-list")
        let list = try await CoreClient(transport: transport).terminals()

        #expect(list.terminals.map(\.address) == ["t3", "t8", "t10", "t12", "devbox/t5", "devbox/t7", "pi/t1"])
        #expect(list.machines?.map(\.name) == ["devbox", "pi"])
        #expect(transport.recordedLines == [#"{"jsonrpc":"2.0","id":1,"method":"terminal.list","params":{}}"# + "\n"])
    }

    @Test func machinesAreMissingWhenNoneWasAdded() async throws {
        let list = try await CoreClient(transport: try FakeCoreTransport.fixture("core-terminal-list-empty"))
            .terminals()

        #expect(list == CoreTerminalList(terminals: [], machines: nil))
    }

    @Test func errorAnswerBecomesAnAPIError() async throws {
        let client = CoreClient(transport: try FakeCoreTransport.fixture("core-error"))

        await #expect(
            throws: CoreError.api(
                method: "terminal.list", kind: "unknown_method", message: #"unknown method "nonexistent.method""#)
        ) {
            try await client.terminals()
        }
    }

    @Test func garbageIsInvalidOutput() {
        #expect {
            let _: CoreTerminalList = try CoreClient.parseResult(Data("not json".utf8), method: "terminal.list")
        } throws: { error in
            if case CoreError.invalidOutput(method: "terminal.list", _) = error { true } else { false }
        }
    }

    @Test func answerWithoutResultOrErrorIsInvalidOutput() {
        #expect(throws: CoreError.invalidOutput(method: "terminal.list", reason: "neither result nor error")) {
            let _: CoreTerminalList = try CoreClient.parseResult(
                Data(#"{"id":1,"jsonrpc":"2.0"}"#.utf8), method: "terminal.list")
        }
    }

    @Test func errorsDescribeThemselves() {
        #expect(
            CoreError.notRunning(socketPath: "/tmp/x.sock").description
                == "hc is not running (nothing listens on /tmp/x.sock)")
        #expect(CoreError.timedOut.description == "hc did not answer in time")
        #expect(CoreError.connectionFailed(reason: "Broken pipe").description == "hc: Broken pipe")
        #expect(
            CoreError.api(method: "terminal.list", kind: "busy", message: "try again").description
                == "terminal.list: try again (busy)")
        #expect(CoreError.api(method: "terminal.list", kind: nil, message: "no").description == "terminal.list: no")
        #expect(
            CoreError.invalidOutput(method: "terminal.list", reason: "eof").description
                == "terminal.list: unexpected output: eof")
    }
}

struct CoreLocatorTests {
    private func path(_ environment: [String: String]) -> String {
        CoreLocator(environment: environment, homeDirectory: "/Users/me").socketPath
    }

    @Test func defaultSessionLivesInTheStateDirectory() {
        #expect(path([:]) == "/Users/me/.local/state/herdr-core/default/default.sock")
    }

    @Test func followsHcsVariables() {
        #expect(path(["HC_SOCKET": "/tmp/core.sock", "HC_SESSION": "work"]) == "/tmp/core.sock")
        #expect(path(["HC_SESSION": "work"]) == "/Users/me/.local/state/herdr-core/work/work.sock")
        #expect(path(["XDG_STATE_HOME": "/state"]) == "/state/herdr-core/default/default.sock")
        #expect(
            path(["XDG_RUNTIME_DIR": "/run/user", "XDG_STATE_HOME": "/state", "HC_SESSION": "work"])
                == "/run/user/herdr-core/work.sock")
    }

    @Test func emptyVariablesAreIgnored() {
        #expect(
            path(["HC_SOCKET": "", "HC_SESSION": "", "XDG_RUNTIME_DIR": "", "XDG_STATE_HOME": ""])
                == "/Users/me/.local/state/herdr-core/default/default.sock")
    }
}
