// Dump text lines of the official Daegu timetable PDF, cut into vertical strips.
// Usage: swift daegu_pdf_columns.swift <pdf> <out.json> <firstPage> <lastPage> <x0,x1,...>
// Each strip is selected separately, so a line never spans two table columns.
// Passing "0,600" yields whole page lines (titles and table notes).
import PDFKit

let args = CommandLine.arguments
guard args.count == 6, let doc = PDFDocument(url: URL(fileURLWithPath: args[1])),
  let first = Int(args[3]), let last = Int(args[4])
else {
  FileHandle.standardError.write("usage: <pdf> <out.json> <first> <last> <edges>\n".data(using: .utf8)!)
  exit(2)
}
let edges = args[5].split(separator: ",").map { Double($0)! }
var pages: [[String: Any]] = []
for i in (first - 1)..<last {
  guard let page = doc.page(at: i) else { continue }
  let box = page.bounds(for: .mediaBox)
  var lines: [[Any]] = []
  for c in 0..<(edges.count - 1) {
    let rect = CGRect(x: edges[c], y: 0, width: edges[c + 1] - edges[c], height: box.height)
    guard let selection = page.selection(for: rect) else { continue }
    for line in selection.selectionsByLine() {
      let r = line.bounds(for: page)
      // y is measured from the page top: [text, x0, top, x1, bottom, column]
      lines.append([line.string ?? "", Double(r.minX), Double(box.height - r.maxY), Double(r.maxX), Double(box.height - r.minY), c])
    }
  }
  pages.append(["page": i + 1, "lines": lines])
}
try! JSONSerialization.data(withJSONObject: pages).write(to: URL(fileURLWithPath: args[2]))
print(pages.count)
