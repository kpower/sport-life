import Foundation
import SwiftData

/// Exports everything in the store as a transfer file.
struct Exporter {
    let context: ModelContext

    func makeFile(exportedAt: Date = .now) throws -> TransferFile {
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
            .sorted { $0.name.localizedLowercase < $1.name.localizedLowercase }
        let workouts = try context.fetch(FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.day), SortDescriptor(\.externalID)]))

        return TransferFile(
            exportedAt: exportedAt,
            exercises: exercises.map { exercise in
                ExerciseRecord(
                    id: exercise.externalID,
                    name: exercise.name,
                    aliases: exercise.aliases,
                    metrics: exercise.metrics,
                    units: exercise.units.dictionary,
                    lessIsBetter: exercise.lessIsBetter,
                    weightIsAdded: exercise.weightIsAdded,
                    handles: exercise.handles,
                    archived: exercise.isArchived,
                    note: exercise.note)
            },
            workouts: workouts.map { workout in
                WorkoutRecord(
                    id: workout.externalID,
                    date: workout.day,
                    startedAt: workout.startedAt,
                    finishedAt: workout.finishedAt,
                    label: workout.label,
                    note: workout.note,
                    entries: workout.orderedEntries.compactMap { entry in
                        // An entry whose exercise was deleted has nothing to point at.
                        guard let exercise = entry.exercise else { return nil }
                        return EntryRecord(
                            exercise: exercise.externalID,
                            variant: entry.variant,
                            hint: entry.hint,
                            note: entry.note,
                            originalName: entry.originalName,
                            source: entry.source,
                            sets: entry.orderedSets.map(\.values))
                    })
            })
    }

    func exportData(exportedAt: Date = .now) throws -> Data {
        try TransferCoding.encoder().encode(makeFile(exportedAt: exportedAt))
    }

    static func defaultFilename(for date: Date = .now) -> String {
        "sport-life-\(Day.key(for: date)).json"
    }
}
