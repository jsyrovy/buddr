import Darwin
import Foundation
import Testing

@testable import Buddr

struct RexTunnelsTests {
    private static let directory = "/Users/me/Library/Application Support/rex/ssh"

    /// The command line Rex.app 0.1.0 (2042) runs for a host.
    private static let sshArguments = [
        "/usr/bin/ssh", "-N", "-T", "-o", "ExitOnForwardFailure=yes", "-o", "StreamLocalBindUnlink=yes", "-o",
        "StreamLocalBindMask=0177", "-o", "ServerAliveInterval=15", "-o", "ServerAliveCountMax=3", "-o",
        "ControlMaster=no", "-o", "ControlPath=none", "-o", "ConnectTimeout=10", "-L",
        "\(directory)/6435e9b0b8868469.sock:/run/user/1000/rex/server.sock", "--", "ssh://devbox",
    ]

    @Test func tunnelOfRexApp() {
        #expect(
            RexTunnels.tunnel(fromSSHArguments: Self.sshArguments, in: Self.directory)
                == RexTunnel(socketPath: "\(Self.directory)/6435e9b0b8868469.sock", endpoint: "ssh://devbox"))
        // The forward can be glued to the option, and the directory given with a slash.
        #expect(
            RexTunnels.tunnel(
                fromSSHArguments: ["ssh", "-L\(Self.directory)/a.sock:/tmp/rex.sock", "ssh://me@devbox:22"],
                in: Self.directory + "/")
                == RexTunnel(socketPath: "\(Self.directory)/a.sock", endpoint: "ssh://me@devbox:22"))
    }

    @Test func otherSSHCommandsAreNoTunnels() {
        for arguments in [
            ["ssh", "devbox"],
            ["ssh", "-L", "8080:localhost:80", "devbox"],
            ["ssh", "-L", "/tmp/other/a.sock:/run/rex.sock", "devbox"],
            // No endpoint after the forward.
            ["ssh", "-L", "\(Self.directory)/a.sock:/run/rex.sock"],
            // Not a socket.
            ["ssh", "-L", "\(Self.directory)/a:/run/rex.sock", "devbox"],
            ["ssh", "-L"],
        ] {
            #expect(RexTunnels.tunnel(fromSSHArguments: arguments, in: Self.directory) == nil)
        }
    }

    @Test func hostNames() {
        #expect(RexTunnel(socketPath: "", endpoint: "ssh://devbox").hostName == "devbox")
        #expect(RexTunnel(socketPath: "", endpoint: "ssh://me@devbox.local:2222").hostName == "devbox.local")
        #expect(RexTunnel(socketPath: "", endpoint: "devbox").hostName == "devbox")
    }

    @Test func noProcessesAreReadWithoutSocketsInTheDirectory() throws {
        let directory = NSTemporaryDirectory() + "buddr-test-\(UUID().uuidString.prefix(8))"
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: directory) }
        FileManager.default.createFile(atPath: directory + "/askpass-1.sock", contents: nil)
        FileManager.default.createFile(atPath: directory + "/1.lock", contents: nil)

        #expect(RexTunnels.find(in: directory).isEmpty)
        #expect(RexTunnels.find(in: directory + "/missing").isEmpty)
    }

    @Test func procArgsHoldTheArgumentsAfterTheExecutablePath() {
        var bytes: [UInt8] = [3, 0, 0, 0] + Array("/usr/bin/ssh".utf8) + [0, 0, 0, 0]
        for argument in ["ssh", "", "-N"] {
            bytes += Array(argument.utf8) + [0]
        }
        bytes += Array("HOME=/Users/me".utf8) + [0]

        #expect(ProcessTable.arguments(fromProcArgs: bytes) == ["ssh", "", "-N"])
        #expect(ProcessTable.arguments(fromProcArgs: bytes.prefix(20)) == nil)
        #expect(ProcessTable.arguments(fromProcArgs: [1, 0]) == nil)
    }

    @Test func processTableHasThisProcess() throws {
        let me = try #require(ProcessTable.processes(ofUser: getuid()).first { $0.id == getpid() })
        #expect(!me.name.isEmpty)
        let arguments = try #require(ProcessTable.arguments(of: getpid()))
        #expect(arguments.first == CommandLine.arguments.first)
        #expect(ProcessTable.arguments(of: -1) == nil)
    }
}
