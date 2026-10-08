import SwiftData
import SwiftUI

struct WorkoutDetailView: View {
  let workout: Workout
  let onRepeat: () -> Void

  var body: some View {
    List {
      if workout.label != nil || workout.note != nil || workout.startedAt != nil {
        Section {
          if let label = workout.label {
            LabeledContent("Label", value: label)
          }
          if let startedAt = workout.startedAt {
            LabeledContent("Time", value: timeRange(from: startedAt))
          }
          if let note = workout.note {
            Text(note)
              .foregroundStyle(.secondary)
          }
        }
      }
      Section {
        ForEach(workout.orderedEntries) { entry in
          EntryRow(entry: entry)
        }
      }
      Section {
        Button("Repeat this workout", systemImage: "arrow.clockwise", action: onRepeat)
      } footer: {
        Text("Starts a new workout with these exercises, each pre-filled from the last time you did it.")
      }
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      NavigationLink("Edit", value: Route.editor(workout))
    }
  }

  private var title: String {
    Day.date(from: workout.day)?.formatted(date: .abbreviated, time: .omitted) ?? workout.day
  }

  private func timeRange(from start: Date) -> String {
    guard let end = workout.finishedAt else { return start.formatted(date: .omitted, time: .shortened) }
    return (start..<max(start, end)).formatted(.interval.hour().minute())
  }
}

struct EntryRow: View {
  let entry: WorkoutEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(entry.exercise?.name ?? entry.originalName ?? "Unknown exercise")
          .font(.headline)
        if let variant = entry.variant {
          Text(variant)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(.quaternary, in: .capsule)
        }
        Spacer()
        if let hint = entry.hint {
          Image(systemName: hint == .up ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
            .foregroundStyle(hint == .up ? .green : .orange)
            .accessibilityLabel(hint == .up ? "Try harder next time" : "Go lighter next time")
        }
      }
      if let originalName = entry.originalName, originalName != entry.exercise?.name {
        Text("logged as \(originalName)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      let lines = SetSummary(exercise: entry.exercise).lines(for: entry.orderedSets.map(\.values))
      ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
        Text(line)
          .monospacedDigit()
      }
      if let note = entry.note {
        Text(note)
          .font(.caption)
          .italic()
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 2)
  }
}
