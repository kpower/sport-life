import Foundation

/// The JSON import/export file. See docs/data-format.md.
struct TransferFile: Codable, Equatable {
  static let formatName = "sport-life"
  static let currentVersion = 1

  var format = TransferFile.formatName
  var version = TransferFile.currentVersion
  var exportedAt: Date?
  var exercises: [ExerciseRecord] = []
  var workouts: [WorkoutRecord] = []
}

struct ExerciseRecord: Codable, Equatable {
  var id: String
  var name: String
  var aliases: [String] = []
  var metrics: [Metric]
  var units: [String: String] = [:]
  var lessIsBetter = false
  var weightIsAdded = false
  var handles = 1
  var archived = false
  var note: String?
}

extension ExerciseRecord {
  private enum CodingKeys: String, CodingKey {
    case id, name, aliases, metrics, units, lessIsBetter, weightIsAdded, handles, archived, note
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    name = try c.decode(String.self, forKey: .name)
    aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
    metrics = try c.decode([Metric].self, forKey: .metrics)
    units = try c.decodeIfPresent([String: String].self, forKey: .units) ?? [:]
    lessIsBetter = try c.decodeIfPresent(Bool.self, forKey: .lessIsBetter) ?? false
    weightIsAdded = try c.decodeIfPresent(Bool.self, forKey: .weightIsAdded) ?? false
    handles = try c.decodeIfPresent(Int.self, forKey: .handles) ?? 1
    archived = try c.decodeIfPresent(Bool.self, forKey: .archived) ?? false
    note = try c.decodeIfPresent(String.self, forKey: .note)
  }
}

struct WorkoutRecord: Codable, Equatable {
  var id: String
  /// `yyyy-MM-dd`
  var date: String
  var startedAt: Date?
  var finishedAt: Date?
  var label: String?
  var note: String?
  var entries: [EntryRecord] = []
}

struct EntryRecord: Codable, Equatable {
  /// Exercise `id`.
  var exercise: String
  var variant: String?
  var hint: Hint?
  var note: String?
  var originalName: String?
  var source: String?
  var sets: [SetValues] = []
}

enum TransferCoding {
  static func decoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  static func encoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return encoder
  }
}

enum TransferError: LocalizedError, Equatable {
  case wrongFormat(String)
  case unsupportedVersion(Int)
  case duplicateID(String)
  case unknownExercise(workout: String, exercise: String)
  case invalidDate(workout: String, date: String)

  var errorDescription: String? {
    switch self {
    case .wrongFormat(let format):
      "Not a Sport Life file (format “\(format)”)."
    case .unsupportedVersion(let version):
      "File version \(version) is newer than this app supports."
    case .duplicateID(let id):
      "The file contains “\(id)” more than once."
    case .unknownExercise(let workout, let exercise):
      "Workout \(workout) refers to an unknown exercise “\(exercise)”."
    case .invalidDate(let workout, let date):
      "Workout \(workout) has an invalid date “\(date)”."
    }
  }
}
