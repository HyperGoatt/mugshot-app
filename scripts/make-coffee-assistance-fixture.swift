// Creates an original, fictional label for local vision acceptance. No user media.
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count >= 2 else { fatalError("Pass a JPEG output path") }
let context = CGContext(data: nil, width: 900, height: 1000, bitsPerComponent: 8,
    bytesPerRow: 3600, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.setFillColor(CGColor(gray: 1, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: 900, height: 1000))
func draw(_ text: String, y: CGFloat, size: CGFloat, bold: Bool = false) {
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName((bold ? "Helvetica-Bold" : "Helvetica") as CFString, size, nil),
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    context.textPosition = CGPoint(x: 55, y: y)
    CTLineDraw(line, context)
}
let recipe = CommandLine.arguments.last == "recipe"
draw(recipe ? "FICTIONAL RECIPE" : "FICTIONAL COFFEE BAG", y: 885, size: 46, bold: true)
let lines = recipe
    ? ["Name: Vanilla iced latte", "Ingredient: 10 g vanilla syrup", "Ingredient: 150 ml milk", "Step: Stir syrup into coffee.", "Creator: Fixture Author"]
    : ["Roaster: Example Roasters", "Coffee: Dawn", "Origin: Colombia", "Process: Washed", "Roast date: 2026-10-28", "Tasting notes: Cocoa, cherry"]
for (index, line) in lines.enumerated() {
    draw(line, y: CGFloat(740 - index * 95), size: 34)
}
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, [kCGImageDestinationLossyCompressionQuality: 0.65] as CFDictionary)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not create fixture JPEG") }
print("Created fictional label fixture; no user media accessed.")
