import Foundation

/// 스냅샷 로컬 캐시 추상화.
///
/// 프롬프트는 SQLite/SwiftData를 언급하지만, 순수 로직 테스트를 위해
/// 코어에서는 프로토콜로만 정의하고 기본 구현은 JSON 파일 캐시를 제공한다.
/// 앱 계층에서 SwiftData 구현으로 교체할 수 있다.
public protocol AvailabilityCache: Sendable {
    func load(campground: Campground) throws -> AvailabilitySnapshot?
    func save(_ snapshot: AvailabilitySnapshot) throws
}

/// JSON 파일 기반 캐시. App Group 컨테이너 경로를 주입하면
/// 앱과 위젯 익스텐션이 동일 캐시를 공유할 수 있다.
public struct FileAvailabilityCache: AvailabilityCache {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// FileManager는 Sendable이 아니므로 저장하지 않고 호출 시점에 default를 사용한다.
    private var fileManager: FileManager { .default }

    private func url(for campground: Campground) -> URL {
        directory.appendingPathComponent("snapshot-\(campground.rawValue).json")
    }

    public func load(campground: Campground) throws -> AvailabilitySnapshot? {
        let fileURL = url(for: campground)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AvailabilitySnapshot.self, from: data)
    }

    public func save(_ snapshot: AvailabilitySnapshot) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: url(for: snapshot.campground), options: .atomic)
    }
}

/// 인메모리 캐시(테스트/미리보기용).
public final class InMemoryCache: AvailabilityCache, @unchecked Sendable {
    private var storage: [Campground: AvailabilitySnapshot] = [:]
    private let lock = NSLock()
    public init() {}

    public func load(campground: Campground) throws -> AvailabilitySnapshot? {
        lock.lock(); defer { lock.unlock() }
        return storage[campground]
    }

    public func save(_ snapshot: AvailabilitySnapshot) throws {
        lock.lock(); defer { lock.unlock() }
        storage[snapshot.campground] = snapshot
    }
}
