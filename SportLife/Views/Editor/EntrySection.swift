import SwiftData
import SwiftUI

/// One exercise of a workout: header, sets (with an inline editor) and hint for next time.
struct EntrySection: View {
  let entry: WorkoutEntry
  @Binding var selectedSet: SetEntry?
  let onFail: (SetEntry) -> Void
  let onRemove: () -> Void
  let onDeleteSet: (SetEntry) -> Void

  @Environment(\.modelContext) private var context
  @State private var editingText: TextPrompt?

  private var planner: WorkoutPlanner { WorkoutPlanner(context: context) }
  private var isLive: Bool { entry.workout?.isLive ?? false }

  var body: some View {
    Section {
      header
        .swipeActions(edge: .trailing) {
          Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
        }
      ForEach(Array(numberedSets.enumerated()), id: \.element.set.id) { _, item in
        SetRow(set: item.set, label: item.label, summary: summary, isLive: isLive,
               isSelected: selectedSet == item.set) {
          withAnimation(.snappy) {
            selectedSet = selectedSet == item.set ? nil : item.set
          }
        } onToggleDone: {
          item.set.isDone.toggle()
          if item.set.isDone, selectedSet == item.set { selectedSet = nil }
        }
        .swipeActions(edge: .trailing) {
          Button("Delete", systemImage: "trash", role: .destructive) { onDeleteSet(item.set) }
        }
        if selectedSet == item.set, let exercise = entry.exercise {
          SetEditor(set: item.set, exercise: exercise,
                    onFail: { onFail(item.set) }, onDelete: { onDeleteSet(item.set) })
        }
      }
      footer
    }
    .alert(editingText?.title ?? "", isPresented: Binding(
      get: { editingText != nil }, set: { if !$0 { editingText = nil } }
    )) {
      TextField(editingText?.title ?? "", text: Binding(
        get: { editingText?.text ?? "" }, set: { editingText?.text = $0 }))
      Button("Save") { editingText?.save() }
      Button("Cancel", role: .cancel) {}
    }
  }

  private var summary: SetSummary { SetSummary(exercise: entry.exercise) }

  /// Sets numbered 1, 2, 3…; drop parts get "↳" instead of a number.
  private var numberedSets: [(set: SetEntry, label: String)] {
    var number = 0
    return entry.orderedSets.map { set in
      if set.isDrop { return (set, "↳") }
      number += 1
      return (set, "\(number)")
    }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(entry.exercise?.name ?? entry.originalName ?? String(localized: "Unknown exercise"))
            .font(.headline)
          if let variant = entry.variant {
            Text(variant)
              .font(.caption)
              .padding(.horizontal, 6)
              .padding(.vertical, 1)
              .background(.quaternary, in: .capsule)
          }
        }
        if let aliases = entry.exercise?.aliases, !aliases.isEmpty {
          Text(aliases.joined(separator: " · "))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        previousHint
      }
      Spacer()
      menu
    }
  }

  /// The hint and note left last time for this exercise.
  @ViewBuilder
  private var previousHint: some View {
    if let exercise = entry.exercise, let workout = entry.workout,
       let previous = planner.previousEntry(for: exercise, before: workout),
       previous.hint != nil || previous.note != nil {
      HStack(spacing: 4) {
        if let hint = previous.hint {
          Label(hint == .up ? "Last time: try harder" : "Last time: go lighter",
                systemImage: hint == .up ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
            .foregroundStyle(hint == .up ? .green : .orange)
        }
        if let note = previous.note {
          Text(note)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }
      .font(.caption)
    }
  }

  private var menu: some View {
    Menu {
      if let exercise = entry.exercise {
        Menu("Variant") {
          Button("None") { entry.variant = nil }
          ForEach(planner.variantOptions(for: exercise), id: \.self) { variant in
            Button(variant) { entry.variant = variant }
          }
          Button("New variant…") {
            editingText = TextPrompt(title: String(localized: "Variant"), text: "") { text in
              entry.variant = text.isEmpty ? nil : text
            }
          }
        }
      }
      Button("Note…", systemImage: "note.text") {
        editingText = TextPrompt(title: String(localized: "Note"), text: entry.note ?? "") { text in
          entry.note = text.isEmpty ? nil : text
        }
      }
      Button("Remove exercise", systemImage: "trash", role: .destructive, action: onRemove)
    } label: {
      Image(systemName: "ellipsis.circle")
        .font(.title3)
    }
    .buttonStyle(.borderless)
  }

  private var footer: some View {
    HStack {
      Button("Set", systemImage: "plus") {
        let set = planner.addSet(to: entry)
        if !isLive { selectedSet = set }
      }
      Spacer()
      Text("Next time")
        .font(.caption)
        .foregroundStyle(.secondary)
      hintButton(.up)
      hintButton(.down)
    }
    .buttonStyle(.borderless)
  }

  private func hintButton(_ hint: Hint) -> some View {
    let isOn = entry.hint == hint
    return Button {
      entry.hint = isOn ? nil : hint
    } label: {
      Image(systemName: hint == .up ? "arrow.up.circle" : "arrow.down.circle")
        .symbolVariant(isOn ? .fill : .none)
        .font(.title2)
        .foregroundStyle(isOn ? (hint == .up ? Color.green : .orange) : .secondary)
    }
    .accessibilityLabel(hint == .up ? "Try harder next time" : "Go lighter next time")
    .accessibilityAddTraits(isOn ? .isSelected : [])
  }
}

private struct TextPrompt {
  let title: String
  var text: String
  let onSave: (String) -> Void

  func save() {
    onSave(text.trimmingCharacters(in: .whitespacesAndNewlines))
  }
}

struct SetRow: View {
  let set: SetEntry
  let label: String
  let summary: SetSummary
  let isLive: Bool
  let isSelected: Bool
  let onTap: () -> Void
  let onToggleDone: () -> Void

  var body: some View {
    HStack {
      Text(label)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(width: 22, alignment: .leading)
      Text(summary.text(for: set.values))
        .monospacedDigit()
        .foregroundStyle(isLive && !set.isDone ? .secondary : .primary)
      Spacer()
      if isLive {
        Button(action: onToggleDone) {
          Image(systemName: set.isDone ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .foregroundStyle(set.isDone ? Color.green : .secondary)
            .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(set.isDone ? "Mark as not done" : "Mark as done")
      }
    }
    .padding(.leading, set.isDrop ? 12 : 0)
    .contentShape(.rect)
    .onTapGesture(perform: onTap)
    .listRowBackground(isSelected ? Color.accentColor.opacity(0.08) : nil)
  }
}
