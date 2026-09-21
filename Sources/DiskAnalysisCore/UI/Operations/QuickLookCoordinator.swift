import AppKit
import QuickLookUI

@MainActor
public final class QuickLookCoordinator: NSObject, @preconcurrency QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    public static let shared = QuickLookCoordinator()
    public var previewURL: URL?

    public func togglePreview(for url: URL) {
        guard let panel = QLPreviewPanel.shared() else { return }

        if panel.isVisible && previewURL == url {
            panel.orderOut(nil)
            previewURL = nil
        } else {
            previewURL = url
            panel.dataSource = self
            panel.delegate = self
            panel.reloadData()
            panel.makeKeyAndOrderFront(nil)
        }
    }

    public func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURL != nil ? 1 : 0
    }

    public func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        return (previewURL as? NSURL) ?? NSURL()
    }
}
