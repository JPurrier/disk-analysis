import SwiftUI

struct FileInfoView: View {
    let node: FileNode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 24))
                    .foregroundColor(node.kind.color)

                VStack(alignment: .leading, spacing: 3) {
                    Text(node.name)
                        .font(.headline)
                        .lineLimit(2)
                        .textSelection(.enabled)
                    Text(nodeType)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 9) {
                GridRow {
                    Text("Name")
                        .foregroundColor(.secondary)
                    Text(node.name)
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Location")
                        .foregroundColor(.secondary)
                    Text(node.url.deletingLastPathComponent().path)
                        .textSelection(.enabled)
                        .lineLimit(2)
                }
                GridRow {
                    Text("Path")
                        .foregroundColor(.secondary)
                    Text(node.path)
                        .textSelection(.enabled)
                        .lineLimit(2)
                }
                GridRow {
                    Text("Size")
                        .foregroundColor(.secondary)
                    Text(node.formattedSize)
                }
                GridRow {
                    Text("Logical size")
                        .foregroundColor(.secondary)
                    Text(node.formattedLogicalSize)
                }
                GridRow {
                    Text("Physical size")
                        .foregroundColor(.secondary)
                    Text(node.formattedPhysicalSize)
                }
                if node.isDirectory {
                    GridRow {
                        Text("Items")
                            .foregroundColor(.secondary)
                        Text("\(node.itemCount)")
                    }
                }
                if let modifiedDate = node.modifiedDate {
                    GridRow {
                        Text("Modified")
                            .foregroundColor(.secondary)
                        Text(modifiedDate.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
            .font(.system(size: 12))
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 500)
    }

    private var nodeType: String {
        if node.isPackage {
            return "Package"
        }
        if node.isDirectory {
            return "Folder"
        }
        return node.fileExtension.isEmpty ? "File" : ".\(node.fileExtension) file"
    }
}
