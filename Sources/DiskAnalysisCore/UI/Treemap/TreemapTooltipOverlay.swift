import SwiftUI

public struct TreemapTooltipOverlay: View {
    let node: FileNode
    let position: CGPoint

    public init(node: FileNode, position: CGPoint) {
        self.node = node
        self.position = position
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle()
                    .fill(node.kind.color)
                    .frame(width: 8, height: 8)
                Text(node.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Text(node.formattedSize)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.95))

            if node.isDirectory && !node.isPackage {
                Text("\(node.itemCount) items")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.75))
            } else {
                Text(node.kind.category.rawValue)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.75))
            }

            Text(node.path)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.82))
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .frame(maxWidth: 260)
        .position(x: min(max(140, position.x), 500), y: max(60, position.y - 45))
        .allowsHitTesting(false)
    }
}
