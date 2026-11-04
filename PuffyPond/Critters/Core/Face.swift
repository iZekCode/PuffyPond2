// MARK: - Faces

/// How a buddy feels right now. Each mood drives eyes, brows, mouth, cheeks and blush.
enum Mood: Equatable {
    case calm       // pottering along
    case blowing    // concentrating, cheeks puffed, pushing out paint
    case excited    // drawing fast: big sparkly eyes, brows up, wide mouth
    case surprised  // picked a color / bumped a creature: huge eyes, round "O"
    case happy      // finished a line / a creature was born: closed smiling eyes, blush
}

struct Face {
    var eyeScale: Float
    var squint: Float      // 1 = happy closed eyes
    var browLift: Float
    var browTilt: Float    // + angry/determined, - worried
    var mouth: Float       // mouth opening
    var cheeks: Float      // puffed cheeks
    var blush: Float

    static func target(for mood: Mood) -> Face {
        switch mood {
        case .calm: return Face(eyeScale: 1, squint: 0, browLift: 0, browTilt: 0, mouth: 0.9, cheeks: 0, blush: 0.15)
        case .blowing: return Face(eyeScale: 1.08, squint: 0, browLift: -0.4, browTilt: 0.45, mouth: 1.5, cheeks: 1, blush: 0.45)
        case .excited: return Face(eyeScale: 1.28, squint: 0, browLift: 0.8, browTilt: -0.15, mouth: 1.7, cheeks: 0.4, blush: 0.7)
        case .surprised: return Face(eyeScale: 1.45, squint: 0, browLift: 1.2, browTilt: -0.3, mouth: 2.0, cheeks: 0, blush: 0.3)
        case .happy: return Face(eyeScale: 1, squint: 1, browLift: 0.5, browTilt: -0.2, mouth: 1.1, cheeks: 0.2, blush: 0.9)
        }
    }

    static func mix(_ a: Face, _ b: Face, _ t: Float) -> Face {
        Face(eyeScale: a.eyeScale + (b.eyeScale - a.eyeScale) * t,
             squint: a.squint + (b.squint - a.squint) * t,
             browLift: a.browLift + (b.browLift - a.browLift) * t,
             browTilt: a.browTilt + (b.browTilt - a.browTilt) * t,
             mouth: a.mouth + (b.mouth - a.mouth) * t,
             cheeks: a.cheeks + (b.cheeks - a.cheeks) * t,
             blush: a.blush + (b.blush - a.blush) * t)
    }
}
