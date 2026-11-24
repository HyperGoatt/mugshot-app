import SwiftUI

/// Accessories are separate layers on the same 500-unit rig. No body, handle,
/// glasses, cheek, or foot geometry is redefined here.
struct MugsyExpandedAccessoryView: View {
    let prop: MugsyProp
    let lineWidth: CGFloat

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 500, y: size.height / 500)
            let ink = MugsyStyleTokens.ink
            let paper = MugsyStyleTokens.ceramicHighlight
            let mint = MugsyStyleTokens.mintAccent
            let stroke = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)

            func polygon(_ points: [CGPoint], fill: Color) {
                var path = Path()
                path.addLines(points)
                path.closeSubpath()
                context.fill(path, with: .color(fill))
                context.stroke(path, with: .color(ink), style: stroke)
            }

            func rectangle(_ rect: CGRect, fill: Color, radius: CGFloat = 4) {
                let path = Path(roundedRect: rect, cornerRadius: radius)
                context.fill(path, with: .color(fill))
                context.stroke(path, with: .color(ink), style: stroke)
            }

            func ellipse(_ rect: CGRect, fill: Color) {
                let path = Path(ellipseIn: rect)
                context.fill(path, with: .color(fill))
                context.stroke(path, with: .color(ink), style: stroke)
            }

            func line(_ points: [CGPoint]) {
                var path = Path()
                path.addLines(points)
                context.stroke(path, with: .color(ink), style: stroke)
            }

            switch prop {
            case .mapAndCompass:
                polygon([.init(x: 121, y: 270), .init(x: 158, y: 260), .init(x: 198, y: 270), .init(x: 238, y: 260), .init(x: 238, y: 326), .init(x: 198, y: 336), .init(x: 158, y: 326), .init(x: 121, y: 336)], fill: mint)
                line([.init(x: 158, y: 260), .init(x: 158, y: 326)])
                line([.init(x: 198, y: 270), .init(x: 198, y: 336)])
                line([.init(x: 133, y: 300), .init(x: 151, y: 285), .init(x: 177, y: 310), .init(x: 219, y: 286)])
                ellipse(.init(x: 243, y: 276, width: 35, height: 35), fill: paper)
                polygon([.init(x: 260, y: 281), .init(x: 254, y: 299), .init(x: 267, y: 299)], fill: mint)
            case .coffeeBeans:
                polygon([.init(x: 146, y: 263), .init(x: 212, y: 263), .init(x: 217, y: 336), .init(x: 141, y: 336)], fill: paper)
                rectangle(.init(x: 146, y: 263, width: 66, height: 13), fill: mint, radius: 2)
                ellipse(.init(x: 165, y: 288, width: 28, height: 34), fill: mint)
                line([.init(x: 181, y: 291), .init(x: 174, y: 307), .init(x: 181, y: 319)])
            case .matchaKit:
                var bowl = Path()
                bowl.move(to: .init(x: 123, y: 288))
                bowl.addQuadCurve(to: .init(x: 204, y: 288), control: .init(x: 164, y: 370))
                bowl.closeSubpath()
                context.fill(bowl, with: .color(paper))
                context.stroke(bowl, with: .color(ink), style: stroke)
                ellipse(.init(x: 123, y: 278, width: 81, height: 20), fill: mint)
                rectangle(.init(x: 238, y: 260, width: 10, height: 35), fill: paper)
                for offset in stride(from: -10.0, through: 10.0, by: 5) {
                    line([.init(x: 243, y: 291), .init(x: 243 + offset, y: 319)])
                }
            case .pourOverKit:
                polygon([.init(x: 142, y: 287), .init(x: 200, y: 287), .init(x: 211, y: 337), .init(x: 131, y: 337)], fill: paper)
                rectangle(.init(x: 134, y: 316, width: 74, height: 15), fill: mint)
                polygon([.init(x: 128, y: 258), .init(x: 214, y: 258), .init(x: 190, y: 286), .init(x: 150, y: 286)], fill: paper)
                line([.init(x: 148, y: 264), .init(x: 159, y: 282)])
                line([.init(x: 171, y: 263), .init(x: 171, y: 283)])
                line([.init(x: 193, y: 264), .init(x: 183, y: 282)])
                ellipse(.init(x: 229, y: 282, width: 42, height: 36), fill: paper)
                line([.init(x: 230, y: 294), .init(x: 218, y: 287), .init(x: 215, y: 270), .init(x: 207, y: 269)])
                line([.init(x: 265, y: 287), .init(x: 280, y: 285), .init(x: 280, y: 308), .init(x: 269, y: 310)])
            case .takeawayCup:
                polygon([.init(x: 147, y: 269), .init(x: 212, y: 269), .init(x: 203, y: 337), .init(x: 156, y: 337)], fill: paper)
                rectangle(.init(x: 143, y: 259, width: 73, height: 12), fill: ink)
                rectangle(.init(x: 153, y: 289, width: 54, height: 24), fill: mint, radius: 2)
            case .tastingSpoon:
                ellipse(.init(x: 234, y: 260, width: 22, height: 31), fill: paper)
                line([.init(x: 245, y: 289), .init(x: 242, y: 324)])
            default:
                break
            }
        }
        .frame(width: 500, height: 500)
        .accessibilityHidden(true)
    }
}
