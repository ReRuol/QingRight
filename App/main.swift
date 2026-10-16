import Cocoa
import FinderSync

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ note: Notification) {
        DistributedNotificationCenter.default().addObserver(forName: Shared.configRequestNotification, object: nil, queue: .main) { _ in
            Config.broadcast()
        }
        Config.broadcast()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "轻右键")
        rebuildMenu()

        if !FIFinderSyncController.isExtensionEnabled { FIFinderSyncController.showExtensionManagementInterface() }
    }

    func application(_ app: NSApplication, open urls: [URL]) {
        urls.compactMap(Shared.request(from:)).forEach(Handler.perform)
    }

    private func rebuildMenu() {
        let m = NSMenu()
        let dirs = NSMenuItem(title: "常用目录", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for d in Config.dirs {
            let it = NSMenuItem(title: "移除 \((d as NSString).lastPathComponent)", action: #selector(removeDir(_:)), keyEquivalent: "")
            it.representedObject = d
            it.toolTip = d
            sub.addItem(it)
        }
        sub.addItem(.separator())
        sub.addItem(NSMenuItem(title: "添加目录…", action: #selector(addDir), keyEquivalent: ""))
        dirs.submenu = sub
        m.addItem(dirs)
        m.addItem(NSMenuItem(title: "启用访达扩展…", action: #selector(openExtSettings), keyEquivalent: ""))
        m.addItem(.separator())
        m.addItem(NSMenuItem(title: "退出轻右键", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = m
    }

    @objc private func addDir() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }
        var dirs = Config.dirs
        for u in panel.urls where !dirs.contains(u.path) { dirs.append(u.path) }
        Config.set(dirs)
        rebuildMenu()
    }

    @objc private func removeDir(_ sender: NSMenuItem) {
        guard let d = sender.representedObject as? String else { return }
        Config.set(Config.dirs.filter { $0 != d })
        rebuildMenu()
    }

    @objc private func openExtSettings() {
        FIFinderSyncController.showExtensionManagementInterface()
    }
}

enum Config {
    static var dirs: [String] {
        UserDefaults.standard.stringArray(forKey: Shared.commonDirsKey) ?? Shared.defaultDirs()
    }

    static func set(_ dirs: [String]) {
        UserDefaults.standard.set(dirs, forKey: Shared.commonDirsKey)
        broadcast()
    }

    static func broadcast() {
        DistributedNotificationCenter.default().postNotificationName(
            Shared.configNotification, object: nil, userInfo: [Shared.commonDirsKey: dirs], deliverImmediately: true)
    }
}

enum Handler {
    static func perform(_ req: Request) {
        let fm = FileManager.default
        let target = URL(fileURLWithPath: req.target)
        switch req.action {
        case .newFile:
            let kind = NewFileKind(rawValue: req.arg) ?? .txt
            let dest = uniqueURL(in: target, base: "未命名", ext: kind.rawValue)
            if let tpl = Bundle.main.url(forResource: "blank", withExtension: kind.rawValue) {
                try? fm.copyItem(at: tpl, to: dest)
            } else {
                fm.createFile(atPath: dest.path, contents: Data())
            }
            NSWorkspace.shared.activateFileViewerSelecting([dest])
        case .openTerminal:
            let term = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal")!
            NSWorkspace.shared.open([target], withApplicationAt: term, configuration: NSWorkspace.OpenConfiguration())
        case .openDir:
            NSWorkspace.shared.open(target)
        case .copyTo, .moveTo:
            var done: [URL] = []
            for p in req.items {
                let src = URL(fileURLWithPath: p)
                let name = src.deletingPathExtension().lastPathComponent
                let dest = uniqueURL(in: target, base: name, ext: src.pathExtension)
                do {
                    if req.action == .copyTo { try fm.copyItem(at: src, to: dest) } else { try fm.moveItem(at: src, to: dest) }
                    done.append(dest)
                } catch {
                    alert("操作失败：\(src.lastPathComponent)\n\(error.localizedDescription)")
                }
            }
            if !done.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(done) }
        }
    }

    // 重名时追加 " 2"、" 3"…，跟访达的习惯一致
    static func uniqueURL(in dir: URL, base: String, ext: String) -> URL {
        let file = { (n: String) in dir.appendingPathComponent(ext.isEmpty ? n : "\(n).\(ext)") }
        var url = file(base), i = 2
        while FileManager.default.fileExists(atPath: url.path) { url = file("\(base) \(i)"); i += 1 }
        return url
    }

    static func alert(_ msg: String) {
        let a = NSAlert()
        a.messageText = "轻右键"
        a.informativeText = msg
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
