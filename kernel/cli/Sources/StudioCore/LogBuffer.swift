struct LogBuffer {
  var lines: [String] = []
  var maxLines: Int = 600

  mutating func append(_ line: String) {
    lines.append(line)
    if lines.count > maxLines {
      lines.removeFirst(lines.count - maxLines)
    }
  }

  func window(count: Int, scroll: Int) -> [String] {
    let total = lines.count
    let end = max(0, total - scroll)
    let start = max(0, end - count)
    return Array(lines[start..<end])
  }
}
