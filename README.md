<img src="docs/icon.png" width="128" alt="轻右键图标">

# 轻右键 QingRight

给 macOS 小白用的访达右键增强工具。极致轻量：安装包约 300 KB（Intel + Apple 芯片双架构），零第三方依赖。

## 功能（v0.1.1）
- 新建文件：txt / md / docx / xlsx（docx、xlsx 为合法空白文档）
- 复制路径（多选时一行一个）
- 在终端中打开
- 常用目录：一键打开，菜单栏图标里增删
- 复制到 / 移动到 常用目录（重名自动编号，不覆盖）

## 下载
- 所有版本：<https://github.com/ReRuol/QingRight/releases>
- v0.1.1 直链：<https://github.com/ReRuol/QingRight/releases/download/v0.1.1/QingRight-0.1.1.zip>（SHA-256 `30732dc730bc502aacb48f082a3326e44d4ebe226d680a5246e03424ea6b8fc1`）

⚠️ 当前为**预览版，未经苹果公证**。首次打开需要：
1. 解压后把 `QingRight.app` 拖进「应用程序」
2. 终端执行 `xattr -dr com.apple.quarantine /Applications/QingRight.app`
3. 打开轻右键，在「系统设置 → 通用 → 登录项与扩展 → 访达」勾选「轻右键」
4. 若弹出「想访问其他 App 的数据」，点「允许」

## 架构
```
访达 ──menu(for:)──▶ 扩展（沙盒，只拼菜单，配置走内存缓存）
                        │ 复制路径：扩展内直接完成
                        │ 其他：写 App Group/requests/<时间戳>.json + Darwin 通知
                        ▼
                   主 App（不沙盒，菜单栏常驻）执行文件操作
                   主 App 未运行时由 qingright:// 拉起并补执行
```

## 加一个新功能
1. `Shared/Shared.swift`：`Action` 里加一个 case
2. `Extension/FinderSync.swift`：`menu(for:)` 里加菜单项，动作函数里 `send(Request(...))`
3. `App/main.swift`：`Handler.perform` 里加对应分支

新建文件类型：往 `Templates/` 放 `blank.<扩展名>`，再在 `NewFileKind` 加一项。

## 构建
需要 Xcode 16+、[XcodeGen](https://github.com/yonaskolb/XcodeGen)。
```sh
xcodegen generate
xcodebuild -scheme QingRight -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- build
```
Fork 后请把 `project.yml` 和 `Shared/Shared.swift` 里的 Team ID `NNJ8PRGN55` 换成你自己的。

## License
MIT
