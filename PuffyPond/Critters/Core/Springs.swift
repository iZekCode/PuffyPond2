import simd

// MARK: - Springs (everything bouncy is a spring)

struct Spring3 {
    var value: SIMD3<Float>
    var velocity: SIMD3<Float> = .zero

    init(_ value: SIMD3<Float>) { self.value = value }

    mutating func step(to target: SIMD3<Float>, stiffness: Float, damping: Float, dt: Float) {
        var remaining = dt
        while remaining > 0 {
            let h = min(remaining, 1.0 / 120.0)
            let a = (target - value) * stiffness - velocity * damping
            velocity += a * h
            value += velocity * h
            remaining -= h
        }
    }
}

struct Spring1 {
    var value: Float
    var velocity: Float = 0

    init(_ value: Float) { self.value = value }

    mutating func step(to target: Float, stiffness: Float, damping: Float, dt: Float) {
        var remaining = dt
        while remaining > 0 {
            let h = min(remaining, 1.0 / 120.0)
            let a = (target - value) * stiffness - velocity * damping
            velocity += a * h
            value += velocity * h
            remaining -= h
        }
    }
}

func smoothStep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
    let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - 2 * t)
}

func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> { a + (b - a) * t }
