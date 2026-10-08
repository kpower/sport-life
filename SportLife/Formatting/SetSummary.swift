import Foundation

/// Compresses sets into short lines, e.g. "3 × 12 @ 27,3 kg" or "1 × 6 @ 27 kg + 6 @ 18 kg".
struct SetSummary {
  var metrics: [Metric]
  var units = MetricUnits()
  var weightIsAdded = false
  var handles = 1
  var locale = Locale.current

  /// One line per run of identical sets (a set together with its drop parts).
  func lines(for sets: [SetValues]) -> [String] {
    var segments: [[SetValues]] = []
    for set in sets {
      if set.drop, !segments.isEmpty {
        segments[segments.count - 1].append(set)
      } else {
        segments.append([set])
      }
    }

    var groups: [(count: Int, segment: [SetValues])] = []
    for segment in segments {
      if let last = groups.last, sameValues(last.segment, segment) {
        groups[groups.count - 1].count += 1
      } else {
        groups.append((1, segment))
      }
    }

    return groups.map { group in
      let parts = group.segment.map(text(for:))
      if metrics.contains(.reps) {
        return "\(group.count) × " + parts.joined(separator: " + ")
      }
      let text = parts.joined(separator: " + ")
      return group.count > 1 ? "\(group.count) × \(text)" : text
    }
  }

  private func sameValues(_ a: [SetValues], _ b: [SetValues]) -> Bool {
    a.count == b.count && zip(a, b).allSatisfy { x, y in
      x.with { $0.done = true } == y.with { $0.done = true }
    }
  }

  /// One set without a count, e.g. "12 @ 27,3 kg" or "5 min · level 8".
  func text(for set: SetValues) -> String {
    if metrics.contains(.reps) {
      let reps = set.reps.map(String.init) ?? "?"
      guard metrics.contains(.weight) else { return reps }
      return "\(reps) @ \(set.weight.map(weightText) ?? "—")"
    }
    let parts = [
      set.duration.map { withUnit($0, units.duration ?? "min") },
      set.distance.map { withUnit($0, units.distance) },
      set.speed.map { withUnit($0, units.speed) },
      set.intensity.flatMap { $0 > 0 ? String(localized: "level \(number($0))", locale: locale) : nil },
    ].compactMap { $0 }
    if !parts.isEmpty { return parts.joined(separator: " · ") }
    return set.weight.map(weightText) ?? "—"
  }

  private func weightText(_ weight: Double) -> String {
    if weightIsAdded {
      return weight == 0 ? "BW" : "BW + \(withUnit(weight, units.weight))"
    }
    let text = withUnit(weight, units.weight)
    return handles > 1 ? "\(handles) × \(text)" : text
  }

  private func withUnit(_ value: Double, _ unit: String?) -> String {
    guard let unit, !unit.isEmpty else { return number(value) }
    return "\(number(value)) \(unit)"
  }

  private func number(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
  }
}

extension SetSummary {
  init(exercise: Exercise?, locale: Locale = .current) {
    self.init(
      metrics: exercise?.metrics ?? [.weight, .reps],
      units: exercise?.units ?? MetricUnits(),
      weightIsAdded: exercise?.weightIsAdded ?? false,
      handles: exercise?.handles ?? 1,
      locale: locale)
  }
}
