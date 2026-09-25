import Foundation

@main
struct EventPaletteTest {
  static func main() throws {
    let fixture = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "tool/tests/fixtures/event_palette.json")
    let data = try JSONSerialization.jsonObject(with: Data(contentsOf: fixture)) as! [String: Any]
    let cases = data["cases"] as! [[Int]]
    for (index, row) in cases.enumerated() {
      let value = DailyEventPalette.resolve(category: row[0], background: row[1])
      precondition([value.foreground, value.strike, value.background] == Array(row[2...4]),
        "Dart parity mismatch at fixture \(index): \(value)")
    }
    // Independent WCAG evaluator checks final 8-bit colours, not solver internals.
    let linear = (0...255).map { c -> Double in
      let v = Double(c) / 255
      return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }
    func contrast(_ a: Int, _ b: Int) -> Double {
      func luminance(_ c: Int) -> Double {
        0.2126 * linear[(c >> 16) & 255] + 0.7152 * linear[(c >> 8) & 255] +
          0.0722 * linear[c & 255] + 0.05
      }
      return max(luminance(a), luminance(b)) / min(luminance(a), luminance(b))
    }
    let values = Array(stride(from: 0, through: 250, by: 10)) + [255]
    // Both appearances for widget labels, month strips and wallpaper strips.
    let surfaces = [(0xff000000, 0.0), (0xffffffff, 0.0),
      (0xff000000, 0.18), (0xffffffff, 0.18),
      (0xff000000, 0.22), (0xffffffff, 0.12)]
    var minimumTitle = 21.0, minimumLineInk = 21.0, minimumLineBackground = 21.0
    var count = 0
    for r in values { for g in values { for b in values {
      let category = 0xff000000 | (r << 16) | (g << 8) | b
      for (surface, alpha) in surfaces {
        let background = DailyEventPalette.blend(category, on: surface, alpha: alpha)
        let palette = DailyEventPalette.resolve(category: category, background: background)
        let title = contrast(palette.foreground, palette.background)
        let lineInk = contrast(palette.strike, palette.foreground)
        let lineBackground = contrast(palette.strike, palette.background)
        precondition(title >= 4.5 && lineInk >= 3 && lineBackground >= 3,
          "Inaccessible palette for \(category)/\(surface)/\(alpha)")
        minimumTitle = min(minimumTitle, title)
        minimumLineInk = min(minimumLineInk, lineInk)
        minimumLineBackground = min(minimumLineBackground, lineBackground)
        count += 1
      }
    } } }
    print("Swift: \(cases.count) Dart fixtures; \(count) RGB/surface cases; minimum title/background=\(minimumTitle), line/title=\(minimumLineInk), line/background=\(minimumLineBackground)")
  }
}
