import Foundation
import SwiftData
@testable import SportLife

/// Synthetic data covering every feature of the transfer format.
enum Fixture {
    static let json = """
    {
      "format": "sport-life",
      "version": 1,
      "exportedAt": "2026-10-07T19:00:00+00:00",
      "exercises": [
        {"id": "ellipsis", "name": "Ellipsis", "aliases": [], "metrics": ["duration", "intensity"],
         "units": {"duration": "min"}, "lessIsBetter": false, "weightIsAdded": false, "handles": 1, "note": null},
        {"id": "lat-pulldown", "name": "Lat Pulldown", "aliases": ["V-Sport ST-101", "St 101 верхняя тяга"],
         "metrics": ["weight", "reps"], "units": {"weight": "kg"}},
        {"id": "chin-assist", "name": "Chin Assist", "metrics": ["weight", "reps"],
         "units": {"weight": "kg"}, "lessIsBetter": true},
        {"id": "hyperextension", "name": "Гиперэкстензия", "metrics": ["weight", "reps"],
         "units": {"weight": "kg"}, "weightIsAdded": true},
        {"id": "cable-chest-fly", "name": "Cable Chest Fly", "metrics": ["weight", "reps"],
         "units": {"weight": "kg"}, "handles": 2, "note": "two stands"},
        {"id": "leg-raise", "name": "Подъем ног", "metrics": ["reps"]},
        {"id": "run", "name": "Бег", "metrics": ["distance", "speed", "duration", "intensity"],
         "units": {"distance": "km", "speed": "km/h", "duration": "min"}, "archived": true}
      ],
      "workouts": [
        {"id": "w-2023-02-18", "date": "2023-02-18", "entries": [
          {"exercise": "run", "note": "with walking", "source": "Бег 1.5 км 8,3 в час",
           "sets": [{"distance": 1.5, "speed": 8.3, "duration": 10, "intensity": 0}]},
          {"exercise": "lat-pulldown", "originalName": "St 101 верхняя тяга",
           "sets": [{"reps": 12, "weight": 25}, {"reps": 12, "weight": 25}]},
          {"exercise": "leg-raise", "sets": [{"reps": 7}, {"reps": 7}]}
        ]},
        {"id": "w-2026-04-29", "date": "2026-04-29", "label": "Legs", "note": "felt good", "entries": [
          {"exercise": "hyperextension", "sets": [{"reps": 12, "weight": 0}, {"reps": 12, "weight": 5}]},
          {"exercise": "chin-assist", "hint": "down", "sets": [{"reps": 12, "weight": 36}]}
        ]},
        {"id": "w-2026-04-29-2", "date": "2026-04-29", "entries": []},
        {"id": "w-2026-10-06", "date": "2026-10-06",
         "startedAt": "2026-10-06T17:02:00Z", "finishedAt": "2026-10-06T18:10:00Z", "entries": [
          {"exercise": "ellipsis", "variant": "Fat", "sets": [{"duration": 5, "intensity": 0}]},
          {"exercise": "lat-pulldown", "hint": "up", "variant": "малый гриф", "sets": [
            {"reps": 12, "weight": 27.3}, {"reps": 6, "weight": 27.3}, {"reps": 6, "weight": 18, "drop": true},
            {"reps": 12, "weight": 23, "done": false}
          ]},
          {"exercise": "cable-chest-fly", "sets": [{"reps": 12, "weight": 4.8}]}
        ]}
      ]
    }
    """

    static func file() throws -> TransferFile {
        try TransferCoding.decoder().decode(TransferFile.self, from: Data(json.utf8))
    }

    static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(AppSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }
}

extension TransferFile {
    /// Order-independent form for comparing files: records sorted by id, no export time.
    func normalized() -> TransferFile {
        var copy = self
        copy.exportedAt = nil
        copy.exercises.sort { $0.id < $1.id }
        copy.workouts.sort { $0.id < $1.id }
        return copy
    }
}
