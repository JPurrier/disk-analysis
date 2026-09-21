import Foundation
import CoreGraphics
import SwiftUI

public final class CushionShadingEngine: Sendable {
    public static let shared = CushionShadingEngine()

    public init() {}

    /// Renders a cushion-shaded tile onto a SwiftUI GraphicsContext
    public func drawTile(
        in context: inout GraphicsContext,
        rect: CGRect,
        baseColor: Color,
        isSelected: Bool,
        isHovered: Bool,
        isDimmed: Bool
    ) {
        guard rect.width >= 1 && rect.height >= 1 else { return }

        let path = Path(rect)

        // Dimmed state for filtered-out items
        let effectiveAlpha = isDimmed ? 0.22 : 1.0

        // 1. Fill base color
        context.fill(path, with: .color(baseColor.opacity(effectiveAlpha)))

        // 2. 3D Cushion Lighting overlay:
        // Top-left light source simulation with linear/radial gradient
        if rect.width > 4 && rect.height > 4 {
            let highlightGradient = Gradient(colors: [
                Color.white.opacity(isHovered ? 0.40 : 0.22),
                Color.white.opacity(0.06),
                Color.black.opacity(0.12),
                Color.black.opacity(0.35)
            ])

            context.fill(
                path,
                with: .linearGradient(
                    highlightGradient,
                    startPoint: CGPoint(x: rect.minX, y: rect.minY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                )
            )

            // Inner border for crisp cushion edge
            context.stroke(
                path,
                with: .color(Color.black.opacity(0.25)),
                lineWidth: 0.5
            )
        }

        // 3. Selection or Hover Accent
        if isSelected {
            // High-visibility bright selection border
            context.stroke(
                path,
                with: .color(Color.white),
                lineWidth: 2.5
            )
            context.stroke(
                path,
                with: .color(Color.accentColor),
                lineWidth: 1.2
            )
        } else if isHovered {
            // Subtle hover outline
            context.stroke(
                path,
                with: .color(Color.white.opacity(0.85)),
                lineWidth: 1.5
            )
        }
    }
}
