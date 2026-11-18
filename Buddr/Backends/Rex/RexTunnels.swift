import Darwin
import Foundation

/// A server of a Rex SSH host that Rex.app forwards to a socket on this Mac.
struct RexTunnel: Equatable, Sendable {
    /// The local end, in `RexLocator.tunnelDirectory`.
    let socketPath: String
    /// The host's endpoint, such as `ssh://studio`.
    let endpoint: String

    /// The host name of the endpoint (`studio` for `ssh://me@studio:22`), for a host without a label.
    var hostName: String {
        URL(string: endpoint)?.host() ?? endpoint
    }
}

/// Finds the SSH tunnels Rex.app keeps open to the servers of its hosts while it runs.
///
/// Rex.app runs `rex __internal ssh-tunnel ssh://studio`, which runs
/// `ssh … -L <tunnel directory>/<hash>.sock:<remote socket> -- ssh://studio`. Nothing in Rex's API tells which socket
/// belongs to which host, so the `ssh` processes of the user are read (`sysctl`, no permission needed). This is how
/// Rex.app works today, not a documented interface.
enum RexTunnels {
    /// The tunnels whose local end is in `directory`, by endpoint. Cheap when there are none: the directory is
    /// looked at before any process.
    static func find(in directory: String) -> [RexTunnel] {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
        // `askpass-<pid>.sock` are ssh's password prompts, not servers.
        guard files.contains(where: { $0.hasSuffix(".sock") && !$0.hasPrefix("askpass-") }) else { return [] }
        let tunnels = ProcessTable.processes(ofUser: getuid())
            .filter { $0.name == "ssh" }
            .compactMap { ProcessTable.arguments(of: $0.id).flatMap { tunnel(fromSSHArguments: $0, in: directory) } }
            .filter { FileManager.default.fileExists(atPath: $0.socketPath) }
        return tunnels.uniqued().sorted { $0.endpoint < $1.endpoint }
    }

    /// The tunnel an `ssh` command line opens, if it forwards a socket in `directory` (`-L <local>:<remote>`); the
    /// endpoint is the last argument.
    static func tunnel(fromSSHArguments arguments: [String], in directory: String) -> RexTunnel? {
        let prefix = directory.hasSuffix("/") ? directory : directory + "/"
        var forward: String?
        for (index, argument) in arguments.enumerated() {
            if argument == "-L", index + 1 < arguments.count {
                forward = arguments[index + 1]
            } else if argument.hasPrefix("-L"), argument.count > 2 {
                forward = String(argument.dropFirst(2))
            }
        }
        guard let forward, forward.hasPrefix(prefix), let endpoint = arguments.last, endpoint != forward,
            let socketEnd = forward.range(of: ".sock:")
        else { return nil }
        return RexTunnel(socketPath: String(forward[..<socketEnd.lowerBound]) + ".sock", endpoint: endpoint)
    }
}

/// The processes of this Mac, read with `sysctl`.
enum ProcessTable {
    struct Process: Equatable, Sendable {
        let id: pid_t
        /// The short name (at most 16 characters).
        let name: String
    }

    static func processes(ofUser user: uid_t) -> [Process] {
        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_UID, Int32(bitPattern: user)]
        var size = 0
        guard sysctl(&name, 4, nil, &size, nil, 0) == 0 else { return [] }
        let stride = MemoryLayout<kinfo_proc>.stride
        // Room for processes started in between.
        var entries = [kinfo_proc](repeating: kinfo_proc(), count: size / stride + 16)
        size = entries.count * stride
        guard sysctl(&name, 4, &entries, &size, nil, 0) == 0 else { return [] }
        return entries.prefix(size / stride).map { entry in
            var command = entry.kp_proc.p_comm
            let name = withUnsafeBytes(of: &command) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
            return Process(id: entry.kp_proc.p_pid, name: name)
        }
    }

    /// The command line of a process of the user; `nil` when it is gone or not readable.
    static func arguments(of process: pid_t) -> [String]? {
        var name: [Int32] = [CTL_KERN, KERN_PROCARGS2, process]
        var size = 0
        guard sysctl(&name, 3, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&name, 3, &buffer, &size, nil, 0) == 0 else { return nil }
        return arguments(fromProcArgs: buffer.prefix(size))
    }

    /// The arguments in the answer of `KERN_PROCARGS2`: the argument count (32 bits), the executable path, padding,
    /// then the arguments, each ending with a zero byte (the environment follows).
    static func arguments(fromProcArgs bytes: some Collection<UInt8>) -> [String]? {
        let bytes = Array(bytes)
        guard bytes.count >= 4 else { return nil }
        let count = Int(bytes[0..<4].reversed().reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
        var index = 4
        // The executable path, then zero bytes up to the first argument.
        while index < bytes.count, bytes[index] != 0 { index += 1 }
        while index < bytes.count, bytes[index] == 0 { index += 1 }
        var arguments: [String] = []
        while arguments.count < count {
            guard index < bytes.count else { return nil }
            let end = bytes[index...].firstIndex(of: 0) ?? bytes.count
            arguments.append(String(decoding: bytes[index..<end], as: UTF8.self))
            index = end + 1
        }
        return arguments
    }
}
