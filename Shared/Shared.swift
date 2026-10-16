import Foundation

enum Shared {
    static let groupID = "NNJ8PRGN55.com.reruol.qingright"
    // Darwin 通知不带数据，载荷放在 group 容器里的 request.json
    static let requestNotification = "com.reruol.qingright.request"
    static let configVersionKey = "configVersion"
    static let commonDirsKey = "commonDirs"

    static var defaults: UserDefaults { UserDefaults(suiteName: groupID)! }

    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)!
    }

    static var requestURL: URL { containerURL.appendingPathComponent("request.json") }

    static func commonDirs() -> [String] {
        if let dirs = defaults.stringArray(forKey: commonDirsKey) { return dirs }
        let home = NSHomeDirectoryForUser(NSUserName()) ?? NSHomeDirectory()
        return ["Desktop", "Downloads", "Documents"].map { "\(home)/\($0)" }
    }

    static func setCommonDirs(_ dirs: [String]) {
        defaults.set(dirs, forKey: commonDirsKey)
        defaults.set(defaults.integer(forKey: configVersionKey) + 1, forKey: configVersionKey)
    }
}

enum Action: String, Codable {
    case newFile, openTerminal, openDir, copyTo, moveTo
}

struct Request: Codable {
    var action: Action
    var target: String        // 当前目录或目标目录
    var items: [String] = []  // 选中的文件
    var arg: String = ""      // newFile 时为扩展名
}

enum NewFileKind: String, CaseIterable {
    case txt, md, docx, xlsx

    var title: String {
        switch self {
        case .txt: return "文本文档 (.txt)"
        case .md: return "Markdown (.md)"
        case .docx: return "Word 文档 (.docx)"
        case .xlsx: return "Excel 表格 (.xlsx)"
        }
    }
}
