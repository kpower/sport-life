import Foundation
import SwiftData

/// Creates and edits workouts. Every exercise is pre-filled from the last time it was
/// done anywhere, as planned (not done) sets.
struct WorkoutPlanner {
  let context: ModelContext
  var now: () -> Date = { .now }
  var calendar = Calendar.current

  // MARK: Workouts

  func activeWorkout() throws -> Workout? {
    try context.fetch(FetchDescriptor<Workout>(
      predicate: #Predicate { $0.startedAt != nil && $0.finishedAt == nil },
      sortBy: [SortDescriptor(\.startedAt, order: .reverse)])).first
  }

  /// Starts a live workout, optionally with the exercises of `template` in its order.
  func startWorkout(repeating template: Workout? = nil) -> Workout {
    let workout = Workout(day: Day.key(for: now(), calendar: calendar))
    workout.startedAt = now()
    context.insert(workout)
    for entry in template?.orderedEntries ?? [] {
      if let exercise = entry.exercise {
        addEntry(for: exercise, to: workout)
      }
    }
    return workout
  }

  /// Ends a live workout: sets that were never done and exercises left without sets
  /// are removed. A workout with nothing done is deleted.
  func finish(_ workout: Workout) {
    for entry in workout.orderedEntries {
      for set in entry.orderedSets where !set.isDone {
        context.delete(set)
      }
      if entry.orderedSets.isEmpty {
        context.delete(entry)
      } else {
        renumber(entry.orderedSets)
      }
    }
    renumber(workout.orderedEntries)
    if workout.orderedEntries.isEmpty {
      context.delete(workout)
    } else {
      workout.finishedAt = now()
    }
  }

  func plannedSetCount(in workout: Workout) -> Int {
    workout.orderedEntries.reduce(0) { $0 + $1.orderedSets.filter { !$0.isDone }.count }
  }

  // MARK: Entries

  @discardableResult
  func addEntry(for exercise: Exercise, to workout: Workout) -> WorkoutEntry {
    let entry = WorkoutEntry(order: (workout.orderedEntries.last?.order ?? -1) + 1)
    context.insert(entry)
    entry.workout = workout
    entry.exercise = exercise

    let plan = plan(for: exercise, in: workout)
    entry.variant = plan.variant
    for (index, values) in plan.sets.enumerated() {
      let set = SetEntry(order: index, values: values.with { $0.done = !workout.isLive })
      context.insert(set)
      set.entry = entry
    }
    return entry
  }

  /// What to do next time: the done sets of the previous entry, without drop parts
  /// (those were failure recovery, not the plan).
  func plan(for exercise: Exercise, in workout: Workout) -> (variant: String?, sets: [SetValues]) {
    if let previous = previousEntry(for: exercise, before: workout) {
      let sets = previous.orderedSets
        .filter { $0.isDone && !$0.isDrop }
        .map { set in set.values.with { $0.done = false } }
      if !sets.isEmpty { return (previous.variant, sets) }
    }
    let metrics = exercise.metrics
    if metrics.contains(.reps) {
      return (nil, Array(repeating: SetValues(reps: 12, done: false), count: 3))
    }
    return (nil, [SetValues(intensity: metrics.contains(.intensity) ? 0 : nil, done: false)])
  }

  /// The latest entry of `exercise` with at least one done set, in another workout on
  /// the same day or earlier.
  func previousEntry(for exercise: Exercise, before workout: Workout) -> WorkoutEntry? {
    (exercise.entries ?? [])
      .filter { entry in
        guard !entry.isDeleted, let other = entry.workout, other != workout else { return false }
        return other.day <= workout.day && entry.orderedSets.contains(where: \.isDone)
      }
      .max { a, b in
        let (wa, wb) = (a.workout!, b.workout!)
        if wa.day != wb.day { return wa.day < wb.day }
        let (sa, sb) = (wa.startedAt ?? .distantPast, wb.startedAt ?? .distantPast)
        if sa != sb { return sa < sb }
        return wa.externalID < wb.externalID
      }
  }

  func removeEntry(_ entry: WorkoutEntry) -> EntrySnapshot {
    let snapshot = EntrySnapshot(entry)
    let workout = entry.workout
    context.delete(entry)
    if let workout { renumber(workout.orderedEntries) }
    return snapshot
  }

  func restore(_ snapshot: EntrySnapshot) {
    guard let workout = snapshot.workout else { return }
    for other in workout.orderedEntries where other.order >= snapshot.order {
      other.order += 1
    }
    let entry = WorkoutEntry(order: snapshot.order)
    context.insert(entry)
    entry.workout = workout
    entry.exercise = snapshot.exercise
    entry.variant = snapshot.variant
    entry.hint = snapshot.hint
    entry.note = snapshot.note
    entry.originalName = snapshot.originalName
    entry.source = snapshot.source
    for (index, values) in snapshot.sets.enumerated() {
      let set = SetEntry(order: index, values: values)
      context.insert(set)
      set.entry = entry
    }
    renumber(workout.orderedEntries)
  }

  func moveEntries(in workout: Workout, from source: IndexSet, to destination: Int) {
    // Same semantics as SwiftUI's `move(fromOffsets:toOffset:)`.
    let entries = workout.orderedEntries
    var reordered = entries.enumerated().filter { !source.contains($0.offset) }.map(\.element)
    let insertAt = destination - source.filter { $0 < destination }.count
    reordered.insert(contentsOf: source.map { entries[$0] }, at: insertAt)
    renumber(reordered)
  }

  // MARK: Sets

  /// A new set after the last one, copying its values (or the plan when there is none).
  @discardableResult
  func addSet(to entry: WorkoutEntry) -> SetEntry {
    let last = entry.orderedSets.last { !$0.isDrop }
    var values = last?.values
      ?? entry.exercise.flatMap { exercise in
        entry.workout.flatMap { plan(for: exercise, in: $0).sets.first }
      }
      ?? SetValues(reps: 12)
    values.drop = false
    values.done = !(entry.workout?.isLive ?? false)
    let set = SetEntry(order: (entry.orderedSets.last?.order ?? -1) + 1, values: values)
    context.insert(set)
    set.entry = entry
    return set
  }

  func deleteSet(_ set: SetEntry) -> SetSnapshot {
    let snapshot = SetSnapshot(set)
    let entry = set.entry
    context.delete(set)
    if let entry { renumber(entry.orderedSets) }
    return snapshot
  }

  func restore(_ snapshot: SetSnapshot) {
    guard let entry = snapshot.entry else { return }
    for other in entry.orderedSets where other.order >= snapshot.order {
      other.order += 1
    }
    let set = SetEntry(order: snapshot.order, values: snapshot.values)
    context.insert(set)
    set.entry = entry
    renumber(entry.orderedSets)
  }

  /// Couldn't finish a set: records the reps actually done and marks it done.
  /// With `dropWeight`, adds a drop part right after it for the remaining reps and
  /// returns it (planned, so it can be adjusted and confirmed).
  @discardableResult
  func failSet(_ set: SetEntry, repsDone: Int, dropWeight: Double?) -> SetEntry? {
    let planned = set.reps ?? repsDone
    set.reps = repsDone
    set.isDone = true
    guard let dropWeight, let entry = set.entry else { return nil }

    // After the set and any drop parts it already has.
    let sets = entry.orderedSets
    let after = (sets.firstIndex(of: set) ?? sets.count - 1) + 1
    let insertAt = sets[after...].firstIndex { !$0.isDrop } ?? sets.count

    let drop = SetEntry(order: 0, values: SetValues(
      weight: dropWeight, reps: max(planned - repsDone, 1), drop: true, done: false))
    context.insert(drop)
    drop.entry = entry
    renumber(sets[..<insertAt] + [drop] + sets[insertAt...])
    return drop
  }

  /// Later sets that `applyToRemaining(from:)` would change.
  func remainingSets(after set: SetEntry) -> [SetEntry] {
    guard let entry = set.entry else { return [] }
    return entry.orderedSets.filter { $0.order > set.order && !$0.isDone && !$0.isDrop }
  }

  /// Copies the set's values to the later sets that are still planned.
  func applyToRemaining(from set: SetEntry) {
    let values = set.values.with {
      $0.drop = false
      $0.done = false
    }
    for other in remainingSets(after: set) { other.values = values }
  }

  // MARK: History

  /// Every weight used for this exercise, ascending.
  func weightOptions(for exercise: Exercise) -> [Double] {
    let weights = (exercise.entries ?? [])
      .filter { !$0.isDeleted }
      .flatMap(\.orderedSets)
      .filter(\.isDone)
      .compactMap(\.weight)
    return Array(Set(weights)).sorted()
  }

  func variantOptions(for exercise: Exercise) -> [String] {
    let variants = (exercise.entries ?? []).filter { !$0.isDeleted }.compactMap(\.variant)
    return Array(Set(variants)).sorted()
  }

  /// The closest known weight below `weight`, for a drop part.
  func lowerWeight(below weight: Double?, for exercise: Exercise) -> Double? {
    guard let weight else { return nil }
    return weightOptions(for: exercise).last { $0 < weight } ?? weight
  }

  private func renumber(_ entries: [WorkoutEntry]) {
    for (index, entry) in entries.enumerated() where entry.order != index {
      entry.order = index
    }
  }

  private func renumber(_ sets: [SetEntry]) {
    for (index, set) in sets.enumerated() where set.order != index {
      set.order = index
    }
  }
}

/// Everything needed to put back a removed exercise entry.
struct EntrySnapshot {
  let workout: Workout?
  let exercise: Exercise?
  let order: Int
  let variant: String?
  let hint: Hint?
  let note: String?
  let originalName: String?
  let source: String?
  let sets: [SetValues]

  init(_ entry: WorkoutEntry) {
    workout = entry.workout
    exercise = entry.exercise
    order = entry.order
    variant = entry.variant
    hint = entry.hint
    note = entry.note
    originalName = entry.originalName
    source = entry.source
    sets = entry.orderedSets.map(\.values)
  }
}

struct SetSnapshot {
  let entry: WorkoutEntry?
  let order: Int
  let values: SetValues

  init(_ set: SetEntry) {
    entry = set.entry
    order = set.order
    values = set.values
  }
}
