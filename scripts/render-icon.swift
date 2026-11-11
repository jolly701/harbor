import AppKit

let side = 1024
let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()

let background = NSBezierPath(
    roundedRect: NSRect(x: 0, y: 0, width: side, height: side),
    xRadius: 224,
    yRadius: 224
)
NSColor(srgbRed: 0x1F / 255, green: 0x6F / 255, blue: 0xEB / 255, alpha: 1).setFill()
background.fill()

NSColor.white.setStroke()
NSColor.white.setFill()
let stroke: CGFloat = 92
let bar = NSBezierPath(
    roundedRect: NSRect(x: 150, y: 190, width: stroke, height: 644),
    xRadius: stroke / 2,
    yRadius: stroke / 2
)
bar.fill()

let center = NSPoint(x: 640, y: 512)
let radius: CGFloat = 250
let arc = NSBezierPath()
arc.appendArc(
    withCenter: center,
    radius: radius,
    startAngle: 28,
    endAngle: 332,
    clockwise: false
)
arc.lineWidth = stroke
arc.lineCapStyle = .round
arc.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
else {
    fputs("failed to render icon\n", stderr)
    exit(1)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try png.write(to: output)
