import SwiftUI

@main
struct KoeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            StatusPanelView(
                appState: appDelegate.appState,
                onOpenDashboard: {
                    openWindow(id: "dashboard")
                },
                onStopRecording: {
                    appDelegate.pipeline?.requestStopRecording()
                },
                onCancel: {
                    appDelegate.pipeline?.cancelCurrentWork()
                }
            )
        } label: {
            Image(systemName: appDelegate.appState.menuBarIcon)
        }

        Window("Koe", id: "dashboard") {
            MainWindowView()
                .environment(appDelegate.appState)
                .environment(appDelegate.dataStore)
        }
        .defaultSize(width: 900, height: 600)
    }
}
