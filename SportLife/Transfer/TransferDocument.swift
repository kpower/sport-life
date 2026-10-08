import SwiftUI
import UniformTypeIdentifiers

/// Wraps exported JSON for `fileExporter`.
struct TransferDocument: FileDocument {
  static let readableContentTypes: [UTType] = [.json]

  var data: Data

  init(data: Data) {
    self.data = data
  }

  init(configuration: ReadConfiguration) throws {
    data = configuration.file.regularFileContents ?? Data()
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}
