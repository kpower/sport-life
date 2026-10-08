import Foundation
import SwiftData
import Testing
@testable import SportLife

struct PlannerTests {
  let context: ModelContext
  let planner: WorkoutPlanner

  init() throws {
    context = try Fixture.importedContext()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let now = Date(timeIntervalSince1970: 1_791_489_600) // 2026-10-08 18:00 UTC
    planner = WorkoutPlanner(context: context, now: { now }, calendar: calendar)
  }

  private func values(_ entry: WorkoutEntry) -> [SetValues] {
    entry.orderedSets.map(\.values)
  }

  private func entry(_ exerciseID: String, in workout: Workout) throws -> WorkoutEntry {
    try #require(workout.orderedEntries.first { $0.exercise?.externalID == exerciseID })
  }

  @Test func repeatCopiesOrderAndLatestDoneSets() throws {
    let template = try Fixture.workout("w-2026-10-06", in: context)
    let workout = planner.startWorkout(repeating: template)

    #expect(workout.isLive)
    #expect(workout.day == "2026-10-08")
    #expect(workout.orderedEntries.map { $0.exercise?.externalID }
            == ["ellipsis", "lat-pulldown", "cable-chest-fly"])

    // Done sets only, drop parts left out, all planned.
    let lat = try entry("lat-pulldown", in: workout)
    #expect(values(lat) == [SetValues(weight: 27.3, reps: 12, done: false),
                            SetValues(weight: 27.3, reps: 6, done: false)])
    #expect(lat.variant == "малый гриф")
    #expect(lat.hint == nil)
    #expect(values(try entry("ellipsis", in: workout)) == [SetValues(duration: 5, intensity: 0, done: false)])
    #expect(try planner.activeWorkout() == workout)
  }

  @Test func prefillComesFromAnyWorkout() throws {
    let workout = planner.startWorkout()
    let chin = planner.addEntry(for: try Fixture.exercise("chin-assist", in: context), to: workout)
    #expect(values(chin) == [SetValues(weight: 36, reps: 12, done: false)])
  }

  @Test func newExerciseGetsDefaults() throws {
    let workout = planner.startWorkout()
    let press = Exercise(name: "Bench", metrics: [.weight, .reps])
    let bike = Exercise(name: "Bike", metrics: [.duration, .intensity])
    context.insert(press)
    context.insert(bike)

    #expect(values(planner.addEntry(for: press, to: workout))
            == Array(repeating: SetValues(reps: 12, done: false), count: 3))
    #expect(values(planner.addEntry(for: bike, to: workout)) == [SetValues(intensity: 0, done: false)])
  }

  @Test func previousEntryLooksBackOnly() throws {
    let lat = try Fixture.exercise("lat-pulldown", in: context)
    let old = try Fixture.workout("w-2023-02-18", in: context)
    let recent = try Fixture.workout("w-2026-10-06", in: context)

    #expect(planner.previousEntry(for: lat, before: old) == nil)
    #expect(planner.previousEntry(for: lat, before: recent)?.workout == old)
  }

  @Test func failedSetWithDropPart() throws {
    let workout = planner.startWorkout(repeating: try Fixture.workout("w-2026-10-06", in: context))
    let lat = try entry("lat-pulldown", in: workout)
    let first = lat.orderedSets[0]

    let drop = try #require(planner.failSet(first, repsDone: 8, dropWeight: 25))
    #expect(drop.isDrop && !drop.isDone)
    #expect(values(lat) == [
      SetValues(weight: 27.3, reps: 8),
      SetValues(weight: 25, reps: 4, drop: true, done: false),
      SetValues(weight: 27.3, reps: 6, done: false),
    ])
    #expect(lat.orderedSets.map(\.order) == [0, 1, 2])
  }

  @Test func failedSetWithFewerReps() throws {
    let workout = planner.startWorkout(repeating: try Fixture.workout("w-2026-10-06", in: context))
    let lat = try entry("lat-pulldown", in: workout)

    #expect(planner.failSet(lat.orderedSets[0], repsDone: 10, dropWeight: nil) == nil)
    #expect(values(lat)[0] == SetValues(weight: 27.3, reps: 10))
    #expect(lat.orderedSets.count == 2)
  }

  @Test func applyToRemainingSkipsDoneSets() throws {
    let workout = planner.startWorkout()
    let lat = planner.addEntry(for: try Fixture.exercise("lat-pulldown", in: context), to: workout)
    planner.addSet(to: lat)
    let sets = lat.orderedSets
    sets[1].isDone = true
    sets[0].weight = 32
    sets[0].reps = 12

    #expect(planner.remainingSets(after: sets[0]) == [sets[2]])
    planner.applyToRemaining(from: sets[0])
    #expect(values(lat) == [SetValues(weight: 32, reps: 12, done: false),
                            SetValues(weight: 27.3, reps: 6),
                            SetValues(weight: 32, reps: 12, done: false)])
  }

  @Test func finishKeepsOnlyDoneWork() throws {
    let workout = planner.startWorkout(repeating: try Fixture.workout("w-2026-10-06", in: context))
    let lat = try entry("lat-pulldown", in: workout)
    lat.orderedSets[1].isDone = true
    #expect(planner.plannedSetCount(in: workout) == 3)

    planner.finish(workout)
    try context.save()

    #expect(workout.finishedAt != nil && !workout.isLive)
    #expect(workout.orderedEntries.map { $0.exercise?.externalID } == ["lat-pulldown"])
    #expect(values(lat) == [SetValues(weight: 27.3, reps: 6)])
    #expect(lat.orderedSets.map(\.order) == [0])
    #expect(try planner.activeWorkout() == nil)
  }

  @Test func finishingEmptyWorkoutDeletesIt() throws {
    let workout = planner.startWorkout(repeating: try Fixture.workout("w-2026-10-06", in: context))
    planner.finish(workout)
    try context.save()
    #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 4)
  }

  @Test func removeAndRestoreEntry() throws {
    let workout = try Fixture.workout("w-2026-10-06", in: context)
    let before = try Exporter(context: context).makeFile().normalized()

    let snapshot = planner.removeEntry(try entry("lat-pulldown", in: workout))
    #expect(workout.orderedEntries.map(\.order) == [0, 1])
    planner.restore(snapshot)
    try context.save()

    #expect(try Exporter(context: context).makeFile().normalized() == before)
  }

  @Test func deleteAndRestoreSet() throws {
    let workout = try Fixture.workout("w-2026-10-06", in: context)
    let lat = try entry("lat-pulldown", in: workout)
    let original = values(lat)

    let snapshot = planner.deleteSet(lat.orderedSets[1])
    #expect(lat.orderedSets.count == 3)
    planner.restore(snapshot)
    #expect(values(lat) == original)
  }

  @Test func restoreAfterSave() throws {
    let workout = try Fixture.workout("w-2026-10-06", in: context)
    let lat = try entry("lat-pulldown", in: workout)
    let original = values(lat)

    let setSnapshot = planner.deleteSet(lat.orderedSets[1])
    try context.save()
    planner.restore(setSnapshot)
    try context.save()
    #expect(values(lat) == original)

    let entrySnapshot = planner.removeEntry(lat)
    try context.save()
    planner.restore(entrySnapshot)
    try context.save()
    let restored = try entry("lat-pulldown", in: workout)
    #expect(values(restored) == original)
    #expect(workout.orderedEntries.map(\.order) == [0, 1, 2])
  }

  @Test func addSetInPastWorkoutIsDone() throws {
    let workout = try Fixture.workout("w-2026-04-29", in: context)
    let chin = try entry("chin-assist", in: workout)
    let set = planner.addSet(to: chin)
    #expect(set.values == SetValues(weight: 36, reps: 12))
    #expect(set.order == 1)
  }

  @Test func moveEntries() throws {
    let workout = try Fixture.workout("w-2026-10-06", in: context)
    planner.moveEntries(in: workout, from: [2], to: 0)
    #expect(workout.orderedEntries.map { $0.exercise?.externalID }
            == ["cable-chest-fly", "ellipsis", "lat-pulldown"])
  }

  @Test func weightOptionsUseDoneSets() throws {
    let lat = try Fixture.exercise("lat-pulldown", in: context)
    #expect(planner.weightOptions(for: lat) == [18, 25, 27.3])
    #expect(planner.lowerWeight(below: 27.3, for: lat) == 25)
    #expect(planner.lowerWeight(below: 18, for: lat) == 18)
    #expect(planner.variantOptions(for: lat) == ["малый гриф"])
  }
}

struct ExerciseSearchTests {
  let context: ModelContext
  let exercises: [Exercise]
  let stats: ExerciseSearch.Stats

  init() throws {
    context = try Fixture.importedContext()
    exercises = try context.fetch(FetchDescriptor<Exercise>())
    stats = ExerciseSearch.stats(from: try context.fetch(FetchDescriptor<Workout>()))
  }

  private func search(_ query: String, after previous: String? = nil,
                      excluded: Set<String> = []) throws -> [String] {
    let previous = try previous.map { try Fixture.exercise($0, in: context) }
    return ExerciseSearch.rank(exercises, query: query, stats: stats, after: previous,
                               excluded: excluded, today: "2026-10-08")
      .map(\.externalID)
  }

  @Test func findsByAlias() throws {
    #expect(try search("st 101").first == "lat-pulldown")
    #expect(try search("v-sport").first == "lat-pulldown")
  }

  @Test func findsRussianAndToleratesSkippedLetters() throws {
    #expect(try search("гипер") == ["hyperextension"])
    #expect(try search("подем").first == "leg-raise")
    #expect(try search("LAT pull") == ["lat-pulldown"])
  }

  @Test func treatsYoAsYe() throws {
    let exercise = Exercise(name: "Жим лёжа", metrics: [.weight, .reps])
    context.insert(exercise)
    #expect(ExerciseSearch.rank([exercise], query: "жим леж", stats: stats, after: nil).count == 1)
  }

  @Test func emptyQuerySuggestsWhatUsuallyFollows() throws {
    let suggestions = try search("", after: "ellipsis", excluded: ["ellipsis"])
    #expect(suggestions.first == "lat-pulldown")
    #expect(!suggestions.contains("ellipsis"))
  }

  @Test func leavesOutArchived() throws {
    #expect(try search("бег").isEmpty)
  }

  @Test func noMatch() throws {
    #expect(try search("zzz").isEmpty)
  }
}
