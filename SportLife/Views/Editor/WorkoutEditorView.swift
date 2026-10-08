import SwiftData
import SwiftUI

/// Logs a live workout set by set, or edits a past one. Live workouts show a ✓ per set;
/// past workouts are edited directly.
struct WorkoutEditorView: View {
  @Bindable var workout: Workout
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  @State private var selectedSet: SetEntry?
  @State private var failingSet: SetEntry?
  @State private var isAddingExercise = false
  @State private var isReordering = false
  @State private var isConfirmingFinish = false
  @State private var isConfirmingDelete = false
  @State private var toast: UndoToast?

  private var planner: WorkoutPlanner { WorkoutPlanner(context: context) }

  var body: some View {
    List {
      if !workout.isLive {
        Section {
          DatePicker("Date", selection: dayBinding, displayedComponents: .date)
          TextField("Note", text: noteBinding, axis: .vertical)
        }
      }
      ForEach(workout.orderedEntries) { entry in
        EntrySection(
          entry: entry,
          selectedSet: $selectedSet,
          onFail: { failingSet = $0 },
          onRemove: { remove(entry) },
          onDeleteSet: { delete($0) })
      }
      Section {
        Button("Add exercise", systemImage: "plus.circle.fill") { isAddingExercise = true }
      }
    }
    .listSectionSpacing(.compact)
    .scrollDismissesKeyboard(.interactively)
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar { toolbar }
    .sheet(isPresented: $isAddingExercise) {
      ExercisePickerView(workout: workout) { exercise in
        let entry = planner.addEntry(for: exercise, to: workout)
        selectedSet = workout.isLive ? nil : entry.orderedSets.first
      }
    }
    .sheet(item: $failingSet) { set in
      FailSetSheet(set: set) { drop in selectedSet = drop }
        .presentationDetents([.height(320)])
    }
    .sheet(isPresented: $isReordering) {
      ReorderEntriesView(workout: workout)
    }
    .confirmationDialog(finishQuestion, isPresented: $isConfirmingFinish, titleVisibility: .visible) {
      Button("Finish workout") { close { planner.finish(workout) } }
    }
    .confirmationDialog(
      workout.isLive ? "Discard this workout?" : "Delete this workout?",
      isPresented: $isConfirmingDelete, titleVisibility: .visible
    ) {
      Button(workout.isLive ? "Discard" : "Delete", role: .destructive) {
        close { context.delete(workout) }
      }
    }
    .overlay(alignment: .bottom) {
      if let toast {
        UndoToastView(toast: toast) { self.toast = nil }
          .padding()
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .animation(.default, value: toast?.id)
  }

  @ToolbarContentBuilder
  private var toolbar: some ToolbarContent {
    if workout.isLive {
      ToolbarItem(placement: .confirmationAction) {
        Button("Finish") {
          if planner.plannedSetCount(in: workout) > 0 {
            isConfirmingFinish = true
          } else {
            close { planner.finish(workout) }
          }
        }
      }
    }
    ToolbarItem(placement: .secondaryAction) {
      Button("Reorder exercises", systemImage: "arrow.up.arrow.down") { isReordering = true }
        .disabled(workout.orderedEntries.count < 2)
    }
    ToolbarItem(placement: .secondaryAction) {
      Button(workout.isLive ? "Discard workout" : "Delete workout",
             systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
    }
    ToolbarItemGroup(placement: .keyboard) {
      Spacer()
      Button("Done") { hideKeyboard() }
    }
  }

  private var title: String {
    let date = Day.date(from: workout.day)?.formatted(date: .abbreviated, time: .omitted) ?? workout.day
    return workout.isLive ? String(localized: "Workout · \(date)") : date
  }

  private var finishQuestion: String {
    let count = planner.plannedSetCount(in: workout)
    return String(localized: "\(count) planned sets weren't done. They will be removed.")
  }

  private var dayBinding: Binding<Date> {
    Binding(get: { Day.date(from: workout.day) ?? .now },
            set: { workout.day = Day.key(for: $0) })
  }

  private var noteBinding: Binding<String> {
    Binding(get: { workout.note ?? "" },
            set: { workout.note = $0.isEmpty ? nil : $0 })
  }

  private func remove(_ entry: WorkoutEntry) {
    let name = entry.exercise?.name ?? ""
    let planner = planner
    let snapshot = planner.removeEntry(entry)
    toast = UndoToast(message: String(localized: "Removed \(name)")) { planner.restore(snapshot) }
  }

  private func delete(_ set: SetEntry) {
    if selectedSet == set { selectedSet = nil }
    let planner = planner
    let snapshot = planner.deleteSet(set)
    toast = UndoToast(message: String(localized: "Set deleted")) {
      planner.restore(snapshot)
    }
  }

  /// Leaves the screen first, then changes the workout, so the view never renders a
  /// deleted object.
  private func close(then action: @escaping () -> Void) {
    dismiss()
    Task {
      try? await Task.sleep(for: .milliseconds(450))
      action()
      try? context.save()
    }
  }
}

@MainActor
func hideKeyboard() {
  UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

#Preview {
  NavigationStack {
    WorkoutEditorView(workout: PreviewData.liveWorkout)
  }
  .modelContainer(PreviewData.container)
}
