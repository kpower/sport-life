import Foundation

/// Finds exercises by name or alias (RU/EN, tolerant to case, ё/е and skipped letters)
/// and ranks them by match quality, what usually follows the previous exercise, usage
/// and recency.
struct ExerciseSearch {
  struct Stats {
    /// Number of workouts each exercise (by `externalID`) appears in.
    var uses: [String: Int] = [:]
    /// Latest day each exercise was done.
    var lastDay: [String: String] = [:]
    /// `follows[a][b]`: how often `b` came right after `a`.
    var follows: [String: [String: Int]] = [:]
  }

  static func stats(from workouts: [Workout]) -> Stats {
    var stats = Stats()
    for workout in workouts {
      let ids = workout.orderedEntries.compactMap { $0.exercise?.externalID }
      for id in Set(ids) {
        stats.uses[id, default: 0] += 1
        stats.lastDay[id] = max(stats.lastDay[id] ?? "", workout.day)
      }
      for (a, b) in zip(ids, ids.dropFirst()) {
        stats.follows[a, default: [:]][b, default: 0] += 1
      }
    }
    return stats
  }

  /// Matching exercises, best first. An empty query suggests what usually comes next,
  /// leaving out `excluded` (already in the workout).
  static func rank(_ exercises: [Exercise], query: String, stats: Stats,
                   after previous: Exercise?, excluded: Set<String> = [],
                   today: String = Day.key(for: .now)) -> [Exercise] {
    let tokens = normalize(query).split(separator: " ").map(String.init)
    let follows = previous.flatMap { stats.follows[$0.externalID] } ?? [:]
    let recentCutoff = Day.date(from: today)
      .flatMap { Calendar.current.date(byAdding: .day, value: -60, to: $0) }
      .map { Day.key(for: $0) } ?? ""

    let scored: [(Exercise, Int)] = exercises.compactMap { exercise in
      guard !exercise.isArchived else { return nil }
      let id = exercise.externalID
      guard let match = tokens.isEmpty ? 0 : matchScore(tokens, exercise),
            !(tokens.isEmpty && excluded.contains(id)) else { return nil }
      let recent = (stats.lastDay[id] ?? "") >= recentCutoff
      let score = match * 1000 + (follows[id] ?? 0) * 20 + min(stats.uses[id] ?? 0, 50) + (recent ? 10 : 0)
      return (exercise, score)
    }
    return scored
      .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.name.localizedLowercase < $1.0.name.localizedLowercase }
      .map(\.0)
  }

  /// Every token must match some name: word prefix (3), substring (2), or letters in
  /// order (1). Nil when any token doesn't match.
  static func matchScore(_ tokens: [String], _ exercise: Exercise) -> Int? {
    let names = ([exercise.name] + exercise.aliases).map(normalize)
    let scores = tokens.map { token in
      names.map { name in
        if name.split(separator: " ").contains(where: { $0.hasPrefix(token) }) {
          3
        } else if name.contains(token) {
          2
        } else if isSubsequence(token, of: name.replacingOccurrences(of: " ", with: "")) {
          1
        } else {
          0
        }
      }.max() ?? 0
    }
    return scores.contains(0) ? nil : scores.reduce(0, +)
  }

  static func normalize(_ text: String) -> String {
    let folded = text
      .lowercased()
      .replacingOccurrences(of: "ё", with: "е")
      .folding(options: [.diacriticInsensitive], locale: nil)
    let cleaned = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
    return String(cleaned).split(separator: " ").joined(separator: " ")
  }

  private static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
    var remaining = needle[...]
    for character in haystack where remaining.first == character {
      remaining = remaining.dropFirst()
      if remaining.isEmpty { return true }
    }
    return remaining.isEmpty
  }
}
