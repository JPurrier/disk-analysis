import Foundation
import CoreGraphics
import SwiftUI

public final class TreemapLayoutEngine: Sendable {
    public static let shared = TreemapLayoutEngine()

    public init() {}

    /// Computes squarified treemap rectangles for all descendant leaves of the root node
    public func computeLayout(
        for rootNode: FileNode,
        in bounds: CGRect,
        maxDepth: Int = 12,
        minPixelArea: CGFloat = 4.0
    ) -> [TreemapRect] {
        guard bounds.width > 2 && bounds.height > 2 else { return [] }
        var results: [TreemapRect] = []

        let initialSurface = CushionSurface(
            x1: Double(bounds.minX),
            x2: Double(bounds.maxX),
            y1: Double(bounds.minY),
            y2: Double(bounds.maxY),
            h: 0.5
        )

        layoutNode(
            node: rootNode,
            rect: bounds,
            depth: 0,
            parentSurface: initialSurface,
            maxDepth: maxDepth,
            minPixelArea: minPixelArea,
            results: &results
        )

        return results
    }

    private func layoutNode(
        node: FileNode,
        rect: CGRect,
        depth: Int,
        parentSurface: CushionSurface,
        maxDepth: Int,
        minPixelArea: CGFloat,
        results: inout [TreemapRect]
    ) {
        guard rect.width * rect.height >= minPixelArea else { return }

        // If this is a leaf node (file or package bundle) or reached maxDepth or has no children
        if !node.isDirectory || node.isPackage || node.children.isEmpty || depth >= maxDepth {
            results.append(TreemapRect(
                node: node,
                rect: rect,
                depth: depth,
                surface: parentSurface,
                color: node.kind.color
            ))
            return
        }

        // Subdivide rect among children with non-zero size
        let validChildren = node.children.filter { $0.effectiveSize > 0 }
        guard !validChildren.isEmpty else { return }

        let totalWeight = Double(validChildren.reduce(Int64(0)) { $0 + $1.effectiveSize })
        guard totalWeight > 0 else { return }

        let totalArea = Double(rect.width * rect.height)
        let normalizedChildren: [(node: FileNode, area: Double)] = validChildren.map {
            ($0, (Double($0.effectiveSize) / totalWeight) * totalArea)
        }

        squarify(
            items: normalizedChildren,
            in: rect,
            depth: depth + 1,
            parentSurface: parentSurface,
            maxDepth: maxDepth,
            minPixelArea: minPixelArea,
            results: &results
        )
    }

    private func squarify(
        items: [(node: FileNode, area: Double)],
        in container: CGRect,
        depth: Int,
        parentSurface: CushionSurface,
        maxDepth: Int,
        minPixelArea: CGFloat,
        results: inout [TreemapRect]
    ) {
        var remainingItems = items
        var currentContainer = container

        while !remainingItems.isEmpty {
            guard currentContainer.width > 1 && currentContainer.height > 1 else { break }

            let isWidthShorter = currentContainer.width < currentContainer.height
            let shorterSide = Double(isWidthShorter ? currentContainer.width : currentContainer.height)

            var currentRow: [(node: FileNode, area: Double)] = []
            var currentWorstRatio = Double.infinity

            while !remainingItems.isEmpty {
                let candidate = remainingItems[0]
                let testRow = currentRow + [candidate]
                let testWorstRatio = worstAspectRatio(row: testRow, sideLength: shorterSide)

                if testWorstRatio <= currentWorstRatio {
                    currentRow.append(candidate)
                    currentWorstRatio = testWorstRatio
                    remainingItems.removeFirst()
                } else {
                    // Ratio worsens; row is complete
                    break
                }
            }

            // Layout the completed row
            let rowArea = currentRow.reduce(0.0) { $0 + $1.area }
            let rowThickness = CGFloat(rowArea / shorterSide)

            var rowRect: CGRect
            if isWidthShorter {
                // Layout horizontally along width
                rowRect = CGRect(
                    x: currentContainer.minX,
                    y: currentContainer.minY,
                    width: currentContainer.width,
                    height: min(currentContainer.height, rowThickness)
                )
                currentContainer = CGRect(
                    x: currentContainer.minX,
                    y: currentContainer.minY + rowThickness,
                    width: currentContainer.width,
                    height: max(0, currentContainer.height - rowThickness)
                )
            } else {
                // Layout vertically along height
                rowRect = CGRect(
                    x: currentContainer.minX,
                    y: currentContainer.minY,
                    width: min(currentContainer.width, rowThickness),
                    height: currentContainer.height
                )
                currentContainer = CGRect(
                    x: currentContainer.minX + rowThickness,
                    y: currentContainer.minY,
                    width: max(0, currentContainer.width - rowThickness),
                    height: currentContainer.height
                )
            }

            // Position each item inside rowRect
            var itemOffset: CGFloat = 0
            for item in currentRow {
                let fraction = rowArea > 0 ? CGFloat(item.area / rowArea) : 0
                let itemRect: CGRect

                if isWidthShorter {
                    let itemWidth = rowRect.width * fraction
                    itemRect = CGRect(
                        x: rowRect.minX + itemOffset,
                        y: rowRect.minY,
                        width: itemWidth,
                        height: rowRect.height
                    )
                    itemOffset += itemWidth
                } else {
                    let itemHeight = rowRect.height * fraction
                    itemRect = CGRect(
                        x: rowRect.minX,
                        y: rowRect.minY + itemOffset,
                        width: rowRect.width,
                        height: itemHeight
                    )
                    itemOffset += itemHeight
                }

                // Compute child cushion surface parameters
                let childSurface = CushionSurface(
                    x1: Double(itemRect.minX),
                    x2: Double(itemRect.maxX),
                    y1: Double(itemRect.minY),
                    y2: Double(itemRect.maxY),
                    h: parentSurface.h * 0.75
                )

                layoutNode(
                    node: item.node,
                    rect: itemRect,
                    depth: depth,
                    parentSurface: childSurface,
                    maxDepth: maxDepth,
                    minPixelArea: minPixelArea,
                    results: &results
                )
            }
        }
    }

    private func worstAspectRatio(row: [(node: FileNode, area: Double)], sideLength: Double) -> Double {
        guard !row.isEmpty && sideLength > 0 else { return Double.infinity }
        let sumArea = row.reduce(0.0) { $0 + $1.area }
        guard sumArea > 0 else { return Double.infinity }

        let minArea = row.map { $0.area }.min() ?? sumArea
        let maxArea = row.map { $0.area }.max() ?? sumArea

        let sideSquared = sideLength * sideLength
        let sumAreaSquared = sumArea * sumArea

        let ratio1 = (sideSquared * maxArea) / sumAreaSquared
        let ratio2 = sumAreaSquared / (sideSquared * minArea)
        return max(ratio1, ratio2)
    }
}
