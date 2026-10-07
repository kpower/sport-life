import SwiftData
import SwiftUI

@main
struct SportLifeApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Schema(AppSchema.models),
                configurations: ModelConfiguration(cloudKitDatabase: .none))
        } catch {
            fatalError("Could not open the data store: \(error)")
        }
        #if DEBUG
        importFromEnvironment()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            HistoryView()
        }
        .modelContainer(container)
    }

    #if DEBUG
    /// Development shortcut: `SPORTLIFE_IMPORT=/path/to/file.json` imports at launch.
    private func importFromEnvironment() {
        guard let path = ProcessInfo.processInfo.environment["SPORTLIFE_IMPORT"] else { return }
        do {
            let data = try Data(contentsOf: URL(filePath: path))
            let summary = try Importer(context: container.mainContext).importData(data)
            print("SPORTLIFE_IMPORT: \(summary)")
        } catch {
            print("SPORTLIFE_IMPORT failed: \(error)")
        }
    }
    #endif
}
