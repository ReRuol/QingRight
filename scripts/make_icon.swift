// 用 CoreGraphics 画 1024 图标：macOS 圆角方块 + 极简右键菜单 + 光标
import AppKit

let S: CGFloat = 1024
let out = CommandLine.arguments[1]
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let c = NSGraphicsContext.current!.cgContext

// 苹果图标网格：824 主体，四周留 100 边距
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
c.saveGState()
c.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.25).cgColor)
c.addPath(bodyPath); c.setFillColor(NSColor.white.cgColor); c.fillPath()
c.restoreGState()
c.saveGState()
c.addPath(bodyPath); c.clip()
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [NSColor(red: 0.20, green: 0.55, blue: 1.0, alpha: 1).cgColor,
                               NSColor(red: 0.36, green: 0.30, blue: 0.95, alpha: 1).cgColor] as CFArray,
                      locations: [0, 1])!
c.drawLinearGradient(grad, start: CGPoint(x: 100, y: 924), end: CGPoint(x: 924, y: 100), options: [])

// 右键菜单卡片
let card = CGRect(x: 300, y: 250, width: 440, height: 470)
c.saveGState()
c.setShadow(offset: CGSize(width: 0, height: -16), blur: 40, color: NSColor.black.withAlphaComponent(0.28).cgColor)
c.addPath(CGPath(roundedRect: card, cornerWidth: 64, cornerHeight: 64, transform: nil))
c.setFillColor(NSColor.white.cgColor); c.fillPath()
c.restoreGState()

// 三行菜单项，第一行高亮
let rowH: CGFloat = 112, inset: CGFloat = 36
for i in 0..<3 {
    let y = card.maxY - inset - rowH * CGFloat(i + 1)
    let row = CGRect(x: card.minX + inset, y: y + 12, width: card.width - inset * 2, height: rowH - 24)
    if i == 0 {
        c.addPath(CGPath(roundedRect: row, cornerWidth: 28, cornerHeight: 28, transform: nil))
        c.setFillColor(NSColor(red: 0.27, green: 0.45, blue: 1.0, alpha: 1).cgColor); c.fillPath()
    }
    let bar = CGRect(x: row.minX + 34, y: row.midY - 14, width: i == 1 ? 210 : 280, height: 28)
    c.addPath(CGPath(roundedRect: bar, cornerWidth: 14, cornerHeight: 14, transform: nil))
    c.setFillColor(i == 0 ? NSColor.white.cgColor : NSColor(white: 0.80, alpha: 1).cgColor); c.fillPath()
}

// 光标
let p = CGMutablePath()
let o = CGPoint(x: 600, y: 470)
p.move(to: o)
p.addLine(to: CGPoint(x: o.x, y: o.y - 300))
p.addLine(to: CGPoint(x: o.x + 70, y: o.y - 232))
p.addLine(to: CGPoint(x: o.x + 120, y: o.y - 335))
p.addLine(to: CGPoint(x: o.x + 168, y: o.y - 312))
p.addLine(to: CGPoint(x: o.x + 118, y: o.y - 212))
p.addLine(to: CGPoint(x: o.x + 212, y: o.y - 205))
p.closeSubpath()
c.saveGState()
c.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: NSColor.black.withAlphaComponent(0.35).cgColor)
c.addPath(p); c.setFillColor(NSColor(white: 0.08, alpha: 1).cgColor); c.fillPath()
c.restoreGState()
c.addPath(p); c.setStrokeColor(NSColor.white.cgColor); c.setLineWidth(22); c.setLineJoin(.round); c.strokePath()
c.addPath(p); c.setFillColor(NSColor(white: 0.08, alpha: 1).cgColor); c.fillPath()
c.restoreGState()

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
