import Foundation

/// Display-only palette shared by Apple widgets and the wallpaper renderer.
/// Category storage and the identifying accent remain unchanged.
enum DailyEventPalette {
  struct Palette {
    let foreground: Int
    let strike: Int
    let background: Int
  }
  private struct Range { let low: Double; let high: Double }
  private static let titleTarget = 4.55
  private static let strikeTarget = 3.05
  private static let linear = (0...255).map { channel -> Double in
    let value = Double(channel) / 255
    return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
  }

  static func resolve(category: Int, background: Int) -> Palette {
    let bg = composite(background, on: 0xffffffff)
    let source = composite(category, on: bg)
    var result = onSurface(source, bg)
    if result == nil {
      let ranges = [Range(low: 0.05, high: 1.05 / (strikeTarget * strikeTarget)),
        Range(low: 0.05 * strikeTarget, high: 1.05 / titleTarget),
        Range(low: 0.05 * titleTarget, high: 1.05 / strikeTarget),
        Range(low: 0.05 * strikeTarget * strikeTarget, high: 1.05)]
      var distance = Double.infinity
      for range in ranges {
        for candidate in coloursInRange(bg, range) {
          guard let palette = onSurface(source, candidate) else { continue }
          let delta = colourDistance(bg, candidate)
          if delta < distance { distance = delta; result = palette }
        }
      }
    }
    guard let palette = result else { preconditionFailure("No accessible event palette") }
    return palette
  }

  static func contrast(_ a: Int, _ b: Int) -> Double {
    max(light(a), light(b)) / min(light(a), light(b))
  }
  private static func light(_ color: Int) -> Double {
    0.2126 * linear[(color >> 16) & 255] + 0.7152 * linear[(color >> 8) & 255] +
      0.0722 * linear[color & 255] + 0.05
  }
  private static func contrastRanges(_ light: Double, _ ratio: Double) -> [Range] {
    [Range(low: 0.05, high: light / ratio), Range(low: light * ratio, high: 1.05)]
  }
  private static func intersections(_ a: [Range], _ b: [Range]) -> [Range] {
    var result = [Range]()
    for x in a {
      for y in b {
        let low = max(0.05, max(x.low, y.low)), high = min(1.05, min(x.high, y.high))
        if low <= high { result.append(Range(low: low, high: high)) }
      }
    }
    return result
  }
  private static func onSurface(_ source: Int, _ background: Int) -> Palette? {
    let b = light(background)
    var withLine = [Range]()
    if b >= 0.05 * strikeTarget { withLine.append(Range(low: 0.05 * strikeTarget, high: 1.05)) }
    if b <= 1.05 / strikeTarget { withLine.append(Range(low: 0.05, high: 1.05 / strikeTarget)) }
    withLine.append(Range(low: 0.05, high: b / (strikeTarget * strikeTarget)))
    withLine.append(Range(low: b * strikeTarget * strikeTarget, high: 1.05))
    var best: Palette?
    var distance = Double.infinity
    for range in intersections(contrastRanges(b, titleTarget), withLine) {
      for ink in coloursInRange(source, range) {
        let delta = colourDistance(source, ink)
        if delta >= distance || contrast(ink, background) < 4.5 { continue }
        guard let line = line(source, ink, background) else { continue }
        best = Palette(foreground: ink, strike: line, background: background)
        distance = delta
        if distance == 0 { return best }
        break
      }
    }
    return best
  }
  private static func line(_ source: Int, _ ink: Int, _ background: Int) -> Int? {
    let a = light(ink), b = light(background)
    var best: Int?
    var score = Double.infinity
    for range in intersections(contrastRanges(a, strikeTarget), contrastRanges(b, strikeTarget)) {
      let preferred = min(range.high, max(range.low, sqrt(a * b)))
      for line in coloursInRange(source, range, preferred: preferred) {
        if contrast(line, ink) < 3 || contrast(line, background) < 3 { continue }
        let l = light(line)
        let outside = l < min(a, b) || l > max(a, b)
        let candidateScore = (outside ? 10.0 : 0.0) + abs(log(l / preferred))
        if candidateScore < score { score = candidateScore; best = line }
        break
      }
    }
    return best
  }
  private static func coloursInRange(_ source: Int, _ range: Range, preferred: Double? = nil) -> [Int] {
    let target = min(range.high, max(range.low, preferred ?? light(source)))
    let center = (range.low + range.high) / 2
    var result = [Int]()
    for step in [0.0, 0.0625, 0.125, 0.25, 0.5, 1.0] {
      let color = withLight(source, target + (center - target) * step)
      if !result.contains(color) { result.append(color) }
    }
    return result
  }
  private static func withLight(_ source: Int, _ target: Double) -> Int {
    if abs(light(source) - target) < 1e-12 { return source }
    let white = target > light(source)
    let r = Double((source >> 16) & 255), g = Double((source >> 8) & 255), b = Double(source & 255)
    let end = white ? 255.0 : 0.0
    var low = 0.0, high = 1.0
    func lightAt(_ t: Double) -> Double {
      0.2126 * linear[Int((r + (end - r) * t).rounded())] +
        0.7152 * linear[Int((g + (end - g) * t).rounded())] +
        0.0722 * linear[Int((b + (end - b) * t).rounded())] + 0.05
    }
    for _ in 0..<20 {
      let mid = (low + high) / 2
      if (lightAt(mid) < target) == white { low = mid } else { high = mid }
    }
    return 0xff000000 | (Int((r + (end - r) * high).rounded()) << 16) |
      (Int((g + (end - g) * high).rounded()) << 8) | Int((b + (end - b) * high).rounded())
  }
  private static func colourDistance(_ a: Int, _ b: Int) -> Double {
    let r = Double((a >> 16) & 255) / 255 - Double((b >> 16) & 255) / 255
    let g = Double((a >> 8) & 255) / 255 - Double((b >> 8) & 255) / 255
    let blue = Double(a & 255) / 255 - Double(b & 255) / 255
    return pow(r, 2) + pow(g, 2) + pow(blue, 2)
  }
  static func blend(_ color: Int, on surface: Int, alpha: Double) -> Int {
    func channel(_ shift: Int) -> Int {
      Int((Double((color >> shift) & 255) * alpha +
        Double((surface >> shift) & 255) * (1 - alpha)).rounded())
    }
    return 0xff000000 | (channel(16) << 16) | (channel(8) << 8) | channel(0)
  }
  private static func composite(_ color: Int, on surface: Int) -> Int {
    blend(color, on: surface, alpha: Double((color >> 24) & 255) / 255)
  }
}
