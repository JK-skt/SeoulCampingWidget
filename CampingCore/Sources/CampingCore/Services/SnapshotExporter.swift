import Foundation

/// 스냅샷을 CSV/JSON으로 내보낸다. (프롬프트 요구사항: CSV/JSON/Excel 내보내기)
///
/// Excel(.xlsx)은 별도 라이브러리가 필요하므로, 여기서는 Excel에서 바로 열리는
/// UTF-8 BOM 포함 CSV를 제공한다(한글 깨짐 방지). 순수 .xlsx 생성은 로드맵.
public struct SnapshotExporter: Sendable {
    public init() {}

    /// JSON 직렬화(ISO8601 날짜).
    public func json(_ snapshot: AvailabilitySnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }

    /// CSV 문자열. 열: month,label,site,available
    public func csv(_ snapshot: AvailabilitySnapshot) -> String {
        var rows = ["month,label,site,available"]
        for month in snapshot.months {
            for site in month.sites {
                rows.append("\(month.month.iso),\(escape(month.label)),\(site.site.label),\(site.availableCount)")
            }
        }
        return rows.joined(separator: "\n")
    }

    /// Excel에서 한글이 깨지지 않도록 UTF-8 BOM을 붙인 CSV 데이터.
    public func excelCompatibleCSV(_ snapshot: AvailabilitySnapshot) -> Data {
        let bom = Data([0xEF, 0xBB, 0xBF])
        return bom + Data(csv(snapshot).utf8)
    }

    /// CSV 필드 이스케이프(쉼표/따옴표 포함 시 큰따옴표로 감싼다).
    private func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
