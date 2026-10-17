import Cocoa
import CryptoKit

// 手动检查更新：GitHub 最新 Release → 提示 → 下载 zip + .sig → Ed25519 验签 → 替换自身并重启。
// 公钥对应的私钥只在发布者钥匙串里（scripts/sign_update.swift），GitHub 被盗也推不了恶意包。
enum Updater {
    static let repo = "ReRuol/QingRight"
    static let publicKey = "2w0nE1TVgQmuaGO6GEQB92Kjm5SLvo++Cb4oKGhi7AE="

    private struct Release {
        let tag: String, body: String, assets: [String: URL]  // 文件名 → 下载地址
    }

    static var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static func check() {
        var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: req) { data, _, error in
            let release = data.flatMap(parse)
            DispatchQueue.main.async {
                guard let release else {
                    return Handler.alert("检查更新失败，请检查网络后重试。\(error.map { "\n\($0.localizedDescription)" } ?? "")")
                }
                prompt(release)
            }
        }.resume()
    }

    private static func parse(_ data: Data) -> Release? {
        guard let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = j["tag_name"] as? String else { return nil }
        var assets: [String: URL] = [:]
        for a in j["assets"] as? [[String: Any]] ?? [] {
            if let n = a["name"] as? String, let u = (a["browser_download_url"] as? String).flatMap(URL.init(string:)) { assets[n] = u }
        }
        return Release(tag: tag, body: j["body"] as? String ?? "", assets: assets)
    }

    private static func prompt(_ r: Release) {
        let latest = r.tag.hasPrefix("v") ? String(r.tag.dropFirst()) : r.tag
        guard isNewer(latest, than: current) else {
            return Handler.alert("已是最新版本（v\(current)）。")
        }
        guard let zipName = r.assets.keys.first(where: { $0.hasSuffix(".zip") }),
              let zip = r.assets[zipName], let sig = r.assets[zipName + ".sig"] else {
            return Handler.alert("新版本 v\(latest) 缺少签名文件，为安全起见不自动安装。")
        }
        let a = NSAlert()
        a.messageText = "发现新版本 v\(latest)"
        a.informativeText = "当前版本 v\(current)\n\n\(r.body)"
        a.addButton(withTitle: "立即更新")
        a.addButton(withTitle: "以后再说")
        NSApp.activate(ignoringOtherApps: true)
        if a.runModal() == .alertFirstButtonReturn { install(zip: zip, sig: sig) }
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    private static func install(zip: URL, sig: URL) {
        fetch(sig) { sigData in
            fetch(zip) { zipData in
                guard let sigRaw = Data(base64Encoded: String(decoding: sigData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)),
                      let key = try? Curve25519.Signing.PublicKey(rawRepresentation: Data(base64Encoded: publicKey)!),
                      key.isValidSignature(sigRaw, for: zipData) else {
                    return Handler.alert("更新包签名校验失败，已取消安装。")
                }
                do {
                    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("QingRightUpdate-\(UUID().uuidString)")
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    let file = dir.appendingPathComponent("update.zip")
                    try zipData.write(to: file)
                    try replaceAndRelaunch(zip: file, workDir: dir)
                } catch {
                    Handler.alert("安装更新失败：\(error.localizedDescription)")
                }
            }
        }
    }

    // 回调切回主线程；失败直接提示，不往下走
    private static func fetch(_ url: URL, _ done: @escaping (Data) -> Void) {
        URLSession.shared.dataTask(with: url) { data, resp, error in
            DispatchQueue.main.async {
                guard let data, (resp as? HTTPURLResponse)?.statusCode == 200 else {
                    return Handler.alert("下载更新失败：\(error?.localizedDescription ?? "服务器无响应")")
                }
                done(data)
            }
        }.resume()
    }

    // 运行中的 App 不能替换自己，交给一个脱离的 shell：等本进程退出 → 替换 → 登记扩展 → 重启
    private static func replaceAndRelaunch(zip: URL, workDir: URL) throws {
        let app = Bundle.main.bundlePath
        guard FileManager.default.isWritableFile(atPath: (app as NSString).deletingLastPathComponent) else {
            throw NSError(domain: "QingRight", code: 1, userInfo: [NSLocalizedDescriptionKey: "没有写入「应用程序」文件夹的权限"])
        }
        let q = { (s: String) in "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let script = """
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done
        ditto -x -k \(q(zip.path)) \(q(workDir.path)) || exit 1
        [ -d \(q(workDir.path))/QingRight.app ] || exit 1
        rm -rf \(q(app)) && mv \(q(workDir.path))/QingRight.app \(q(app))
        xattr -dr com.apple.quarantine \(q(app))
        pluginkit -a \(q(app))/Contents/PlugIns/QingRightFinder.appex
        pluginkit -e use -i \(ExtensionRepair.extID)
        open \(q(app))
        rm -rf \(q(workDir.path))
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", script]
        try p.run()
        NSApp.terminate(nil)
    }
}
