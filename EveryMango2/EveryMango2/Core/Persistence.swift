import Foundation
import Observation

enum Persistence {
    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }

    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    static func load(from url: URL) throws -> Snapshot {
        try decoder().decode(Snapshot.self, from: Data(contentsOf: url))
    }

    static func save(_ snapshot: Snapshot, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder().encode(snapshot).write(to: url, options: .atomic)
    }
}

/// Calls `onChange` once after any persisted part of the store changes, then re-arms itself.
/// The app uses it to save without every mutation having to remember to.
final class StoreObserver {
    private let store: MangoStore
    private let onChange: () -> Void
    private var active = true

    init(store: MangoStore, onChange: @escaping () -> Void) {
        self.store = store
        self.onChange = onChange
        arm()
    }

    func stop() { active = false }

    private func arm() {
        withObservationTracking {
            _ = store.snapshot
        } onChange: {
            // Fires before the change lands; hop to the next main-queue turn to see the new value.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.active else { return }
                self.onChange()
                self.arm()
            }
        }
    }
}
