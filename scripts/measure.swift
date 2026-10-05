#!/usr/bin/xcrun swift
import Darwin
import Foundation
import IOKit.ps

// Measures what the running Buddr costs: CPU time (its own and that of the herdr processes it runs), wakeups, power
// and memory, sampled from the kernel's per-process counters (`proc_pid_rusage`, no root needed). Every run is saved
// as JSON in build/measurements; `show` prints a saved run, `compare` two of them. See `scripts/measure.swift --help`.
// (The comment follows the imports: swift-format joins a comment right after the shebang onto its line.)

let usage = """
    Usage:
      scripts/measure.swift [options]                       measure the running Buddr until Ctrl-C or --duration
      scripts/measure.swift show <file> [--json] [--samples]
      scripts/measure.swift compare <a> <b> [--json]

    Options:
      --duration <d>   stop after d (90s, 5m, 1h; a plain number is seconds); required with --json
      --interval <d>   sample every d (default 5s)
      --label <name>   name of the scenario, part of the file name
      --pid <pid>      the Buddr process to measure when several run
      --json           print JSON instead of text (for agents); messages go to stderr
      --samples        include the samples in the printed JSON (the saved file always has them)
      --profile        also record a Time Profiler trace next to the results (adds some overhead)

    CPU is in percent of one core, like in Activity Monitor. Runs are saved in build/measurements.
    """

// MARK: - Results

/// One measurement run, as saved in build/measurements (keys in snake_case, units in the key names).
struct Measurement: Codable {
    var schema: Int
    var label: String?
    var startedAt: String
    var durationS: Double
    var intervalS: Double
    var endReason: EndReason
    var tracePath: String?
    var app: AppInfo
    var repo: RepoInfo?
    var system: SystemInfo
    var settings: Settings
    var summary: Summary
    var warnings: [String]
    var samples: [Sample]?
}

enum EndReason: String, Codable {
    case duration, interrupted
    case appExited = "app_exited"
}

struct AppInfo: Codable {
    var pid: Int32
    var path: String
    var configuration: Configuration
    var builtAt: String
    /// How long the app had been running when the measurement started.
    var uptimeS: Double
}

enum Configuration: String, Codable {
    case release, debug

    var name: String { rawValue.capitalized }
}

/// The state of the repo the script is in, which isn't necessarily what the measured app was built from.
struct RepoInfo: Codable {
    var commit: String
    var dirty: Bool
    var lastCommitAt: String

    var text: String { "repo \(commit)\(dirty ? " (dirty)" : "")" }
}

struct SystemInfo: Codable {
    var macos: String
    var model: String
    var powerSource: PowerSource
}

enum PowerSource: String, Codable {
    case ac, battery, ups, unknown

    var text: String {
        switch self {
        case .ac: "AC power"
        case .battery: "battery"
        case .ups: "UPS"
        case .unknown: "unknown power source"
        }
    }
}

/// Buddr's menu bar settings as the app uses them: keys, choices and defaults mirror `Preferences`.
struct Settings: Codable, Equatable {
    var animationMode: String
    var animationSeconds: Int
    var hideMode: String
    var hideMinutes: Int
    var watchesRemoteMachines: Bool

    static func read() -> Settings {
        let defaults = UserDefaults(suiteName: "cz.jsyrovy.buddr")
        func choice<Value: Equatable>(_ key: String, _ choices: [Value], default value: Value) -> Value {
            (defaults?.object(forKey: key) as? Value).flatMap { choices.contains($0) ? $0 : nil } ?? value
        }
        return Settings(
            animationMode: choice("animationMode", ["off", "onChange", "always"], default: "always"),
            animationSeconds: choice("animationDurationSeconds", [5, 10, 30, 60], default: 10),
            hideMode: choice("hideMode", ["never", "whenIdle", "unlessNeeded"], default: "never"),
            hideMinutes: choice("hideAfterMinutes", [1, 5, 15, 30], default: 5),
            watchesRemoteMachines: choice("watchesRemoteMachines", [false, true], default: true))
    }

    /// Names as in the JSON.
    var fields: [(name: String, value: String)] {
        Mirror(reflecting: self).children.map { (snakeCase($0.label!), "\($0.value)") }
    }

    var text: String {
        let animation =
            switch animationMode {
            case "onChange": "on change (\(animationSeconds) s)"
            default: animationMode
            }
        let hide =
            switch hideMode {
            case "whenIdle": "when idle (after \(hideMinutes) min)"
            case "unlessNeeded": "unless needed (after \(hideMinutes) min)"
            default: hideMode
            }
        return "animation \(animation) · hide \(hide) · remote machines \(watchesRemoteMachines ? "on" : "off")"
    }
}

/// `avg` is the rate over the whole run, `p95` and `max` are over the samples.
struct Stat: Codable {
    var avg: Double
    var p95: Double
    var max: Double
}

extension Stat {
    init(avg: Double, over values: [Double]) {
        let sorted = values.sorted()
        let p95 = sorted[Swift.max(0, Int((Double(sorted.count) * 0.95).rounded(.up)) - 1)]
        self.init(avg: avg, p95: p95, max: sorted[sorted.count - 1])
    }
}

/// In MB of 1024² bytes, like in Activity Monitor.
struct Footprint: Codable {
    var start: Double
    var end: Double
    var max: Double
    /// The app's peak since it started.
    var lifetimeMax: Double
}

struct Summary: Codable {
    var cpuPercent: Stat
    /// herdr processes run by the app, counted once they have exited.
    var childrenCpuPercent: Stat
    var wakeupsPerS: Stat
    /// Wakeups that brought the CPU out of idle (Activity Monitor's "Idle Wake Ups").
    var idleWakeupsPerS: Stat
    var powerMw: Stat
    var footprintMb: Footprint
}

/// Rates over one sampling interval that ended `tS` seconds after the start.
struct Sample: Codable {
    var tS: Double
    var cpuPercent: Double
    var childrenCpuPercent: Double
    var wakeupsPerS: Double
    var idleWakeupsPerS: Double
    var powerMw: Double
    var footprintMb: Double
}

/// The rates of a sample and their stats in the summary, in the order of every table.
let rateMetrics: [(name: String, label: String, sample: KeyPath<Sample, Double>, stat: KeyPath<Summary, Stat>)] = [
    ("cpu_percent", "CPU %", \.cpuPercent, \.cpuPercent),
    ("children_cpu_percent", "herdr CPU %", \.childrenCpuPercent, \.childrenCpuPercent),
    ("wakeups_per_s", "Wakeups/s", \.wakeupsPerS, \.wakeupsPerS),
    ("idle_wakeups_per_s", "Idle wakeups/s", \.idleWakeupsPerS, \.idleWakeupsPerS),
    ("power_mw", "Power mW", \.powerMw, \.powerMw),
]

/// The result of `compare`.
struct Comparison: Codable {
    struct Run: Codable {
        var file: String
        var label: String?
        var startedAt: String
        var configuration: Configuration
        var durationS: Double
        var commit: String?
    }

    struct Metric: Codable {
        var name: String
        var a: Double
        var b: Double
        var delta: Double
        /// Missing when `a` is zero.
        var deltaPercent: Double?
    }

    var a: Run
    var b: Run
    var metrics: [Metric]
    var warnings: [String]
}

// MARK: - Counters

/// Cumulative counters of a process at one moment; times in nanoseconds.
struct Counters {
    var time: UInt64
    var cpu: UInt64
    var childrenCPU: UInt64
    var wakeups: UInt64
    var idleWakeups: UInt64
    /// Nanojoules.
    var energy: UInt64
    var footprint: UInt64
    var lifetimeMaxFootprint: UInt64
    var startTime: UInt64

    /// Nil once the process is gone.
    static func read(pid: pid_t) -> Counters? {
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        guard result == 0 else { return nil }
        return Counters(
            time: clock_gettime_nsec_np(CLOCK_UPTIME_RAW),
            cpu: nanoseconds(info.ri_user_time + info.ri_system_time),
            childrenCPU: nanoseconds(info.ri_child_user_time + info.ri_child_system_time),
            wakeups: info.ri_interrupt_wkups,
            idleWakeups: info.ri_pkg_idle_wkups,
            energy: info.ri_billed_energy,
            footprint: info.ri_phys_footprint,
            lifetimeMaxFootprint: info.ri_lifetime_max_phys_footprint,
            startTime: nanoseconds(info.ri_proc_start_abstime))
    }

    /// Converts Mach absolute time units, which `proc_pid_rusage` reports times in.
    private static func nanoseconds(_ ticks: UInt64) -> UInt64 {
        ticks * UInt64(timebase.numer) / UInt64(timebase.denom)
    }

    private static let timebase: mach_timebase_info_data_t = {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        return timebase
    }()
}

/// Rates between two readings, `start` being the first reading of the run.
func sample(from a: Counters, to b: Counters, start: Counters) -> Sample {
    func delta(_ value: KeyPath<Counters, UInt64>) -> Double {
        Double(b[keyPath: value] > a[keyPath: value] ? b[keyPath: value] - a[keyPath: value] : 0)
    }
    let seconds = delta(\.time) / 1e9
    return Sample(
        tS: round3(Double(b.time - start.time) / 1e9),
        cpuPercent: round3(delta(\.cpu) / 1e9 / seconds * 100),
        childrenCpuPercent: round3(delta(\.childrenCPU) / 1e9 / seconds * 100),
        wakeupsPerS: round3(delta(\.wakeups) / seconds),
        idleWakeupsPerS: round3(delta(\.idleWakeups) / seconds),
        powerMw: round3(delta(\.energy) / 1e6 / seconds),
        footprintMb: megabytes(b.footprint))
}

func megabytes(_ bytes: UInt64) -> Double { round3(Double(bytes) / 1_048_576) }

func round3(_ value: Double) -> Double { (value * 1000).rounded() / 1000 }

// MARK: - Process and system

func buddrProcesses() -> [(pid: pid_t, path: String)] {
    let capacity = Int(proc_listallpids(nil, 0)) + 64
    var pids = [pid_t](repeating: 0, count: capacity)
    let count = Int(proc_listallpids(&pids, Int32(capacity * MemoryLayout<pid_t>.stride)))
    return pids.prefix(max(count, 0)).compactMap { pid in
        guard pid > 0, let path = executablePath(pid), path.hasSuffix("/Buddr.app/Contents/MacOS/Buddr") else {
            return nil
        }
        return (pid, path)
    }
}

func executablePath(_ pid: pid_t) -> String? {
    var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
    let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
    guard length > 0 else { return nil }
    return string(buffer.prefix(Int(length)))
}

/// Debug builds put the app's code into `Buddr.debug.dylib` next to the executable (`ENABLE_DEBUG_DYLIB`).
func configuration(of executable: String) -> Configuration {
    FileManager.default.fileExists(atPath: debugDylib(of: executable)) ? .debug : .release
}

func debugDylib(of executable: String) -> String { executable + ".debug.dylib" }

/// The newer of the executable and its debug dylib, which holds the code of a Debug build.
func buildDate(_ executable: String) -> Date? {
    [executable, debugDylib(of: executable)]
        .compactMap { try? FileManager.default.attributesOfItem(atPath: $0)[.modificationDate] as? Date }
        .max()
}

func systemInfo() -> SystemInfo {
    let version = ProcessInfo.processInfo.operatingSystemVersion
    var macos = "\(version.majorVersion).\(version.minorVersion)"
    if version.patchVersion > 0 { macos += ".\(version.patchVersion)" }
    return SystemInfo(macos: macos, model: sysctlString("hw.model") ?? "unknown", powerSource: powerSource())
}

func sysctlString(_ name: String) -> String? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0 else { return nil }
    var buffer = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
    return string(buffer.prefix { $0 != 0 })
}

func string(_ characters: some Sequence<CChar>) -> String {
    String(decoding: characters.map { UInt8(bitPattern: $0) }, as: UTF8.self)
}

func powerSource() -> PowerSource {
    guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
        let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
    else { return .unknown }
    switch type {
    case kIOPMACPowerKey: return .ac
    case kIOPMBatteryPowerKey: return .battery
    case kIOPMUPSPowerKey: return .ups
    default: return .unknown
    }
}

let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

func repoInfo() -> RepoInfo? {
    func git(_ arguments: String...) -> String? {
        run("/usr/bin/git", ["-C", repoRoot.path] + arguments)
    }
    guard let head = git("log", "-1", "--format=%h %cI")?.split(separator: " "), head.count == 2,
        let status = git("status", "--porcelain")
    else { return nil }
    return RepoInfo(commit: String(head[0]), dirty: !status.isEmpty, lastCommitAt: String(head[1]))
}

/// Trimmed stdout of a command that succeeded.
func run(_ executable: String, _ arguments: [String]) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    guard (try? process.run()) != nil else { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { return nil }
    return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Records a Time Profiler trace of a process until `stop()`.
final class Profiler {
    let output: URL
    private let process = Process()
    private let log: URL

    init(pid: pid_t, output: URL) throws {
        self.output = output
        log = FileManager.default.temporaryDirectory.appendingPathComponent("buddr-measure-\(getpid())-xctrace.log")
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let handle = try FileHandle(forWritingTo: log)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = [
            "xctrace", "record", "--template", "Time Profiler", "--attach", "\(pid)", "--output", output.path,
            "--no-prompt",
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = handle
        process.standardError = handle
        // Foundation starts it in its own process group, so a Ctrl-C in the terminal doesn't reach it.
        try process.run()
    }

    /// Waits until xctrace records, which takes a few seconds; false if it gave up.
    func waitUntilRecording() -> Bool {
        let deadline = Date().addingTimeInterval(60)
        while process.isRunning && Date() < deadline {
            if logText.contains("Ctrl-C to stop the recording") { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return false
    }

    /// Ends the recording and waits until the trace is written; returns an error message if it failed.
    func stop() -> String? {
        if process.isRunning { process.interrupt() }
        process.waitUntilExit()
        defer { try? FileManager.default.removeItem(at: log) }
        guard process.terminationStatus != 0 || !FileManager.default.fileExists(atPath: output.path) else {
            return nil
        }
        let lastLine =
            logText.split(separator: "\n").last.map(String.init) ?? "exit status \(process.terminationStatus)"
        return "Profiling failed: \(lastLine)"
    }

    private var logText: String { (try? String(contentsOf: log, encoding: .utf8)) ?? "" }
}

// MARK: - Recording

func record(_ options: Options) {
    if options.json && options.duration == nil {
        fail("--json needs --duration (an agent can't press Ctrl-C)")
    }
    let (pid, path) = target(options.pid)
    let startedAt = Date()
    let settings = Settings.read()
    let configuration = configuration(of: path)
    let repo = repoInfo()
    let system = systemInfo()

    let directory = repoRoot.appendingPathComponent("build/measurements")
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var baseName = "\(startedAt.fileStamp)-\(configuration)"
    if let label = options.label { baseName += "-\(label.fileNameSafe)" }
    let file = directory.appendingPathComponent(baseName + ".json")

    var profiler: Profiler?
    if options.profile {
        do {
            profiler = try Profiler(pid: pid, output: directory.appendingPathComponent(baseName + ".trace"))
        } catch {
            fail("can't start xctrace: \(error)")
        }
    }

    let stop = DispatchSemaphore(value: 0)
    // A handler instead of SIG_IGN: an ignored signal stays ignored in child processes (xctrace has to get SIGINT).
    signal(SIGINT) { _ in }
    signal(SIGTERM) { _ in }
    let signalSources = [SIGINT, SIGTERM].map { number in
        let source = DispatchSource.makeSignalSource(signal: number, queue: .global())
        source.setEventHandler { stop.signal() }
        source.resume()
        return source
    }

    if let profiler {
        printProgress("Starting the profiler…", json: options.json)
        guard profiler.waitUntilRecording() else { fail(profiler.stop() ?? "Profiling failed: xctrace didn't start") }
    }
    if options.json {
        let length = options.duration.map { " for \(clock($0))" } ?? ""
        printError("Measuring Buddr \(pid) (\(configuration.name))\(length)…")
    } else {
        print("Measuring Buddr \(pid) · \(configuration.name) · \(settings.text)")
        if configuration == .debug { print("Warning: \(debugWarning)") }
        print(options.duration.map { "Stops after \(clock($0)) or on Ctrl-C." } ?? "Stops on Ctrl-C.")
        print()
        print(liveHeader)
    }
    // Read after the setup above, which would otherwise end up in the first sample.
    guard let first = Counters.read(pid: pid) else { fail("can't read the counters of process \(pid)") }
    let builtAt = buildDate(path) ?? startedAt
    let app = AppInfo(
        pid: pid, path: path, configuration: configuration, builtAt: builtAt.iso8601,
        uptimeS: round3(Double(first.time - min(first.startTime, first.time)) / 1e9))

    var samples: [Sample] = []
    var last = first
    var endReason = EndReason.interrupted
    let deadline = options.duration.map { first.time + UInt64($0 * 1e9) }
    while true {
        var wait = options.interval
        if let deadline { wait = min(wait, Double(deadline > last.time ? deadline - last.time : 0) / 1e9) }
        let interrupted = stop.wait(timeout: .now() + wait) == .success
        guard let current = Counters.read(pid: pid) else {
            endReason = .appExited
            break
        }
        // A Ctrl-C right after a sample would make a sample too short to mean anything.
        if current.time - last.time >= 200_000_000 {
            let sample = sample(from: last, to: current, start: first)
            samples.append(sample)
            if !options.json { print(liveLine(sample)) }
            last = current
        }
        if interrupted { break }
        if let deadline, current.time >= deadline {
            endReason = .duration
            break
        }
    }
    signalSources.forEach { $0.cancel() }
    if !options.json { print() }
    guard !samples.isEmpty else { fail("stopped before the first sample") }

    var warnings: [String] = []
    if configuration == .debug { warnings.append(debugWarning) }
    if let repo, let committed = Date.parse(repo.lastCommitAt), builtAt < committed {
        warnings.append("The app was built before the last commit; it may not match the repo.")
    }
    if app.uptimeS < 60 {
        warnings.append("The app started \(Int(app.uptimeS)) s before the measurement; startup may skew the numbers.")
    }
    let duration = round3(Double(last.time - first.time) / 1e9)
    if endReason == .appExited {
        warnings.append("The app exited after \(clock(duration)); the results are partial.")
    }
    if duration < shortRun { warnings.append(shortRunWarning(duration)) }
    if Settings.read() != settings { warnings.append("The settings changed during the measurement.") }
    var tracePath: String?
    if let profiler {
        printProgress("Writing the trace…", json: options.json)
        if let error = profiler.stop() {
            warnings.append(error)
        } else {
            tracePath = profiler.output.path
            warnings.append("Profiled with Time Profiler, which adds some overhead.")
        }
    }

    let total = sample(from: first, to: last, start: first)
    func stat(_ rate: KeyPath<Sample, Double>) -> Stat {
        Stat(avg: total[keyPath: rate], over: samples.map { $0[keyPath: rate] })
    }
    let measurement = Measurement(
        schema: 1, label: options.label, startedAt: startedAt.iso8601, durationS: duration,
        intervalS: options.interval, endReason: endReason, tracePath: tracePath, app: app,
        repo: repo, system: system, settings: settings,
        summary: Summary(
            cpuPercent: stat(\.cpuPercent), childrenCpuPercent: stat(\.childrenCpuPercent),
            wakeupsPerS: stat(\.wakeupsPerS), idleWakeupsPerS: stat(\.idleWakeupsPerS), powerMw: stat(\.powerMw),
            footprintMb: Footprint(
                start: megabytes(first.footprint), end: megabytes(last.footprint),
                max: ([megabytes(first.footprint)] + samples.map(\.footprintMb)).max()!,
                lifetimeMax: megabytes(last.lifetimeMaxFootprint))),
        warnings: warnings, samples: samples)

    do {
        try Data((json(measurement) + "\n").utf8).write(to: file)
    } catch {
        fail("can't save \(file.path): \(error)")
    }
    if options.json {
        printJSON(measurement, samples: options.samples)
    } else {
        printSummary(measurement)
        print()
    }
    printProgress("Saved \(displayPath(file.path))", json: options.json)
}

func target(_ pid: pid_t?) -> (pid: pid_t, path: String) {
    let processes = buddrProcesses()
    if let pid {
        guard let process = processes.first(where: { $0.pid == pid }) else { fail("process \(pid) is not Buddr") }
        return process
    }
    switch processes.count {
    case 0:
        fail("Buddr is not running")
    case 1:
        return processes[0]
    default:
        let list = processes.map { "  \($0.pid)  \($0.path)" }.joined(separator: "\n")
        fail("several Buddr processes run, choose one with --pid:\n\(list)")
    }
}

let debugWarning = "Debug build – absolute numbers are not representative; compare only with other Debug runs."
let shortRun = 60.0

func shortRunWarning(_ duration: Double) -> String {
    "Short measurement (\(clock(duration))); polls and random clips make it noisy."
}

/// Without the samples unless asked for them: an agent seldom needs them, and they make the output long.
func printJSON(_ measurement: Measurement, samples: Bool) {
    var measurement = measurement
    if !samples { measurement.samples = nil }
    print(json(measurement))
}

// MARK: - Show and compare

func show(_ options: Options) {
    guard options.files.count == 1 else { fail("show needs one file\n\n\(usage)", status: 2) }
    let measurement = load(options.files[0])
    if options.json {
        printJSON(measurement, samples: options.samples)
    } else {
        printSummary(measurement)
    }
}

func compare(_ options: Options) {
    guard options.files.count == 2 else { fail("compare needs two files\n\n\(usage)", status: 2) }
    let a = load(options.files[0])
    let b = load(options.files[1])
    guard a.app.configuration == b.app.configuration else {
        fail("can't compare a \(a.app.configuration.rawValue) run with a \(b.app.configuration.rawValue) run")
    }

    var warnings: [String] = []
    let changed = zip(a.settings.fields, b.settings.fields).filter { $0.value != $1.value }
    if !changed.isEmpty {
        let list = changed.map { "\($0.name) \($0.value) → \($1.value)" }.joined(separator: ", ")
        warnings.append("The settings differ: \(list).")
    }
    if a.system.powerSource != b.system.powerSource {
        warnings.append("The power source differs: \(a.system.powerSource.text) → \(b.system.powerSource.text).")
    }
    if a.profiled != b.profiled { warnings.append("Only one of the runs was profiled.") }
    for (name, run) in [("A", a), ("B", b)] where run.durationS < shortRun {
        warnings.append("\(name): \(shortRunWarning(run.durationS))")
    }

    let rows = comparedMetrics.map { metric in
        let valueA = a.summary[keyPath: metric.value]
        let valueB = b.summary[keyPath: metric.value]
        return (
            label: metric.label,
            metric: Comparison.Metric(
                name: metric.name, a: valueA, b: valueB, delta: round3(valueB - valueA),
                deltaPercent: valueA == 0 ? nil : round3((valueB - valueA) / valueA * 100))
        )
    }
    let comparison = Comparison(
        a: Comparison.Run(a, file: options.files[0]), b: Comparison.Run(b, file: options.files[1]),
        metrics: rows.map(\.metric), warnings: warnings)

    if options.json {
        print(json(comparison))
        return
    }
    print("A  \(runLine(a))")
    print("B  \(runLine(b))")
    print()
    print(pad("", 20) + pad("A", 10, right: true) + pad("B", 10, right: true) + pad("Δ", 10, right: true))
    for (label, metric) in rows {
        var line = pad(label, 20) + pad(number(metric.a), 10, right: true)
        line += pad(number(metric.b), 10, right: true) + pad(signed(metric.delta), 10, right: true)
        if let percent = metric.deltaPercent { line += "  (\(String(format: "%+.0f", percent)) %)" }
        print(line)
    }
    printWarnings(warnings)
}

/// The avg and p95 of every rate, then memory.
let comparedMetrics: [(name: String, label: String, value: KeyPath<Summary, Double>)] =
    rateMetrics.flatMap { rate in
        [("avg", \Stat.avg), ("p95", \Stat.p95)].map { stat, value in
            ("\(rate.name).\(stat)", "\(rate.label) \(stat)", rate.stat.appending(path: value))
        }
    } + [
        ("footprint_mb.end", "Memory MB end", \.footprintMb.end),
        ("footprint_mb.max", "Memory MB max", \.footprintMb.max),
    ]

extension Comparison.Run {
    init(_ measurement: Measurement, file: String) {
        self.init(
            file: file, label: measurement.label, startedAt: measurement.startedAt,
            configuration: measurement.app.configuration, durationS: measurement.durationS,
            commit: measurement.repo?.commit)
    }
}

func load(_ path: String) -> Measurement {
    do {
        return try decoder.decode(Measurement.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    } catch {
        fail("can't read \(path): \(error)")
    }
}

// MARK: - Text output

let liveColumns = ["Time"] + rateMetrics.map(\.label) + ["Memory MB"]
let liveHeader = liveColumns.map { pad($0, liveWidth($0), right: true) }.joined()

func liveWidth(_ title: String) -> Int { max(title.count + 2, 8) }

func liveLine(_ sample: Sample) -> String {
    let values =
        [clock(sample.tS)] + rateMetrics.map { number(sample[keyPath: $0.sample]) } + [number(sample.footprintMb)]
    return zip(values, liveColumns).map { pad($0, liveWidth($1), right: true) }.joined()
}

func printSummary(_ measurement: Measurement) {
    var first = "Buddr \(measurement.app.pid) · \(measurement.app.configuration.name)"
    if let repo = measurement.repo { first += " · \(repo.text)" }
    first += " · on \(measurement.system.powerSource.text)"
    if let label = measurement.label { first += " · label \(label)" }
    print(first)
    let ending =
        switch measurement.endReason {
        case .duration: ""
        case .interrupted: " · stopped by hand"
        case .appExited: " · the app exited"
        }
    print(
        "Started \(measurement.startedText) · \(clock(measurement.durationS)) (\(measurement.samples?.count ?? 0)"
            + " samples × \(seconds(measurement.intervalS)) s)\(ending)")
    print("Settings: \(measurement.settings.text)")
    print()

    print(pad("", 18) + ["avg", "p95", "max"].map { pad($0, 9, right: true) }.joined())
    for rate in rateMetrics {
        let stat = measurement.summary[keyPath: rate.stat]
        print(pad(rate.label, 18) + [stat.avg, stat.p95, stat.max].map { pad(number($0), 9, right: true) }.joined())
    }
    let memory = measurement.summary.footprintMb
    print(
        pad("Memory MB", 18) + "\(number(memory.start)) → \(number(memory.end)) (max \(number(memory.max)),"
            + " lifetime max \(number(memory.lifetimeMax)))")

    if let trace = measurement.tracePath { print("\nTrace: \(displayPath(trace))") }
    printWarnings(measurement.warnings)
}

func runLine(_ measurement: Measurement) -> String {
    var parts = [measurement.label ?? "(no label)", measurement.app.configuration.name, measurement.startedText]
    parts.append(clock(measurement.durationS))
    if let repo = measurement.repo { parts.append(repo.text) }
    return parts.joined(separator: " · ")
}

extension Measurement {
    var startedText: String { Date.parse(startedAt)?.displayStamp ?? startedAt }
    var profiled: Bool { tracePath != nil }
}

func printWarnings(_ warnings: [String]) {
    if !warnings.isEmpty { print() }
    warnings.forEach { print("Warning: \($0)") }
}

/// Whole seconds without decimals.
func seconds(_ value: Double) -> String {
    value == value.rounded() ? "\(Int(value))" : number(value)
}

/// Two decimals below 10, one above: small CPU percentages stay visible.
func number(_ value: Double) -> String {
    String(format: abs(value) < 10 ? "%.2f" : "%.1f", value)
}

func signed(_ value: Double) -> String {
    value > 0 ? "+" + number(value) : number(value)
}

func pad(_ text: String, _ width: Int, right: Bool = false) -> String {
    let padding = String(repeating: " ", count: max(0, width - text.count))
    return right ? padding + text : text + padding
}

/// m:ss, or h:mm:ss from an hour on.
func clock(_ seconds: Double) -> String {
    let total = Int(seconds.rounded())
    let (hours, minutes, rest) = (total / 3600, total / 60 % 60, total % 60)
    return hours > 0
        ? String(format: "%d:%02d:%02d", hours, minutes, rest) : String(format: "%d:%02d", minutes, rest)
}

func displayPath(_ path: String) -> String {
    let current = FileManager.default.currentDirectoryPath + "/"
    return path.hasPrefix(current) ? String(path.dropFirst(current.count)) : path
}

// MARK: - JSON, dates, errors

/// Reads what `json(_:)` writes.
let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
}()

/// Pretty-printed JSON of the result types with snake_case keys in declaration order (`JSONEncoder` orders them at
/// random, which buries the summary); plain values are written by `JSONEncoder`. Objects of plain values in an array
/// (samples, metrics) and objects of numbers (stats) take one line each. Nil optionals are left out.
func json(_ value: Any, indent: String = "", inline: Bool = false) -> String {
    let mirror = Mirror(reflecting: value)
    if mirror.displayStyle == .optional {
        return mirror.children.first.map { json($0.value, indent: indent, inline: inline) } ?? "null"
    }
    if mirror.children.isEmpty, let plain = value as? any Encodable {
        // Throws only for values JSON can't hold (NaN, infinity).
        return (try? plainEncoder.encode(plain)).map { String(decoding: $0, as: UTF8.self) } ?? "null"
    }
    let inner = indent + "  "
    if mirror.displayStyle == .collection {
        let items = mirror.children.map { inner + json($0.value, indent: inner, inline: true) }
        return "[\n" + items.joined(separator: ",\n") + "\n" + indent + "]"
    }
    let fields = mirror.children.compactMap { child -> (key: String, value: Any)? in
        let childMirror = Mirror(reflecting: child.value)
        let value: Any? = childMirror.displayStyle == .optional ? childMirror.children.first?.value : child.value
        return value.map { (json(snakeCase(child.label!)), $0) }
    }
    let plain = fields.allSatisfy { Mirror(reflecting: $0.value).children.isEmpty }
    let numbers = fields.allSatisfy { $0.value is Double }
    if plain && (inline || numbers) {
        return "{ " + fields.map { "\($0.key): \(json($0.value))" }.joined(separator: ", ") + " }"
    }
    let lines = fields.map { "\(inner)\($0.key): \(json($0.value, indent: inner))" }
    return "{\n" + lines.joined(separator: ",\n") + "\n" + indent + "}"
}

let plainEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .withoutEscapingSlashes
    return encoder
}()

/// What `JSONDecoder.KeyDecodingStrategy.convertFromSnakeCase` turns back into the property name.
func snakeCase(_ name: String) -> String {
    name.map { $0.isUppercase ? "_" + $0.lowercased() : String($0) }.joined()
}

extension Date {
    /// With the local time zone offset.
    var iso8601: String {
        ISO8601DateFormatter.string(from: self, timeZone: .current, formatOptions: .withInternetDateTime)
    }

    var fileStamp: String { formatted("yyyy-MM-dd'T'HH-mm-ss") }
    var displayStamp: String { formatted("yyyy-MM-dd HH:mm:ss") }

    static func parse(_ text: String) -> Date? { ISO8601DateFormatter().date(from: text) }

    private func formatted(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
}

extension String {
    var fileNameSafe: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
    }
}

/// To stderr in JSON mode, which keeps stdout for the JSON.
func printProgress(_ message: String, json: Bool) {
    if json { printError(message) } else { print(message) }
}

func printError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

func fail(_ message: String, status: Int32 = 1) -> Never {
    printError("measure: \(message)")
    exit(status)
}

// MARK: - Options

enum Command: String {
    case record, show, compare
}

struct Options {
    var command = Command.record
    var files: [String] = []
    var duration: Double?
    var interval = 5.0
    var label: String?
    var pid: pid_t?
    var json = false
    var samples = false
    var profile = false
}

func parseOptions(_ arguments: [String]) -> Options {
    var options = Options()
    var rest = arguments[...]
    if let command = rest.first.flatMap(Command.init(rawValue:)) {
        options.command = command
        rest = rest.dropFirst()
    }
    func value(for option: String) -> String {
        guard let value = rest.popFirst() else { fail("\(option) needs a value", status: 2) }
        return value
    }
    while let argument = rest.popFirst() {
        switch argument {
        case "--duration": options.duration = parseDuration(value(for: argument))
        case "--interval": options.interval = parseDuration(value(for: argument))
        case "--label": options.label = value(for: argument)
        case "--pid":
            guard let pid = pid_t(value(for: argument)) else { fail("--pid needs a number", status: 2) }
            options.pid = pid
        case "--json": options.json = true
        case "--samples": options.samples = true
        case "--profile": options.profile = true
        case "-h", "--help":
            print(usage)
            exit(0)
        case _ where argument.hasPrefix("-"): fail("unknown option \(argument)\n\n\(usage)", status: 2)
        default: options.files.append(argument)
        }
    }
    if options.command == .record && !options.files.isEmpty {
        fail("unexpected argument \(options.files[0])\n\n\(usage)", status: 2)
    }
    if options.interval < 0.5 { fail("--interval must be at least 0.5s", status: 2) }
    return options
}

/// 90s, 5m, 1h, 500ms or plain seconds.
func parseDuration(_ text: String) -> Double {
    let units: [(suffix: String, seconds: Double)] = [("ms", 0.001), ("s", 1), ("m", 60), ("h", 3600)]
    let unit = units.first { text.hasSuffix($0.suffix) && Double(text.dropLast($0.suffix.count)) != nil }
    guard let value = Double(unit.map { String(text.dropLast($0.suffix.count)) } ?? text), value > 0 else {
        fail("invalid duration \(text)", status: 2)
    }
    return value * (unit?.seconds ?? 1)
}

// MARK: - Main

setvbuf(stdout, nil, _IOLBF, 0)
let options = parseOptions(Array(CommandLine.arguments.dropFirst()))
switch options.command {
case .record: record(options)
case .show: show(options)
case .compare: compare(options)
}
