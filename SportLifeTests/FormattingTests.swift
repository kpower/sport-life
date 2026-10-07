import Foundation
import Testing
@testable import SportLife

struct SetSummaryTests {
    let ru = Locale(identifier: "ru_RU")
    let kg = MetricUnits(["weight": "kg"])

    private func strength(weightIsAdded: Bool = false, handles: Int = 1) -> SetSummary {
        SetSummary(metrics: [.weight, .reps], units: kg, weightIsAdded: weightIsAdded,
                   handles: handles, locale: ru)
    }

    private func sets(_ pairs: [(Int, Double)]) -> [SetValues] {
        pairs.map { SetValues(weight: $1, reps: $0) }
    }

    @Test func groupsIdenticalSets() {
        #expect(strength().lines(for: sets([(12, 27.3), (12, 27.3), (12, 27.3)])) == ["3 × 12 @ 27,3 kg"])
    }

    @Test func mixedSets() {
        #expect(strength().lines(for: sets([(12, 32), (12, 32), (12, 36)]))
                == ["2 × 12 @ 32 kg", "1 × 12 @ 36 kg"])
    }

    @Test func dropSetStaysWithItsSet() {
        var values = sets([(12, 27), (6, 27), (6, 18), (12, 14)])
        values[2].drop = true
        #expect(strength().lines(for: values)
                == ["1 × 12 @ 27 kg", "1 × 6 @ 27 kg + 6 @ 18 kg", "1 × 12 @ 14 kg"])
    }

    @Test func plannedSetsGroupWithDoneOnes() {
        var values = sets([(12, 32), (12, 32)])
        values[1].done = false
        #expect(strength().lines(for: values) == ["2 × 12 @ 32 kg"])
    }

    @Test func bodyweight() {
        #expect(strength(weightIsAdded: true).lines(for: sets([(12, 0), (12, 0), (12, 5)]))
                == ["2 × 12 @ BW", "1 × 12 @ BW + 5 kg"])
    }

    @Test func handles() {
        #expect(strength(handles: 2).lines(for: sets([(12, 4.8)])) == ["1 × 12 @ 2 × 4,8 kg"])
    }

    @Test func repsOnly() {
        let summary = SetSummary(metrics: [.reps], locale: ru)
        #expect(summary.lines(for: [SetValues(reps: 7), SetValues(reps: 7)]) == ["2 × 7"])
    }

    @Test func cardio() {
        let summary = SetSummary(
            metrics: [.distance, .speed, .duration, .intensity],
            units: MetricUnits(["duration": "min", "distance": "km", "speed": "km/h"]),
            locale: ru)
        #expect(summary.lines(for: [SetValues(duration: 5, intensity: 0)]) == ["5 min"])
        #expect(summary.lines(for: [SetValues(duration: 19.5, distance: 2, speed: 8.5)])
                == ["19,5 min · 2 km · 8,5 km/h"])
    }
}

struct DayTests {
    @Test func parsesAndFormats() throws {
        let calendar = Calendar(identifier: .gregorian)
        let date = try #require(Day.date(from: "2026-04-09", calendar: calendar))
        #expect(Day.key(for: date, calendar: calendar) == "2026-04-09")
        #expect(Day.monthKey("2026-04-09") == "2026-04")
    }

    @Test(arguments: ["2026-02-30", "2026-4-9", "", "yesterday"])
    func rejectsInvalid(_ key: String) {
        #expect(Day.date(from: key) == nil)
    }
}
