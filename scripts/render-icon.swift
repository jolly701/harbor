import AppKit
import ImageIO

func tintedWhite(_ sourceURL: URL) throws -> NSImage {
    let data = try Data(contentsOf: sourceURL)
    guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
          let source = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
        throw NSError(domain: "HarborIcon", code: 1)
    }

    let width = source.width
    let height = source.height
    var sourcePixels = [UInt8](repeating: 0, count: width * height * 4)
    let rendered = sourcePixels.withUnsafeMutableBytes { pixels -> Bool in
        guard let context = CGContext(
            data: pixels.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard rendered else { throw NSError(domain: "HarborIcon", code: 2) }

    var minX = width
    var minY = height
    var maxX = 0
    var maxY = 0
    for y in 0..<height {
        for x in 0..<width where sourcePixels[(y * width + x) * 4 + 3] > 5 {
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x + 1)
            maxY = max(maxY, y + 1)
        }
    }
    guard maxX > minX, maxY > minY else { throw NSError(domain: "HarborIcon", code: 3) }

    let cropWidth = maxX - minX
    let cropHeight = maxY - minY
    var maskPixels = [UInt8](repeating: 0, count: cropWidth * cropHeight * 4)
    for y in 0..<cropHeight {
        for x in 0..<cropWidth {
            let alpha = sourcePixels[((minY + y) * width + minX + x) * 4 + 3]
            let index = (y * cropWidth + x) * 4
            maskPixels[index] = alpha
            maskPixels[index + 1] = alpha
            maskPixels[index + 2] = alpha
            maskPixels[index + 3] = alpha
        }
    }

    let maskData = Data(maskPixels) as CFData
    guard let provider = CGDataProvider(data: maskData),
          let mask = CGImage(
            width: cropWidth,
            height: cropHeight,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: cropWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
          ) else {
        throw NSError(domain: "HarborIcon", code: 4)
    }
    return NSImage(cgImage: mask, size: NSSize(width: cropWidth, height: cropHeight))
}

func render(mark: NSImage, side: CGFloat, hasBackground: Bool, output: URL) throws {
    let image = NSImage(size: NSSize(width: side, height: side))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    if hasBackground {
        NSColor.black.setFill()
        NSBezierPath(
            roundedRect: NSRect(x: 0, y: 0, width: side, height: side),
            xRadius: side * 0.22,
            yRadius: side * 0.22
        ).fill()
    }

    let inset = side * (hasBackground ? 0.17 : 0.04)
    let available = side - inset * 2
    let scale = min(available / mark.size.width, available / mark.size.height)
    let size = NSSize(width: mark.size.width * scale, height: mark.size.height * scale)
    mark.draw(in: NSRect(
        x: (side - size.width) / 2,
        y: (side - size.height) / 2,
        width: size.width,
        height: size.height
    ))
    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "HarborIcon", code: 2)
    }
    try png.write(to: output)
}

guard CommandLine.arguments.count == 4,
      FileManager.default.fileExists(atPath: CommandLine.arguments[1]) else {
    fputs("usage: render-icon.swift SOURCE_PNG APP_ICON_PNG MENU_BAR_ICON_PNG\n", stderr)
    exit(1)
}

let markImage = try tintedWhite(URL(fileURLWithPath: CommandLine.arguments[1]))
try render(mark: markImage, side: 1024, hasBackground: true,
           output: URL(fileURLWithPath: CommandLine.arguments[2]))
try render(mark: markImage, side: 32, hasBackground: false,
           output: URL(fileURLWithPath: CommandLine.arguments[3]))
