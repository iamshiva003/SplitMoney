import Cocoa

let config = NSImage.SymbolConfiguration(pointSize: 600, weight: .bold)
guard let symbolImage = NSImage(systemSymbolName: "dollarsign.arrow.circlepath", accessibilityDescription: nil)?.withSymbolConfiguration(config) else {
    print("Failed to load symbol")
    exit(1)
}

let size = NSSize(width: 1024, height: 1024)
let finalImage = NSImage(size: size)

finalImage.lockFocus()

// Draw white background
NSColor.white.setFill()
NSRect(origin: .zero, size: size).fill()

// Tint symbol to blue
let blueColor = NSColor.systemBlue
blueColor.set()

let symbolRect = NSRect(
    x: (size.width - symbolImage.size.width) / 2,
    y: (size.height - symbolImage.size.height) / 2,
    width: symbolImage.size.width,
    height: symbolImage.size.height
)

if let cgImage = symbolImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
    let context = NSGraphicsContext.current!.cgContext
    context.saveGState()
    context.clip(to: symbolRect, mask: cgImage)
    context.setFillColor(blueColor.cgColor)
    context.fill(symbolRect)
    context.restoreGState()
}

finalImage.unlockFocus()

guard let tiffData = finalImage.tiffRepresentation,
      let bitmapRep = NSBitmapImageRep(data: tiffData),
      let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    print("Failed to create PNG")
    exit(1)
}

let outputPath = "/Users/shivakumarpatil/X-code projects/SplitMoney/SplitMoney/Assets.xcassets/AppIcon.appiconset/app_icon.png"
do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("Successfully saved icon to \(outputPath)")
} catch {
    print("Error saving: \(error)")
    exit(1)
}
