import Foundation

/// The game's saves, kept natively as one JSON file of localStorage key/value pairs.
///
/// The page still uses localStorage; Game/ios-bridge.js mirrors every write here, and on launch the
/// saved pairs are copied back into the page before the game reads them. So the save survives WebKit
/// clearing its storage, and it is part of the device's iCloud/computer backup like any app data.
///
/// The file lives in Application Support/Saves. The first write of each launch first copies the
/// previous file to localStorage.previous.json, so one bad session can always be rolled back.
final class SaveStore {
    static let shared = SaveStore()

    private let queue = DispatchQueue(label: "com.samuelling.animalsanctuary.saves")
    private var values: [String: String] = [:]
    private var pendingWrite: DispatchWorkItem?
    private var backedUpThisLaunch = false
    private let fileURL: URL
    private let backupURL: URL

    private init() {
        let fm = FileManager.default
        let support = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        let dir = support.appendingPathComponent("Saves", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("localStorage.json")
        backupURL = dir.appendingPathComponent("localStorage.previous.json")
        values = Self.read(fileURL) ?? Self.read(backupURL) ?? [:]
    }

    private static func read(_ url: URL) -> [String: String]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }

    /// JavaScript that hands the saved pairs to ios-bridge.js (it runs at document start, before the game).
    func seedScript() -> String {
        let snapshot = queue.sync { values }
        let json = (try? JSONEncoder().encode(snapshot)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return "window.__AS_NATIVE_SAVE=\(json);"
    }

    /// A message from ios-bridge.js: {op:"set",k,v} | {op:"del",k} | {op:"clear"} | {op:"all",data}.
    func handle(_ body: Any) {
        guard let message = body as? [String: Any], let op = message["op"] as? String else { return }
        let key = message["k"] as? String
        let value = message["v"] as? String
        var all: [String: String] = [:]
        if op == "all", let data = message["data"] as? [String: Any] {
            for (k, v) in data { if let s = v as? String { all[k] = s } }
        }
        queue.async {
            switch op {
            case "set": if let key, let value { self.values[key] = value }
            case "del": if let key { self.values.removeValue(forKey: key) }
            case "clear": self.values.removeAll()
            case "all": self.values.merge(all) { _, new in new }
            default: return
            }
            self.scheduleWrite()
        }
    }

    /// Writes now if a save is waiting. Called when the app leaves the foreground.
    func flush() {
        queue.sync {
            guard let pending = pendingWrite else { return }
            pending.cancel()
            writeNow()
        }
    }

    // The game saves after almost every action, so writes are coalesced into one every ~0.75 s.
    private func scheduleWrite() {
        pendingWrite?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.writeNow() }
        pendingWrite = work
        queue.asyncAfter(deadline: .now() + 0.75, execute: work)
    }

    private func writeNow() {
        pendingWrite = nil
        guard let data = try? JSONEncoder().encode(values) else { return }
        let fm = FileManager.default
        if !backedUpThisLaunch {
            backedUpThisLaunch = true
            if fm.fileExists(atPath: fileURL.path) {
                try? fm.removeItem(at: backupURL)
                try? fm.copyItem(at: fileURL, to: backupURL)
            }
        }
        try? data.write(to: fileURL, options: .atomic)
    }
}
