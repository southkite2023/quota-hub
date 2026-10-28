import AppKit

// Finder uses points; render at 2x for Retina displays.
let size = NSSize(width: 720, height: 460)
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1440,
    pixelsHigh: 920, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
bitmap.size = size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(calibratedRed: 0.95, green: 0.97, blue: 1, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

func label(_ text: String, y: CGFloat, fontSize: CGFloat, color: NSColor) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    (text as NSString).draw(in: NSRect(x: 30, y: y, width: 660, height: 46),
        withAttributes: [.font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
                         .foregroundColor: color, .paragraphStyle: style])
}
label("安装星账 Astracct", y: 363, fontSize: 29, color: .labelColor)
label("将左侧应用拖到右侧 Applications 文件夹", y: 320, fontSize: 17, color: .darkGray)

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 320, y: 230))
arrow.line(to: NSPoint(x: 400, y: 230))
arrow.move(to: NSPoint(x: 382, y: 246))
arrow.line(to: NSPoint(x: 400, y: 230))
arrow.line(to: NSPoint(x: 382, y: 214))
arrow.lineWidth = 5
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
NSColor(calibratedRed: 0.26, green: 0.40, blue: 0.83, alpha: 1).setStroke()
arrow.stroke()
label("拖拽完成后，从“应用程序”打开星账", y: 80, fontSize: 16, color: .darkGray)
label("安装后，可在桌面右键“星账 Astracct”磁盘并选择“推出”", y: 43,
      fontSize: 13, color: .gray)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(
    to: URL(fileURLWithPath: CommandLine.arguments[1]))
