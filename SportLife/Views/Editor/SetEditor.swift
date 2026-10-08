import SwiftData
import SwiftUI

/// Inline editor for one set. Weight is picked from values used before (the app never
/// guesses machine steps) or typed.
struct SetEditor: View {
  @Bindable var set: SetEntry
  let exercise: Exercise
  let onFail: () -> Void
  let onDelete: () -> Void

  @Environment(\.modelContext) private var context

  private var planner: WorkoutPlanner { WorkoutPlanner(context: context) }
  private var metrics: [Metric] { exercise.metrics }
  private var units: MetricUnits { exercise.units }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if metrics.contains(.reps) {
        Stepper(value: intBinding(\.reps, default: 12), in: 0...200) {
          LabeledContent("Reps", value: set.reps.map(String.init) ?? "—")
        }
      }
      if metrics.contains(.weight) {
        weightEditor
      }
      if metrics.contains(.duration) {
        numberField("Duration", value: $set.duration, unit: units.duration ?? "min", step: 1)
      }
      if metrics.contains(.intensity) {
        Stepper(value: doubleBinding(\.intensity, default: 0), in: 0...30, step: 1) {
          LabeledContent("Intensity",
                         value: (set.intensity ?? 0).formatted(.number.precision(.fractionLength(0...1))))
        }
      }
      if metrics.contains(.distance) {
        numberField("Distance", value: $set.distance, unit: units.distance ?? "km", step: nil)
      }
      if metrics.contains(.speed) {
        numberField("Speed", value: $set.speed, unit: units.speed ?? "km/h", step: nil)
      }
      actions
    }
    .padding(.vertical, 4)
    .listRowBackground(Color.accentColor.opacity(0.08))
  }

  private var weightEditor: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(exercise.weightIsAdded ? "Added weight" : (exercise.handles > 1 ? "Weight per handle" : "Weight"))
        Spacer()
        TextField("—", value: $set.weight, format: .number)
          .keyboardType(.decimalPad)
          .multilineTextAlignment(.trailing)
          .monospacedDigit()
          .frame(maxWidth: 90)
          .textFieldStyle(.roundedBorder)
        Text(units.weight ?? "")
          .foregroundStyle(.secondary)
      }
      ScrollViewReader { proxy in
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 6) {
            ForEach(weightOptions, id: \.self) { weight in
              let isSelected = set.weight == weight
              Button(chipTitle(weight)) {
                set.weight = weight
                hideKeyboard()
              }
              .buttonStyle(.bordered)
              .tint(isSelected ? .accentColor : .secondary)
              .fontWeight(isSelected ? .semibold : .regular)
              .monospacedDigit()
              .id(weight)
            }
          }
        }
        .onAppear {
          if let weight = set.weight { proxy.scrollTo(weight, anchor: .center) }
        }
      }
    }
  }

  /// Known weights, the current one, and 0 (bodyweight) for added-weight exercises.
  private var weightOptions: [Double] {
    var options = Set(planner.weightOptions(for: exercise))
    if let weight = set.weight { options.insert(weight) }
    if exercise.weightIsAdded { options.insert(0) }
    return options.sorted()
  }

  private func chipTitle(_ weight: Double) -> String {
    if exercise.weightIsAdded && weight == 0 { return "BW" }
    return weight.formatted(.number.precision(.fractionLength(0...2)))
  }

  private var actions: some View {
    let remaining = planner.remainingSets(after: set)
    return HStack(spacing: 16) {
      if metrics.contains(.reps), !set.isDrop {
        Button("Couldn't finish…", systemImage: "exclamationmark.triangle", action: onFail)
      }
      if !set.isDrop, !remaining.isEmpty, set.values.differsFrom(remaining) {
        Button("Apply to \(remaining.count) more", systemImage: "arrow.down.to.line") {
          planner.applyToRemaining(from: set)
        }
      }
      Spacer()
      Button("Delete set", systemImage: "trash", role: .destructive, action: onDelete)
        .labelStyle(.iconOnly)
    }
    .font(.subheadline)
    .buttonStyle(.borderless)
  }

  private func numberField(_ title: LocalizedStringKey, value: Binding<Double?>, unit: String,
                           step: Double?) -> some View {
    HStack {
      Text(title)
      Spacer()
      TextField("—", value: value, format: .number)
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
        .monospacedDigit()
        .frame(maxWidth: 90)
        .textFieldStyle(.roundedBorder)
      Text(unit)
        .foregroundStyle(.secondary)
      if let step {
        Stepper("", value: Binding(get: { value.wrappedValue ?? 0 },
                                   set: { value.wrappedValue = max(0, $0) }),
                step: step)
          .labelsHidden()
      }
    }
  }

  private func intBinding(_ keyPath: ReferenceWritableKeyPath<SetEntry, Int?>, default value: Int) -> Binding<Int> {
    Binding(get: { set[keyPath: keyPath] ?? value }, set: { set[keyPath: keyPath] = $0 })
  }

  private func doubleBinding(_ keyPath: ReferenceWritableKeyPath<SetEntry, Double?>,
                             default value: Double) -> Binding<Double> {
    Binding(get: { set[keyPath: keyPath] ?? value }, set: { set[keyPath: keyPath] = $0 })
  }
}

private extension SetValues {
  /// True when copying these values would change at least one of `sets`.
  func differsFrom(_ sets: [SetEntry]) -> Bool {
    let mine = with {
      $0.drop = false
      $0.done = false
    }
    return sets.contains { other in other.values.with { $0.done = false } != mine }
  }
}

/// "Couldn't finish": how many reps were done, then either a drop part with less weight
/// or just fewer reps.
struct FailSetSheet: View {
  let set: SetEntry
  let onDrop: (SetEntry) -> Void

  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @State private var repsDone: Int

  init(set: SetEntry, onDrop: @escaping (SetEntry) -> Void) {
    self.set = set
    self.onDrop = onDrop
    _repsDone = State(initialValue: max((set.reps ?? 12) - 1, 0))
  }

  private var planned: Int { self.set.reps ?? 12 }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Stepper(value: $repsDone, in: 0...max(planned - 1, 0)) {
            LabeledContent("Reps done", value: "\(repsDone) / \(planned)")
          }
        }
        Section {
          Button("Finish with less weight", systemImage: "arrow.down.right") {
            let planner = WorkoutPlanner(context: context)
            let weight = set.entry?.exercise.flatMap { planner.lowerWeight(below: set.weight, for: $0) }
              ?? set.weight
            if let drop = planner.failSet(set, repsDone: repsDone, dropWeight: weight ?? 0) {
              onDrop(drop)
            }
            dismiss()
          }
          Button("Just fewer reps", systemImage: "minus.circle") {
            WorkoutPlanner(context: context).failSet(set, repsDone: repsDone, dropWeight: nil)
            dismiss()
          }
        } footer: {
          Text("Less weight adds a drop part for the remaining ^[\(planned - repsDone) rep](inflect: true).")
        }
      }
      .navigationTitle("Couldn't finish")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", role: .cancel) { dismiss() }
        }
      }
    }
  }
}
