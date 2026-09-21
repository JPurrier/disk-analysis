import Foundation
import CoreGraphics
import SwiftUI

public struct CushionSurface: Sendable {
    public var x1: Double
    public var x2: Double
    public var y1: Double
    public var y2: Double
    public var h: Double

    public init(x1: Double = 0, x2: Double = 0, y1: Double = 0, y2: Double = 0, h: Double = 0.5) {
        self.x1 = x1
        self.x2 = x2
        self.y1 = y1
        self.y2 = y2
        self.h = h
    }
}

public struct TreemapRect: Identifiable, @unchecked Sendable {
    public var id: UUID { node.id }
    public let node: FileNode
    public let rect: CGRect
    public let depth: Int
    public let surface: CushionSurface
    public let color: Color

    public init(node: FileNode, rect: CGRect, depth: Int, surface: CushionSurface, color: Color) {
        self.node = node
        self.rect = rect
        self.depth = depth
        self.surface = surface
        self.color = color
    }
}
