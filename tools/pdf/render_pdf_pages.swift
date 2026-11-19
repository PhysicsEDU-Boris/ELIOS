// Renders every page of the given PDFs to PNG (for PR review; decision 0228).
//   swift tools/pdf/render_pdf_pages.swift <out-dir> <file.pdf>...
// Writes <out-dir>/<name>_p<page>.png at 1.5x (893 x 1263 for A4).
import AppKit
import PDFKit

let args = CommandLine.arguments
guard args.count >= 3 else {
  print("usage: render_pdf_pages.swift <out-dir> <file.pdf>...")
  exit(1)
}
let out = URL(fileURLWithPath: args[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let scale: CGFloat = 1.5
for path in args.dropFirst(2) {
  let url = URL(fileURLWithPath: path)
  guard let doc = PDFDocument(url: url) else {
    print("cannot open \(path)")
    exit(1)
  }
  for i in 0..<doc.pageCount {
    let page = doc.page(at: i)!
    let box = page.bounds(for: .mediaBox)
    let w = Int(box.width * scale), h = Int(box.height * scale)
    let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
      samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    ctx.cgContext.setFillColor(NSColor.white.cgColor)
    ctx.cgContext.fill(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.cgContext.scaleBy(x: scale, y: scale)
    page.draw(with: .mediaBox, to: ctx.cgContext)
    ctx.flushGraphics()
    let name = url.deletingPathExtension().lastPathComponent
    try rep.representation(using: .png, properties: [:])!
      .write(to: out.appendingPathComponent("\(name)_p\(i + 1).png"))
  }
  print("\(url.lastPathComponent): \(doc.pageCount) pages")
}
