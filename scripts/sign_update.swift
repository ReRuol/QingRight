// 发布签名（Ed25519，系统自带 CryptoKit）
//   swift scripts/sign_update.swift keygen        生成密钥，私钥存进登录钥匙串，打印公钥
//   swift scripts/sign_update.swift sign <文件>   用钥匙串里的私钥签名，输出 base64 签名
import CryptoKit
import Foundation

let service = "QingRight Update Signing Key"

func sh(_ args: [String], input: String? = nil) -> (Int32, String) {
    let p = Process(), out = Pipe()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    p.arguments = args
    p.standardOutput = out
    try! p.run(); p.waitUntilExit()
    return (p.terminationStatus, String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
}

let args = CommandLine.arguments
switch args.count > 1 ? args[1] : "" {
case "keygen":
    if sh(["find-generic-password", "-s", service]).0 == 0 { print("钥匙串里已有密钥，拒绝覆盖"); exit(1) }
    let key = Curve25519.Signing.PrivateKey()
    let ok = sh(["add-generic-password", "-s", service, "-a", "QingRight", "-w", key.rawRepresentation.base64EncodedString()]).0
    guard ok == 0 else { print("写入钥匙串失败"); exit(1) }
    print(key.publicKey.rawRepresentation.base64EncodedString())
case "sign":
    let (st, b64) = sh(["find-generic-password", "-s", service, "-w"])
    guard st == 0, let raw = Data(base64Encoded: b64) else { print("钥匙串里没有签名私钥"); exit(1) }
    let key = try! Curve25519.Signing.PrivateKey(rawRepresentation: raw)
    let data = try! Data(contentsOf: URL(fileURLWithPath: args[2]))
    print(try! key.signature(for: data).base64EncodedString())
default:
    print("用法：keygen | sign <文件>"); exit(2)
}
