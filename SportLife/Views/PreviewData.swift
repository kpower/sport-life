#if DEBUG
import Foundation
import SwiftData

/// In-memory store with a couple of workouts, for SwiftUI previews.
enum PreviewData {
    static let container: ModelContainer = {
        let container = try! ModelContainer(
            for: Schema(AppSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        _ = try! Importer(context: container.mainContext).importData(Data(json.utf8))
        return container
    }()

    private static let json = """
    {
      "format": "sport-life",
      "version": 1,
      "exercises": [
        {"id": "ellipsis", "name": "Ellipsis", "metrics": ["duration", "intensity"], "units": {"duration": "min"}},
        {"id": "lat-pulldown", "name": "Lat Pulldown", "aliases": ["V-Sport ST-101"], "metrics": ["weight", "reps"], "units": {"weight": "kg"}},
        {"id": "chin-assist", "name": "Chin Assist", "metrics": ["weight", "reps"], "units": {"weight": "kg"}, "lessIsBetter": true},
        {"id": "hyperextension", "name": "Гиперэкстензия", "metrics": ["weight", "reps"], "units": {"weight": "kg"}, "weightIsAdded": true}
      ],
      "workouts": [
        {"id": "w1", "date": "2026-10-06", "entries": [
          {"exercise": "ellipsis", "variant": "Fat", "sets": [{"duration": 5, "intensity": 0}]},
          {"exercise": "lat-pulldown", "hint": "up", "sets": [{"reps": 12, "weight": 32}, {"reps": 12, "weight": 32}, {"reps": 6, "weight": 32}, {"reps": 6, "weight": 27.3, "drop": true}]}
        ]},
        {"id": "w2", "date": "2026-10-02", "label": "Legs", "entries": [
          {"exercise": "hyperextension", "sets": [{"reps": 12, "weight": 0}, {"reps": 12, "weight": 0}, {"reps": 12, "weight": 5}]},
          {"exercise": "chin-assist", "sets": [{"reps": 12, "weight": 36}, {"reps": 12, "weight": 36}, {"reps": 12, "weight": 36}]}
        ]}
      ]
    }
    """
}
#endif
