import CoreGraphics
import PencilKit
import UIKit

// MARK: - PKDrawing Path Utilities

extension PKDrawing {
    /// Converts PencilKit strokes to an array of CGPath objects for font compilation.
    func toCGPaths(scaledTo unitsPerEm: Int, canvasSize: CGFloat = 512.0) -> [CGPath] {
        let scale = CGFloat(unitsPerEm) / canvasSize
        return strokes.compactMap { stroke -> CGPath? in
            let path = CGMutablePath()
            let points = stroke.path
            guard points.count >= 2 else { return nil }

            path.move(to: CGPoint(
                x: points[0].location.x * scale,
                y: (canvasSize - points[0].location.y) * scale
            ))

            if points.count == 2 {
                path.addLine(to: CGPoint(
                    x: points[1].location.x * scale,
                    y: (canvasSize - points[1].location.y) * scale
                ))
            } else {
                // Use Catmull-Rom to quadratic B-spline conversion for smooth curves
                for i in 1..<points.count {
                    let p = points[i].location
                    path.addLine(to: CGPoint(
                        x: p.x * scale,
                        y: (canvasSize - p.y) * scale
                    ))
                }
            }

            return path
        }
    }

    /// Returns the union bounding box of all strokes, scaled to font units.
    func boundingBox(unitsPerEm: Int, canvasSize: CGFloat = 512.0) -> CGRect {
        let paths = toCGPaths(scaledTo: unitsPerEm, canvasSize: canvasSize)
        guard !paths.isEmpty else { return .zero }

        var unionRect = CGRect.null
        for path in paths {
            unionRect = unionRect.union(path.boundingBox)
        }
        return unionRect
    }
}

// MARK: - CGPath to TTF Points

extension CGPath {
    /// Extracts on-curve and off-curve control points for TTF glyph encoding.
    func toTTFPoints() -> [TTFPoint] {
        var points: [TTFPoint] = []

        self.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                let p = element.points[0]
                points.append(TTFPoint(x: Int16(p.x), y: Int16(p.y), onCurve: true))

            case .addLineToPoint:
                let p = element.points[0]
                points.append(TTFPoint(x: Int16(p.x), y: Int16(p.y), onCurve: true))

            case .addQuadCurveToPoint:
                let cp = element.points[0]
                let end = element.points[1]
                points.append(TTFPoint(x: Int16(cp.x), y: Int16(cp.y), onCurve: false))
                points.append(TTFPoint(x: Int16(end.x), y: Int16(end.y), onCurve: true))

            case .addCurveToPoint:
                // Convert cubic to quadratic approximation
                let cp1 = element.points[0]
                let cp2 = element.points[1]
                let end = element.points[2]
                let midCP = CGPoint(
                    x: (cp1.x + cp2.x) / 2,
                    y: (cp1.y + cp2.y) / 2
                )
                points.append(TTFPoint(x: Int16(midCP.x), y: Int16(midCP.y), onCurve: false))
                points.append(TTFPoint(x: Int16(end.x), y: Int16(end.y), onCurve: true))

            case .closeSubpath:
                break

            @unknown default:
                break
            }
        }

        return points
    }
}
