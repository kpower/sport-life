import Foundation

/// The values of one set, independent of storage. Also the `Set` record of the
/// transfer format: `drop` is written only when true, `done` only when false.
nonisolated struct SetValues: Codable, Hashable {
    var weight: Double?
    var reps: Int?
    var duration: Double?
    var intensity: Double?
    var distance: Double?
    var speed: Double?
    var drop = false
    var done = true

    init(weight: Double? = nil, reps: Int? = nil, duration: Double? = nil,
         intensity: Double? = nil, distance: Double? = nil, speed: Double? = nil,
         drop: Bool = false, done: Bool = true) {
        self.weight = weight
        self.reps = reps
        self.duration = duration
        self.intensity = intensity
        self.distance = distance
        self.speed = speed
        self.drop = drop
        self.done = done
    }

    private enum CodingKeys: String, CodingKey {
        case weight, reps, duration, intensity, distance, speed, drop, done
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weight = try c.decodeIfPresent(Double.self, forKey: .weight)
        reps = try c.decodeIfPresent(Int.self, forKey: .reps)
        duration = try c.decodeIfPresent(Double.self, forKey: .duration)
        intensity = try c.decodeIfPresent(Double.self, forKey: .intensity)
        distance = try c.decodeIfPresent(Double.self, forKey: .distance)
        speed = try c.decodeIfPresent(Double.self, forKey: .speed)
        drop = try c.decodeIfPresent(Bool.self, forKey: .drop) ?? false
        done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(weight, forKey: .weight)
        try c.encodeIfPresent(reps, forKey: .reps)
        try c.encodeIfPresent(duration, forKey: .duration)
        try c.encodeIfPresent(intensity, forKey: .intensity)
        try c.encodeIfPresent(distance, forKey: .distance)
        try c.encodeIfPresent(speed, forKey: .speed)
        if drop { try c.encode(true, forKey: .drop) }
        if !done { try c.encode(false, forKey: .done) }
    }
}
