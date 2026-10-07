import Foundation
import SwiftData

/// An exercise or machine. Every property here is global: changing it affects all history.
@Model
final class Exercise {
    /// Stable id used by import/export (a slug for imported data, a UUID otherwise).
    var externalID: String = UUID().uuidString
    var name: String = ""
    var aliases: [String] = []
    /// Comma-separated `Metric` raw values, in display order.
    var metricsRaw: String = ""
    /// `MetricUnits` as JSON. A plain string, because SwiftData can't load a composite
    /// struct whose fields are all nil.
    var unitsRaw: String = "{}"
    var lessIsBetter: Bool = false
    /// `weight` is extra load on top of bodyweight; 0 means bodyweight only.
    var weightIsAdded: Bool = false
    /// `weight` is per handle/stack; 2 for "(2x4,8)".
    var handles: Int = 1
    var note: String?
    var isArchived: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \WorkoutEntry.exercise)
    var entries: [WorkoutEntry]? = []

    init(externalID: String = UUID().uuidString, name: String, metrics: [Metric]) {
        self.externalID = externalID
        self.name = name
        self.metricsRaw = Self.encode(metrics)
    }

    var metrics: [Metric] {
        get { metricsRaw.split(separator: ",").compactMap { Metric(rawValue: String($0)) } }
        set { metricsRaw = Self.encode(newValue) }
    }

    var units: MetricUnits {
        get { (try? JSONDecoder().decode(MetricUnits.self, from: Data(unitsRaw.utf8))) ?? MetricUnits() }
        set {
            let data = (try? JSONEncoder().encode(newValue)) ?? Data("{}".utf8)
            unitsRaw = String(decoding: data, as: UTF8.self)
        }
    }

    private static func encode(_ metrics: [Metric]) -> String {
        metrics.map(\.rawValue).joined(separator: ",")
    }
}
