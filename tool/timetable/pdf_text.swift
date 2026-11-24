// Write the text of each PDF next to it as <file>.txt, using macOS PDFKit.
// Usage: swift pdf_text.swift <pdf> [<pdf> ...]
import PDFKit

for path in CommandLine.arguments.dropFirst() {
  guard let doc = PDFDocument(url: URL(fileURLWithPath: path)) else {
    FileHandle.standardError.write("unreadable: \(path)\n".data(using: .utf8)!)
    continue
  }
  var pages: [String] = []
  for i in 0..<doc.pageCount {
    pages.append(doc.page(at: i)?.string ?? "")
  }
  try pages.joined(separator: "\n").write(
    toFile: path + ".txt", atomically: true, encoding: .utf8)
}
