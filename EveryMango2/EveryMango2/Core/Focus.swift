import Foundation

/// The focus timer's shape, edited like an envelope generator: Focus, Break, Rounds, Long break.
struct FocusPlan: Codable, Hashable {
    var focusMinutes = 25
    var breakMinutes = 5
    var rounds = 4
    var longBreakMinutes = 15

    enum Kind: String, Codable { case focus, rest, longRest }

    struct Phase: Hashable {
        var kind: Kind
        var seconds: Int
        var round: Int
    }

    /// Focus and break alternate for `rounds` rounds; the last break is the long one.
    var phases: [Phase] {
        var out: [Phase] = []
        let n = max(1, rounds)
        for r in 1...n {
            out.append(Phase(kind: .focus, seconds: max(1, focusMinutes) * 60, round: r))
            if r < n {
                out.append(Phase(kind: .rest, seconds: max(1, breakMinutes) * 60, round: r))
            } else {
                out.append(Phase(kind: .longRest, seconds: max(1, longBreakMinutes) * 60, round: r))
            }
        }
        return out
    }

    var totalSeconds: Int { phases.reduce(0) { $0 + $1.seconds } }

    /// Points (x: 0...1 across the cycle, y: 0...1 level) tracing the cycle as an envelope:
    /// level rises for focus and falls for breaks.
    var envelope: [(x: Double, y: Double)] {
        let total = Double(max(1, totalSeconds))
        var points: [(x: Double, y: Double)] = [(0, 0)]
        var t = 0.0
        for p in phases {
            let ramp = min(Double(p.seconds) * 0.12, 90)
            switch p.kind {
            case .focus:
                points.append(((t + ramp) / total, 1))
                points.append(((t + Double(p.seconds)) / total, 1))
            case .rest:
                points.append(((t + ramp) / total, 0.25))
                points.append(((t + Double(p.seconds)) / total, 0.25))
            case .longRest:
                points.append(((t + Double(p.seconds)) / total, 0))
            }
            t += Double(p.seconds)
        }
        return points
    }
}

/// A running (or paused) focus session. Stored as timestamps so it survives the app being closed.
struct FocusRun: Codable, Hashable {
    var plan: FocusPlan
    var startedAt: Date
    var pausedAt: Date?
    var pausedSeconds: Double = 0
    var taskID: UUID?
    var title: String = ""
    /// Focus phases already credited to the task.
    var credited = 0

    struct Position: Equatable {
        var index: Int
        var phase: FocusPlan.Phase
        var remaining: Int
        /// 0...1 through the whole cycle.
        var progress: Double
        var finished: Bool
    }

    var isPaused: Bool { pausedAt != nil }

    func elapsed(at now: Date) -> Double {
        let end = pausedAt ?? now
        return max(0, end.timeIntervalSince(startedAt) - pausedSeconds)
    }

    func position(at now: Date) -> Position {
        let phases = plan.phases
        let total = Double(plan.totalSeconds)
        let e = elapsed(at: now)
        var t = 0.0
        for (i, p) in phases.enumerated() {
            let end = t + Double(p.seconds)
            if e < end {
                return Position(index: i, phase: p, remaining: Int((end - e).rounded(.up)),
                                progress: min(1, e / total), finished: false)
            }
            t = end
        }
        let last = phases[phases.count - 1]
        return Position(index: phases.count - 1, phase: last, remaining: 0, progress: 1, finished: true)
    }

    /// Focus phases fully completed by `now`.
    func completedFocusPhases(at now: Date) -> Int {
        let e = elapsed(at: now)
        var t = 0.0
        var count = 0
        for p in plan.phases {
            t += Double(p.seconds)
            if e >= t && p.kind == .focus { count += 1 }
        }
        return count
    }

    /// When each remaining phase will end, for scheduling notifications.
    func upcomingPhaseEnds(after now: Date) -> [(date: Date, finishing: FocusPlan.Phase)] {
        guard pausedAt == nil else { return [] }
        var out: [(date: Date, finishing: FocusPlan.Phase)] = []
        var t = 0.0
        for p in plan.phases {
            t += Double(p.seconds)
            let date = startedAt.addingTimeInterval(t + pausedSeconds)
            if date > now { out.append((date, p)) }
        }
        return out
    }

    mutating func pause(at now: Date) {
        if pausedAt == nil { pausedAt = now }
    }

    mutating func resume(at now: Date) {
        if let p = pausedAt {
            pausedSeconds += now.timeIntervalSince(p)
            pausedAt = nil
        }
    }

    /// Jump to the start of the next phase.
    mutating func skip(at now: Date) {
        let pos = position(at: now)
        guard !pos.finished else { return }
        startedAt = startedAt.addingTimeInterval(-Double(pos.remaining))
    }
}
