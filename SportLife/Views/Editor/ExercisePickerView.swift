import SwiftData
import SwiftUI

/// Search over names and aliases, ranked by what usually follows the previous exercise,
/// usage and recency. Creates a new exercise when nothing fits.
struct ExercisePickerView: View {
  let workout: Workout
  let onPick: (Exercise) -> Void

  @Environment(\.dismiss) private var dismiss
  @Query private var exercises: [Exercise]
  @Query private var workouts: [Workout]
  @State private var query = ""
  @State private var stats = ExerciseSearch.Stats()
  @State private var isCreating = false

  var body: some View {
    NavigationStack {
      List {
        Section(query.isEmpty ? "Suggested" : "Matches") {
          ForEach(results) { exercise in
            Button {
              pick(exercise)
            } label: {
              ExercisePickerRow(exercise: exercise, lastDay: stats.lastDay[exercise.externalID])
            }
            .tint(.primary)
          }
        }
        Section {
          Button(query.isEmpty ? "New exercise…" : "Create “\(query)”…", systemImage: "plus") {
            isCreating = true
          }
        }
      }
      .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                  prompt: "Name or machine")
      .navigationTitle("Add exercise")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", role: .cancel) { dismiss() }
        }
      }
      .task { stats = ExerciseSearch.stats(from: workouts) }
      .sheet(isPresented: $isCreating) {
        ExerciseFormView(initialName: query) { exercise in pick(exercise) }
      }
    }
  }

  private var results: [Exercise] {
    let inWorkout = Set(workout.orderedEntries.compactMap { $0.exercise?.externalID })
    return ExerciseSearch.rank(exercises, query: query, stats: stats,
                               after: workout.orderedEntries.last?.exercise,
                               excluded: inWorkout)
  }

  private func pick(_ exercise: Exercise) {
    onPick(exercise)
    dismiss()
  }
}

private struct ExercisePickerRow: View {
  let exercise: Exercise
  let lastDay: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(exercise.name)
      if !exercise.aliases.isEmpty {
        Text(exercise.aliases.joined(separator: " · "))
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      if let lastDay, let date = Day.date(from: lastDay) {
        Text("Last: \(date.formatted(date: .abbreviated, time: .omitted))")
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
    }
  }
}

/// Minimal form for a new exercise; the full library settings come later.
struct ExerciseFormView: View {
  enum Kind: CaseIterable, Identifiable {
    case weightAndReps, bodyweight, repsOnly, cardio

    var id: Self { self }

    var title: LocalizedStringKey {
      switch self {
      case .weightAndReps: "Weight × reps"
      case .bodyweight: "Bodyweight (+ extra weight) × reps"
      case .repsOnly: "Reps only"
      case .cardio: "Cardio: minutes + intensity"
      }
    }
  }

  let onCreate: (Exercise) -> Void

  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @State private var name: String
  @State private var kind = Kind.weightAndReps
  @State private var lessIsBetter = false
  @State private var twoHandles = false

  init(initialName: String, onCreate: @escaping (Exercise) -> Void) {
    self.onCreate = onCreate
    _name = State(initialValue: initialName)
  }

  var body: some View {
    NavigationStack {
      Form {
        TextField("Name", text: $name)
        Picker("Type", selection: $kind) {
          ForEach(Kind.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.inline)
        Section {
          Toggle("Less is better", isOn: $lessIsBetter)
          if kind == .weightAndReps {
            Toggle("Two handles (weight per handle)", isOn: $twoHandles)
          }
        } footer: {
          Text("“Less is better” is for assisted machines, where lower weight means progress.")
        }
      }
      .navigationTitle("New exercise")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", role: .cancel) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Create", action: create)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
    }
  }

  private func create() {
    let exercise: Exercise
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    switch kind {
    case .weightAndReps, .bodyweight:
      exercise = Exercise(name: trimmed, metrics: [.weight, .reps])
      exercise.units = MetricUnits(["weight": "kg"])
      exercise.weightIsAdded = kind == .bodyweight
      exercise.handles = kind == .weightAndReps && twoHandles ? 2 : 1
    case .repsOnly:
      exercise = Exercise(name: trimmed, metrics: [.reps])
    case .cardio:
      exercise = Exercise(name: trimmed, metrics: [.duration, .intensity])
      exercise.units = MetricUnits(["duration": "min"])
    }
    exercise.lessIsBetter = lessIsBetter
    context.insert(exercise)
    dismiss()
    onCreate(exercise)
  }
}

struct ReorderEntriesView: View {
  let workout: Workout

  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        ForEach(workout.orderedEntries) { entry in
          Text(entry.exercise?.name ?? entry.originalName ?? "?")
        }
        .onMove { source, destination in
          WorkoutPlanner(context: context).moveEntries(in: workout, from: source, to: destination)
        }
      }
      .environment(\.editMode, .constant(.active))
      .navigationTitle("Reorder")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }
}
