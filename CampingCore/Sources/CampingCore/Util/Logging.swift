import Foundation

#if canImport(os)
import os

/// OSLog 기반 통합 로거. (프롬프트 요구사항: OSLog 사용)
public enum Log {
    private static let subsystem = "com.seoulcamping.widget"

    public static let network = Logger(subsystem: subsystem, category: "network")
    public static let parser  = Logger(subsystem: subsystem, category: "parser")
    public static let cache   = Logger(subsystem: subsystem, category: "cache")
    public static let scheduler = Logger(subsystem: subsystem, category: "scheduler")
    public static let app     = Logger(subsystem: subsystem, category: "app")
}
#else
/// os를 쓸 수 없는 플랫폼용 최소 대체 구현.
public enum Log {
    public struct Shim: Sendable {
        public func debug(_ msg: String) {}
        public func info(_ msg: String) {}
        public func error(_ msg: String) {}
    }
    public static let network = Shim()
    public static let parser = Shim()
    public static let cache = Shim()
    public static let scheduler = Shim()
    public static let app = Shim()
}
#endif
