import SwiftUI

@main
struct GolfYardageCheatsheetApp: App {
    @UIApplicationDelegateAdaptor(CaddieCatAppDelegate.self) private var appDelegate

    private let repository: GolfBagRepository

    init() {
        let storeURL = (try? FileGolfBagStore.defaultStoreURL()) ??
            FileManager.default.temporaryDirectory.appendingPathComponent("golf-bag-data.json")

        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-data") {
            try? FileManager.default.removeItem(at: storeURL)
        }

        repository = GolfBagRepository(store: FileGolfBagStore(fileURL: storeURL))
    }

    var body: some Scene {
        WindowGroup {
            RootView(repository: repository)
        }
    }
}
