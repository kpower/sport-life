import Foundation
import SwiftData

@Model
final class Workout {
    var externalID: String = UUID().uuidString
    /// Training day as `yyyy-MM-dd`; see `Day`.
    var day: String = ""
    var startedAt: Date?
    var finishedAt: Date?
    /// Optional name; never used to identify a program.
    var label: String?
    var note: String?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutEntry.workout)
    var entries: [WorkoutEntry]? = []

    init(externalID: String = UUID().uuidString, day: String) {
        self.externalID = externalID
        self.day = day
    }

    var orderedEntries: [WorkoutEntry] {
        (entries ?? []).sorted { $0.order < $1.order }
    }
}

/// One exercise within a workout.
@Model
final class WorkoutEntry {
    var order: Int = 0
    var workout: Workout?
    var exercise: Exercise?
    /// Attachment or program, e.g. "малый гриф", "Fat".
    var variant: String?
    var hintRaw: String?
    var note: String?
    /// Name it was logged under, when different from the exercise's current name.
    var originalName: String?
    /// Original Markdown line, for imported entries.
    var source: String?

    @Relationship(deleteRule: .cascade, inverse: \SetEntry.entry)
    var sets: [SetEntry]? = []

    init(order: Int) {
        self.order = order
    }

    var hint: Hint? {
        get { hintRaw.flatMap(Hint.init(rawValue:)) }
        set { hintRaw = newValue?.rawValue }
    }

    var orderedSets: [SetEntry] {
        (sets ?? []).sorted { $0.order < $1.order }
    }
}

@Model
final class SetEntry {
    var order: Int = 0
    var entry: WorkoutEntry?
    var weight: Double?
    var reps: Int?
    var duration: Double?
    var intensity: Double?
    var distance: Double?
    var speed: Double?
    /// Continues the previous set with a lighter weight.
    var isDrop: Bool = false
    var isDone: Bool = true

    init(order: Int, values: SetValues) {
        self.order = order
        self.values = values
    }

    var values: SetValues {
        get {
            SetValues(weight: weight, reps: reps, duration: duration, intensity: intensity,
                      distance: distance, speed: speed, drop: isDrop, done: isDone)
        }
        set {
            weight = newValue.weight
            reps = newValue.reps
            duration = newValue.duration
            intensity = newValue.intensity
            distance = newValue.distance
            speed = newValue.speed
            isDrop = newValue.drop
            isDone = newValue.done
        }
    }
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Exercise.self, Workout.self, WorkoutEntry.self, SetEntry.self,
    ]
}
