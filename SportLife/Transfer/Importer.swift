import Foundation
import SwiftData

struct ImportSummary: Equatable {
  var exercisesAdded = 0
  var exercisesUpdated = 0
  var workoutsAdded = 0
  var workoutsReplaced = 0
}

/// Imports a transfer file. Records are matched by id: existing exercises are updated,
/// existing workouts are replaced by the file's version. Re-importing a file is a no-op.
struct Importer {
  let context: ModelContext

  func importData(_ data: Data) throws -> ImportSummary {
    try importFile(TransferCoding.decoder().decode(TransferFile.self, from: data))
  }

  func importFile(_ file: TransferFile) throws -> ImportSummary {
    try validate(file)

    var exercises = Dictionary(
      try context.fetch(FetchDescriptor<Exercise>()).map { ($0.externalID, $0) },
      uniquingKeysWith: { first, _ in first })
    let workouts = Dictionary(
      try context.fetch(FetchDescriptor<Workout>()).map { ($0.externalID, $0) },
      uniquingKeysWith: { first, _ in first })

    var summary = ImportSummary()

    for record in file.exercises {
      let exercise: Exercise
      if let existing = exercises[record.id] {
        exercise = existing
        summary.exercisesUpdated += 1
      } else {
        exercise = Exercise(externalID: record.id, name: record.name, metrics: record.metrics)
        context.insert(exercise)
        exercises[record.id] = exercise
        summary.exercisesAdded += 1
      }
      exercise.name = record.name
      exercise.aliases = record.aliases
      exercise.metrics = record.metrics
      exercise.units = MetricUnits(record.units)
      exercise.lessIsBetter = record.lessIsBetter
      exercise.weightIsAdded = record.weightIsAdded
      exercise.handles = record.handles
      exercise.isArchived = record.archived
      exercise.note = record.note
    }

    for record in file.workouts {
      let workout: Workout
      if let existing = workouts[record.id] {
        workout = existing
        for entry in existing.entries ?? [] { context.delete(entry) }
        workout.entries = []
        summary.workoutsReplaced += 1
      } else {
        workout = Workout(externalID: record.id, day: record.date)
        context.insert(workout)
        summary.workoutsAdded += 1
      }
      workout.day = record.date
      workout.startedAt = record.startedAt
      workout.finishedAt = record.finishedAt
      workout.label = record.label
      workout.note = record.note

      for (index, entryRecord) in record.entries.enumerated() {
        let entry = WorkoutEntry(order: index)
        context.insert(entry)
        entry.workout = workout
        entry.exercise = exercises[entryRecord.exercise]
        entry.variant = entryRecord.variant
        entry.hint = entryRecord.hint
        entry.note = entryRecord.note
        entry.originalName = entryRecord.originalName
        entry.source = entryRecord.source
        for (setIndex, values) in entryRecord.sets.enumerated() {
          let set = SetEntry(order: setIndex, values: values)
          context.insert(set)
          set.entry = entry
        }
      }
    }

    try context.save()
    return summary
  }

  /// Checks the whole file before touching the store, so a bad file changes nothing.
  private func validate(_ file: TransferFile) throws {
    guard file.format == TransferFile.formatName else {
      throw TransferError.wrongFormat(file.format)
    }
    guard file.version <= TransferFile.currentVersion else {
      throw TransferError.unsupportedVersion(file.version)
    }
    var exerciseIDs = Set<String>()
    for record in file.exercises where !exerciseIDs.insert(record.id).inserted {
      throw TransferError.duplicateID(record.id)
    }
    let stored = Set(try context.fetch(FetchDescriptor<Exercise>()).map(\.externalID))
    var workoutIDs = Set<String>()
    for record in file.workouts {
      guard workoutIDs.insert(record.id).inserted else {
        throw TransferError.duplicateID(record.id)
      }
      guard Day.date(from: record.date) != nil else {
        throw TransferError.invalidDate(workout: record.id, date: record.date)
      }
      for entry in record.entries
      where !exerciseIDs.contains(entry.exercise) && !stored.contains(entry.exercise) {
        throw TransferError.unknownExercise(workout: record.id, exercise: entry.exercise)
      }
    }
  }
}
