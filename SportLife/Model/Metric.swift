import Foundation

/// A value a set can record. Which ones apply is configured per exercise.
nonisolated enum Metric: String, Codable, CaseIterable, Hashable {
    case weight, reps, duration, intensity, distance, speed
}

/// "Try harder / lighter next time", attached to a workout entry.
nonisolated enum Hint: String, Codable, Hashable {
    case up, down
}

/// Display unit per metric, e.g. weight → "kg", duration → "min".
nonisolated struct MetricUnits: Codable, Hashable {
    var weight: String?
    var reps: String?
    var duration: String?
    var intensity: String?
    var distance: String?
    var speed: String?

    init() {}

    /// Unknown keys are dropped.
    init(_ dictionary: [String: String]) {
        for (key, unit) in dictionary {
            if let metric = Metric(rawValue: key) { self[metric] = unit }
        }
    }

    var dictionary: [String: String] {
        var result: [String: String] = [:]
        for metric in Metric.allCases {
            if let unit = self[metric] { result[metric.rawValue] = unit }
        }
        return result
    }

    subscript(metric: Metric) -> String? {
        get {
            switch metric {
            case .weight: weight
            case .reps: reps
            case .duration: duration
            case .intensity: intensity
            case .distance: distance
            case .speed: speed
            }
        }
        set {
            switch metric {
            case .weight: weight = newValue
            case .reps: reps = newValue
            case .duration: duration = newValue
            case .intensity: intensity = newValue
            case .distance: distance = newValue
            case .speed: speed = newValue
            }
        }
    }
}
