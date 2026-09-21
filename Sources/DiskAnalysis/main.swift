import SwiftUI
import DiskAnalysisCore

@main
struct DiskAnalysisApp: App {
    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .frame(minWidth: 950, idealWidth: 1200, minHeight: 650, idealHeight: 800)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Disk") {
                Button("Start Scan") {
                    AppState.shared.startScan()
                }
                .keyboardShortcut("s", modifiers: [.command])

                Button("Cancel Scan") {
                    AppState.shared.cancelScan()
                }
                .keyboardShortcut(".", modifiers: [.command])

                Divider()

                Button("Drill Down") {
                    if let selected = AppState.shared.selectedNode, selected.isDirectory && !selected.isPackage {
                        AppState.shared.drillDown(to: selected)
                    }
                }
                .keyboardShortcut(.downArrow, modifiers: [.command])

                Button("Go to Root") {
                    AppState.shared.resetDrillDown()
                }
                .keyboardShortcut(.upArrow, modifiers: [.command])
            }
        }
    }
}
