import Foundation
import SwiftData
import Testing
@testable import SportLife

struct TransferTests {
  @Test func roundTripKeepsEverything() throws {
    let context = try Fixture.makeContext()
    let original = try Fixture.file()

    let summary = try Importer(context: context).importFile(original)
    #expect(summary == ImportSummary(exercisesAdded: 7, workoutsAdded: 4))

    let data = try Exporter(context: context).exportData()
    let exported = try TransferCoding.decoder().decode(TransferFile.self, from: data)
    #expect(exported.normalized() == original.normalized())
  }

  @Test func reimportChangesNothing() throws {
    let context = try Fixture.makeContext()
    let importer = Importer(context: context)
    _ = try importer.importFile(Fixture.file())

    let summary = try importer.importFile(Fixture.file())
    #expect(summary == ImportSummary(exercisesUpdated: 7, workoutsReplaced: 4))
    #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 4)
    #expect(try context.fetchCount(FetchDescriptor<WorkoutEntry>()) == 8)
    #expect(try context.fetchCount(FetchDescriptor<SetEntry>()) == 14)
    #expect(try Exporter(context: context).makeFile().normalized() == Fixture.file().normalized())
  }

  @Test func reimportReplacesChangedWorkout() throws {
    let context = try Fixture.makeContext()
    let importer = Importer(context: context)
    _ = try importer.importFile(Fixture.file())

    var changed = try Fixture.file()
    let index = try #require(changed.workouts.firstIndex { $0.id == "w-2026-10-06" })
    changed.workouts[index].entries = [
      EntryRecord(exercise: "chin-assist", sets: [SetValues(weight: 32, reps: 12)]),
    ]
    changed.workouts[index].label = "Experiment"
    _ = try importer.importFile(changed)

    let exported = try Exporter(context: context).makeFile()
    #expect(exported.normalized() == changed.normalized())
    #expect(try context.fetchCount(FetchDescriptor<SetEntry>()) == 14 - 6 + 1)
  }

  @Test func importAddsToExistingData() throws {
    let context = try Fixture.makeContext()
    let importer = Importer(context: context)
    _ = try importer.importFile(Fixture.file())

    // A later file may refer to exercises that are only in the store.
    let later = TransferFile(workouts: [
      WorkoutRecord(id: "new", date: "2026-10-08", entries: [
        EntryRecord(exercise: "lat-pulldown", sets: [SetValues(weight: 32, reps: 12)]),
      ]),
    ])
    let summary = try importer.importFile(later)
    #expect(summary == ImportSummary(workoutsAdded: 1))
    #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 5)
  }

  @Test func rejectsBadFilesWithoutChanges() throws {
    let context = try Fixture.makeContext()
    let importer = Importer(context: context)

    var wrongFormat = try Fixture.file()
    wrongFormat.format = "something-else"
    #expect(throws: TransferError.wrongFormat("something-else")) {
      try importer.importFile(wrongFormat)
    }

    var newer = try Fixture.file()
    newer.version = 2
    #expect(throws: TransferError.unsupportedVersion(2)) { try importer.importFile(newer) }

    var unknown = try Fixture.file()
    unknown.workouts[0].entries[0].exercise = "nope"
    #expect(throws: TransferError.unknownExercise(workout: "w-2023-02-18", exercise: "nope")) {
      try importer.importFile(unknown)
    }

    var duplicate = try Fixture.file()
    duplicate.workouts.append(duplicate.workouts[0])
    #expect(throws: TransferError.duplicateID("w-2023-02-18")) {
      try importer.importFile(duplicate)
    }

    var badDate = try Fixture.file()
    badDate.workouts[0].date = "2026-02-30"
    #expect(throws: TransferError.invalidDate(workout: "w-2023-02-18", date: "2026-02-30")) {
      try importer.importFile(badDate)
    }

    #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 0)
  }

  @Test func exportOmitsDefaultSetFlags() throws {
    let data = try TransferCoding.encoder().encode([
      SetValues(weight: 27.3, reps: 12),
      SetValues(weight: 18, reps: 6, drop: true, done: false),
    ])
    let text = String(decoding: data, as: UTF8.self)
    #expect(text.components(separatedBy: "\"drop\"").count == 2)
    #expect(text.components(separatedBy: "\"done\"").count == 2)
    #expect(text.contains("27.3"))
  }

  /// The real converted log, when present locally (data/ is never committed).
  nonisolated static let realDataURL = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "data/import.json")

  @Test(.enabled(if: FileManager.default.fileExists(atPath: realDataURL.path())))
  func realDataRoundTrip() throws {
    let context = try Fixture.makeContext()
    let data = try Data(contentsOf: Self.realDataURL)
    let original = try TransferCoding.decoder().decode(TransferFile.self, from: data)

    _ = try Importer(context: context).importData(data)
    let exported = try Exporter(context: context).makeFile()
    #expect(exported.normalized() == original.normalized())
    #expect(exported.workouts.count == original.workouts.count)
  }
}
