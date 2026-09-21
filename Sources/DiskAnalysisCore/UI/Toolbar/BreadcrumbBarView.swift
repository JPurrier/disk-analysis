import SwiftUI

public struct BreadcrumbBarView: View {
    @Bindable var state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 4) {
            Button {
                state.resetDrillDown()
            } label: {
                Image(systemName: "house.fill")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Go to root volume")

            if let current = state.currentDrillDownNode {
                let crumbs = current.breadcrumbs
                ForEach(crumbs, id: \.id) { crumb in
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)

                    Button {
                        state.navigateToBreadcrumb(crumb)
                    } label: {
                        Text(crumb.name)
                            .font(.system(size: 11, weight: crumb === current ? .bold : .regular))
                            .foregroundColor(crumb === current ? .primary : .accentColor)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("No volume loaded")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .cornerRadius(6)
    }
}
