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
        if let url = Shared.url(for: req) { NSWorkspace.shared.open(url) }
    }
}
