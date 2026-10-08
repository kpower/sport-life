import SwiftData
import SwiftUI

@main
struct SportLifeApp: App {
  let container: ModelContainer

  init() {
    do {
      container = try ModelContainer(for: Schema(AppSchema.models), configurations: Self.storeConfiguration)
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

  private static var storeConfiguration: ModelConfiguration {
    #if DEBUG
    // Hosting unit tests: they bring their own stores, and CI builds are unsigned, so
    // CloudKit would crash at launch without the iCloud entitlement.
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
      return ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    }
    #endif
    return ModelConfiguration(cloudKitDatabase: .private("iCloud.com.PrankMind.SportLife"))
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
