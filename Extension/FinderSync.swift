import Cocoa
import FinderSync

final class FinderSync: FIFinderSync {
    // 常用目录只存内存：主 App 启动/改配置时广播过来，右键时零 IO
    private var cachedDirs = Shared.defaultDirs()
    private let dnc = DistributedNotificationCenter.default()

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
        dnc.addObserver(forName: Shared.configNotification, object: nil, queue: .main) { [weak self] note in
            if let dirs = note.userInfo?[Shared.commonDirsKey] as? [String] { self?.cachedDirs = dirs }
        }
        dnc.postNotificationName(Shared.configRequestNotification, object: nil, userInfo: nil, deliverImmediately: true)
    }

    private func dirs() -> [String] { cachedDirs }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        let onItems = menuKind == .contextualMenuForItems

        menu.addItem(submenu("新建文件", icon: "doc.badge.plus",
                             NewFileKind.allCases.enumerated().map { item($1.title, #selector(newFile(_:)), tag: $0) }))
        menu.addItem(item(onItems ? "复制路径" : "复制当前路径", #selector(copyPath(_:)), icon: "doc.on.clipboard"))
        menu.addItem(item("在终端中打开", #selector(openTerminal(_:)), icon: "terminal"))

        let ds = dirs()
        menuDirs = ds
        let name = { (p: String) in (p as NSString).lastPathComponent }
        menu.addItem(submenu("常用目录", icon: "folder",
                             ds.enumerated().map { item(name($1), #selector(openDir(_:)), tag: $0) }))
        if onItems {
            menu.addItem(submenu("复制到", icon: "doc.on.doc",
                                 ds.enumerated().map { item(name($1), #selector(copyTo(_:)), tag: $0) }))
            menu.addItem(submenu("移动到", icon: "arrow.right.doc.on.clipboard",
                                 ds.enumerated().map { item(name($1), #selector(moveTo(_:)), tag: $0) }))
        }
        return menu
    }

    // MARK: - 菜单构造

    // 访达会复制菜单项再显示，representedObject 会丢，只有 tag 能带回来，所以用 tag 存下标
    private var menuDirs: [String] = []

    private func item(_ title: String, _ sel: Selector, icon: String? = nil, tag: Int = 0) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: sel, keyEquivalent: "")
        it.target = self
        it.tag = tag
        if let icon { it.image = symbol(icon) }
        return it
    }

    private var symbols: [String: NSImage] = [:]

    private func symbol(_ name: String) -> NSImage? {
        if let img = symbols[name] { return img }
        let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        symbols[name] = img
        return img
    }

    private func submenu(_ title: String, icon: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        it.image = symbol(icon)
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
        send(Request(action: .newFile, target: currentDir, arg: NewFileKind.allCases[safe: sender.tag]?.rawValue ?? "txt"))
    }

    @objc func openTerminal(_ sender: NSMenuItem) {
        send(Request(action: .openTerminal, target: currentDir))
    }

    private func dir(_ sender: NSMenuItem) -> String? { menuDirs[safe: sender.tag] }

    @objc func openDir(_ sender: NSMenuItem) {
        guard let d = dir(sender) else { return }
        send(Request(action: .openDir, target: d))
    }

    @objc func copyTo(_ sender: NSMenuItem) {
        guard let d = dir(sender) else { return }
        send(Request(action: .copyTo, target: d, items: selected))
    }

    @objc func moveTo(_ sender: NSMenuItem) {
        guard let d = dir(sender) else { return }
        send(Request(action: .moveTo, target: d, items: selected))
    }

    private func send(_ req: Request) {
        if let url = Shared.url(for: req) { NSWorkspace.shared.open(url) }
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
