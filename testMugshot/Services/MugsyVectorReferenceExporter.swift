import SwiftUI
import UIKit

/// Produces a review-only vector handoff from the same code-native geometry
/// used by `MugsyModelView`. Shipping image assets remain authoritative until
/// this reference is separately approved.
enum MugsyVectorReferenceExporter {
    static let canvasSize = CGSize(width: 500, height: 500)

    @MainActor
    static func pdfData() -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Mugsy code-native vector reference",
            kCGPDFContextAuthor as String: "Mugshot",
            kCGPDFContextCreator as String: "MugsyModelView / ImageRenderer",
            kCGPDFContextSubject as String:
                "Review-only vector reference. Existing production assets remain authoritative."
        ]
        let bounds = CGRect(origin: .zero, size: canvasSize)
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)
        let mugsy = MugsyModelView(
            configuration: MugsyModelConfiguration(),
            renderMode: .contours
        )
        .frame(width: canvasSize.width, height: canvasSize.height)
        let imageRenderer = ImageRenderer(content: mugsy)

        return pdfRenderer.pdfData { pdfContext in
            pdfContext.beginPage()
            imageRenderer.render { renderedSize, draw in
                let scale = min(
                    canvasSize.width / max(renderedSize.width, 1),
                    canvasSize.height / max(renderedSize.height, 1)
                )
                pdfContext.cgContext.saveGState()
                pdfContext.cgContext.scaleBy(x: scale, y: scale)
                draw(pdfContext.cgContext)
                pdfContext.cgContext.restoreGState()
            }
        }
    }

#if DEBUG
    /// Writes the review artifact only when explicitly requested at launch.
    /// This keeps shipping artwork authoritative and gives reviewers a
    /// deterministic way to reproduce the exact PDF covered by the unit test.
    @MainActor
    @discardableResult
    static func exportIfRequested() throws -> URL? {
        guard MugshotLaunchEnvironment.shouldExportMugsyVectorReference,
              let documentsURL = FileManager.default.urls(
                  for: .documentDirectory,
                  in: .userDomainMask
              ).first else {
            return nil
        }

        let outputURL = documentsURL
            .appendingPathComponent("Mugsy-code-native-reference.pdf")
        try pdfData().write(to: outputURL, options: .atomic)
        return outputURL
    }
#endif
}
