import AppKit
import SwiftUI

// Minimal cross-platform support needed to render the canonical app-owned
// Mugsy geometry from the command line without booting an iOS Simulator.
enum MugshotMotion {
    static func normalized(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }

    static func normalized(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

enum MugshotDrinkAppearance: String, CaseIterable, Identifiable {
    case coffee
    case matcha
    case tea
    case chai
    case bright

    var id: String { rawValue }

    var liquidColor: Color {
        switch self {
        case .coffee: Color(hex: "80563C")
        case .matcha: Color(hex: "87A967")
        case .tea: Color(hex: "C89554")
        case .chai: Color(hex: "B87957")
        case .bright: Color(hex: "D99A71")
        }
    }
}

extension Comparable {
    func mugshotClamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

extension Color {
    static let creamWhite = Color(hex: "FAF6F0")

    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue)
    }
}

@main
struct MugsyWaveFrameRenderer {
    @MainActor
    static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 2 else {
            fputs("usage: mugsy-wave-renderer <output-directory>\n", stderr)
            exit(2)
        }

        let output = URL(fileURLWithPath: arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let frameCount = 36
        for frameIndex in 0..<frameCount {
            let progress = Double(frameIndex) / Double(frameCount)
            let waveLift = CGFloat(sin(min(1, progress * 3.2) * .pi / 2))
            let waveSwing = CGFloat(sin(progress * .pi * 4.0) * 15.0) * waveLift
            let blink = exp(-pow((progress - 0.58) / 0.055, 2))
            let eyeOpenness = CGFloat(max(0.08, 1 - blink * 0.92))

            let mugsy = MugsyModelView(
                configuration: MugsySceneFamily.playfulWavingMugsy.configuration,
                presentation: MugsyModelPresentation(
                    waveLift: waveLift,
                    waveSwing: waveSwing,
                    limbRetraction: 0,
                    faceOpacity: 1,
                    eyeOpenness: eyeOpenness,
                    ceramicOpacity: 1
                )
            )
            .frame(width: 900, height: 900)

            let renderer = ImageRenderer(content: mugsy)
            renderer.proposedSize = ProposedViewSize(width: 900, height: 900)
            renderer.scale = 1
            renderer.isOpaque = false

            guard let image = renderer.cgImage else {
                throw RenderError.missingFrame(frameIndex)
            }

            let representation = NSBitmapImageRep(cgImage: image)
            guard let data = representation.representation(using: .png, properties: [:]) else {
                throw RenderError.encodingFailed(frameIndex)
            }

            let filename = String(format: "mugsy-wave-%03d.png", frameIndex)
            try data.write(to: output.appendingPathComponent(filename), options: .atomic)
        }

        print("Rendered \(frameCount) canonical Mugsy wave frames to \(output.path)")
    }
}

private enum RenderError: LocalizedError {
    case missingFrame(Int)
    case encodingFailed(Int)

    var errorDescription: String? {
        switch self {
        case .missingFrame(let index): "ImageRenderer did not produce frame \(index)."
        case .encodingFailed(let index): "PNG encoding failed for frame \(index)."
        }
    }
}
