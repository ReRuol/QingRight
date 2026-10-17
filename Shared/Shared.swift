import Foundation

// 不用 App Group：ad-hoc 签名没有 Team ID，macOS 15 会把共享容器当受保护数据弹授权框。
// 扩展 → 主 App：qingright://run?d=<base64 JSON>，主 App 没开时 LaunchServices 会顺带拉起。
// 主 App → 扩展：分布式通知广播配置，扩展只存在内存里。
enum Shared {
    static let scheme = "qingright"
    static let configNotification = Notification.Name("com.reruol.qingright.config")
    static let configRequestNotification = Notification.Name("com.reruol.qingright.config.request")
    static let commonDirsKey = "commonDirs"

    static func defaultDirs() -> [String] {
        let home = NSHomeDirectoryForUser(NSUserName()) ?? NSHomeDirectory()
        return ["Desktop", "Downloads", "Documents"].map { "\(home)/\($0)" }
    }

    static func url(for req: Request) -> URL? {
        guard let data = try? JSONEncoder().encode(req) else { return nil }
        var c = URLComponents()
        c.scheme = scheme
        c.host = "run"
        c.queryItems = [URLQueryItem(name: "d", value: data.base64EncodedString())]
        return c.url
    }

    static func request(from url: URL) -> Request? {
        guard url.scheme == scheme,
              let d = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "d" })?.value,
              let data = Data(base64Encoded: d) else { return nil }
        return try? JSONDecoder().decode(Request.self, from: data)
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

// 顺序即菜单顺序；docx/xlsx/pptx/pdf/rtf 在 Templates/ 有 blank.<ext> 模板，其余建空文件
enum NewFileKind: String, CaseIterable {
    case docx, xlsx, pptx, pdf, txt, md, rtf, csv

    var title: String {
        switch self {
        case .docx: return "Word 文档 (.docx)"
        case .xlsx: return "Excel 表格 (.xlsx)"
        case .pptx: return "PPT 演示文稿 (.pptx)"
        case .pdf: return "PDF 文档 (.pdf)"
        case .txt: return "文本文档 (.txt)"
        case .md: return "Markdown (.md)"
        case .rtf: return "富文本 (.rtf)"
        case .csv: return "CSV 表格 (.csv)"
        }
    }
}
