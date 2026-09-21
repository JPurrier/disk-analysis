import SwiftUI

public struct FilterSearchBarView: View {
    @Bindable var state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Instant Search Box
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                TextField("Filter by name or extension...", text: $state.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                if !state.searchQuery.isEmpty {
                    Button {
                        state.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .frame(width: 190)

            // Min-Size Threshold Menu
            Picker("Size", selection: $state.minSizeThreshold) {
                ForEach(SizeFilterThreshold.allCases) { threshold in
                    Text(threshold.title).tag(threshold)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 110)

            // Package Bundles Toggle
            Toggle(isOn: $state.treatPackagesAsFiles) {
                Text("Apps as Files")
                    .font(.system(size: 11))
            }
            .toggleStyle(.checkbox)
            .help("Treat macOS Application (.app) and Photo Library bundles as single atomic items")

            // Toggle Inspector
            Button {
                state.isInspectorVisible.toggle()
            } label: {
                Image(systemName: "sidebar.trailing")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help("Toggle Smart Report")
        }
    }
}
