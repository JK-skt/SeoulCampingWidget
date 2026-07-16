import Foundation

#if os(macOS)
/// 외부 크롤러(예: `node crawler/crawl.mjs`)를 서브프로세스로 실행하고,
/// stdout으로 받은 계약 HTML을 `ReservationParser`로 파싱하는 데이터 소스.
///
/// macOS 전용(Foundation.Process). 실행 파일/인자는 주입식이라
/// 테스트에서는 `/bin/sh`로 대체해 파이프라인 전체를 검증할 수 있다.
public struct ProcessCrawlerDataSource: MonthlyDataSource {
    /// 실행할 명령 경로(예: "/usr/bin/env").
    public let launchPath: String
    /// 인자 빌더: (campground, month) → 인자 배열.
    public let argumentsBuilder: @Sendable (Campground, MonthKey) -> [String]
    private let parser: ReservationParsing

    public init(launchPath: String = "/usr/bin/env",
                parser: ReservationParsing = ReservationParser(),
                argumentsBuilder: @escaping @Sendable (Campground, MonthKey) -> [String] = { _, month in
                    // 기본: node crawler/crawl.mjs --month YYYY-MM
                    ["node", "crawler/crawl.mjs", "--month", month.iso]
                }) {
        self.launchPath = launchPath
        self.parser = parser
        self.argumentsBuilder = argumentsBuilder
    }

    public func siteCounts(campground: Campground, month: MonthKey) async throws -> [Campsite: Int] {
        let html = try runProcess(arguments: argumentsBuilder(campground, month))
        return try parser.parseSiteCounts(from: html)
    }

    /// 서브프로세스를 실행하고 stdout 문자열을 반환한다.
    private func runProcess(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            throw ReservationError.network("크롤러 실행 실패: \(error)")
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ReservationError.network("크롤러 종료 코드 \(process.terminationStatus)")
        }
        return String(decoding: data, as: UTF8.self)
    }
}
#endif
