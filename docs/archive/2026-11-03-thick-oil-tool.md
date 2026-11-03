# Thick oil tool (removed from the fist scheme)

On 2026-11-03 the thick oil tool and its snail were taken out of the five-tool column. The snail stays in the app as the **blender**; this note keeps what the thick oil tool was, so it can be put back.

## What it was

- Tool name "Thick oil", SF symbol `rectangle.portrait.fill`, first in the tool column, carried by the snail.
- It laid heavy impasto: a wide, knife-like sheet piled high with ridged edges.
- Paint came from `PaintTool.dabs`, not from the critter. The critter only gave the character and its motion.

## The code that was removed (`PuffyPond/Canvas/PaintTool.swift`)

```swift
enum PaintTool: Int, CaseIterable, Equatable {
    case thickOil, liquidOil, brush, eraser, blender   // thickOil was first

    var name: String { case .thickOil: return "Thick oil" ... }
    var symbol: String { case .thickOil: return "rectangle.portrait.fill" ... }
    var critterKind: CritterKind? { case .thickOil: return .snail ... }

    func dabs(from a: SIMD2<Float>, to b: SIMD2<Float>, radius: Float, speed: Float) -> [BrushDab] {
        let d = b - a
        let moving = smoothStep(0.002, 0.02, simd_length(d))
        switch self {
        case .thickOil:
            // Heavy impasto: a wide knife-like sheet, piled high with ridged edges.
            let angle = simd_length(d) > 1e-5 ? atan2(d.y, d.x) + Float.pi / 2 : Float.pi / 2
            var style = BrushStyle(push: 0.9, bristles: 0.4, nibAngle: angle, nibAspect: 1.4, knife: 0.6, impasto: 1)
            style.amount = 0.08 + 0.4 * moving
            return [BrushDab(from: a, to: b, radius: radius * 1.5, speed: speed, style: style)]
        ...
```

The test that went with it (`ControlSchemeTests.fistPaintsWithCurrentTool`):

```swift
let thick = PaintTool.thickOil.dabs(from: a, to: b, radius: 0.085, speed: 1)
#expect(thick.allSatisfy { $0.style.impasto > 0 })
```

## What stayed

- `BrushStyle`'s `impasto`, `knife`, `nibAngle` and `nibAspect` fields, and the Metal impasto and knife shading in `PaintLayer.swift` and `PaintShaders.metal`: the legacy snail (palette knife) still uses them.
- `Snail.swift` as it is.

## To put it back

1. Add `thickOil` to `PaintTool` with the name, symbol, `critterKind` and `dabs` branch above.
2. Give it a critter (the snail is now the blender, so it needs another one) and add that critter to `CritterKind.gardenCast` in tool-column order.
3. Restore the test, and the thick-oil line in the HUD tool row and the README table.
