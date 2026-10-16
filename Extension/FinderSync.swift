import Cocoa
import FinderSync

final class FinderSync: FIFinderSync {
    // 配置缓存：只有主 App 改了配置（版本号变化）才重新读
    private var cachedVersion = -1
    private var cachedDirs: [String] = []

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    private func dirs() -> [String] {
        let v = Shared.defaults.integer(forKey: Shared.configVersionKey)
        if v != cachedVersion {
            cachedDirs = Shared.commonDirs()
            cachedVersion = v
        }
        return cachedDirs
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        let onItems = menuKind == .contextualMenuForItems

        menu.addItem(submenu("新建文件", icon: "doc.badge.plus",
                             NewFileKind.allCases.map { item($0.title, #selector(newFile(_:)), rep: $0.rawValue) }))
        menu.addItem(item(onItems ? "复制路径" : "复制当前路径", #selector(copyPath(_:)), icon: "doc.on.clipboard"))
        menu.addItem(item("在终端中打开", #selector(openTerminal(_:)), icon: "terminal"))

        let ds = dirs()
        let name = { (p: String) in (p as NSString).lastPathComponent }
        menu.addItem(submenu("常用目录", icon: "folder",
                             ds.map { item(name($0), #selector(openDir(_:)), rep: $0) }))
        if onItems {
            menu.addItem(submenu("复制到", icon: "doc.on.doc",
                                 ds.map { item(name($0), #selector(copyTo(_:)), rep: $0) }))
            menu.addItem(submenu("移动到", icon: "arrow.right.doc.on.clipboard",
                                 ds.map { item(name($0), #selector(moveTo(_:)), rep: $0) }))
        }
        return menu
    }

    // MARK: - 菜单构造

    private func item(_ title: String, _ sel: Selector, icon: String? = nil, rep: String? = nil) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: sel, keyEquivalent: "")
        it.target = self
        it.representedObject = rep
        if let icon { it.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil) }
        return it
    }

    private func submenu(_ title: String, icon: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        it.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        let sub = NSMenu(title: title)
        items.forEach(sub.addItem)
        it.submenu = sub
        return it
    }

    // MARK: - 上下文

    private var selected: [String] {
        (FIFinderSyncController.default().selectedItemURLs() ?? []).map(\.path)
    }

    // 选中单个文件夹时视为在该文件夹内操作
    private var currentDir: String {
        let sel = FIFinderSyncController.default().selectedItemURLs() ?? []
        if sel.count == 1, (try? sel[0].resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
            return sel[0].path
        }
        return FIFinderSyncController.default().targetedURL()?.path ?? NSHomeDirectory()
    }

    // MARK: - 动作（复制路径本地完成，其余交给主 App）

    @objc func copyPath(_ sender: NSMenuItem) {
        let paths = selected.isEmpty ? [currentDir] : selected
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(paths.joined(separator: "\n"), forType: .string)
    }

    @objc func newFile(_ sender: NSMenuItem) {
        send(Request(action: .newFile, target: currentDir, arg: sender.representedObject as? String ?? "txt"))
    }

    @objc func openTerminal(_ sender: NSMenuItem) {
        send(Request(action: .openTerminal, target: currentDir))
    }

    @objc func openDir(_ sender: NSMenuItem) {
        send(Request(action: .openDir, target: sender.representedObject as? String ?? ""))
    }

    @objc func copyTo(_ sender: NSMenuItem) {
        send(Request(action: .copyTo, target: sender.representedObject as? String ?? "", items: selected))
    }

    @objc func moveTo(_ sender: NSMenuItem) {
        send(Request(action: .moveTo, target: sender.representedObject as? String ?? "", items: selected))
    }

    private func send(_ req: Request) {
        guard let data = try? JSONEncoder().encode(req),
              (try? data.write(to: Shared.requestURL, options: .atomic)) != nil else { return }
        let running = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.reruol.qingright").isEmpty
        if running {
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                                 CFNotificationName(Shared.requestNotification as CFString),
                                                 nil, nil, true)
        } else {
            // 主 App 没开时用 URL 拉起，启动后会读取 request.json
            NSWorkspace.shared.open(URL(string: "qingright://run")!)
        }
    }
}
