import Foundation

/// A half-open range of minutes within a day.
struct Span: Hashable, Codable {
    var start: Int
    var end: Int

    var length: Int { end - start }
    func overlaps(_ other: Span) -> Bool { start < other.end && other.start < end }
}

enum Scheduling {
    /// The earliest start at or after `earliest` where `length` minutes fit before `dayEnd`
    /// without touching any busy span. Starts are aligned to `grid`.
    static func freeSlot(length: Int, busy: [Span], earliest: Int, dayEnd: Int, grid: Int = 15) -> Int? {
        guard length > 0 else { return nil }
        let sorted = busy.sorted { $0.start < $1.start }
        var t = ceilToGrid(earliest, grid)
        while t + length <= dayEnd {
            let candidate = Span(start: t, end: t + length)
            if let clash = sorted.first(where: { $0.overlaps(candidate) }) {
                t = ceilToGrid(max(clash.end, t + grid), grid)
            } else {
                return t
            }
        }
        return nil
    }

    static func ceilToGrid(_ minutes: Int, _ grid: Int) -> Int {
        guard grid > 0 else { return minutes }
        return ((minutes + grid - 1) / grid) * grid
    }

    struct Placement: Equatable {
        var column: Int
        var columns: Int
    }

    /// Side-by-side layout for overlapping items on a day timeline: every item gets a column,
    /// and each cluster of mutually overlapping items shares a column count.
    static func columns<ID: Hashable>(_ items: [(id: ID, span: Span)]) -> [ID: Placement] {
        let sorted = items.sorted { ($0.span.start, $0.span.end) < ($1.span.start, $1.span.end) }
        var result: [ID: Placement] = [:]
        var cluster: [(id: ID, span: Span, column: Int)] = []
        var clusterEnd = Int.min

        func flush() {
            let count = (cluster.map(\.column).max() ?? 0) + 1
            for item in cluster { result[item.id] = Placement(column: item.column, columns: count) }
            cluster.removeAll()
        }

        for item in sorted {
            if !cluster.isEmpty && item.span.start >= clusterEnd {
                flush()
                clusterEnd = Int.min
            }
            var column = 0
            while cluster.contains(where: { $0.column == column && $0.span.overlaps(item.span) }) { column += 1 }
            cluster.append((item.id, item.span, column))
            clusterEnd = max(clusterEnd, item.span.end)
        }
        flush()
        return result
    }

    /// Total minutes covered by the spans, counting overlaps once.
    static func coveredMinutes(_ spans: [Span]) -> Int {
        var total = 0
        var current: Span?
        for s in spans.sorted(by: { $0.start < $1.start }) {
            if let c = current, s.start <= c.end {
                current = Span(start: c.start, end: max(c.end, s.end))
            } else {
                if let c = current { total += c.length }
                current = s
            }
        }
        if let c = current { total += c.length }
        return total
    }
}
