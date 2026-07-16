import Foundation
import CampingCore

/// 자동 업데이트 서비스 추상화. (프롬프트 요구사항: Sparkle 자동 업데이트)
///
/// 실제 Sparkle 통합은 SPM 의존성 + EdDSA 서명 키 + appcast 호스팅이 필요하므로,
/// 여기서는 프로토콜과 no-op 기본 구현만 두어 UI/설정이 이 seam에 의존하도록 한다.
/// Sparkle 도입 시 `SparkleUpdaterService`를 추가해 교체하면 된다.
public protocol UpdaterService: Sendable {
    /// 사용자가 명시적으로 "업데이트 확인"을 눌렀을 때.
    func checkForUpdates()
    /// 백그라운드 자동 확인 활성화 여부.
    var automaticallyChecksForUpdates: Bool { get set }
}

/// 기본 no-op 구현. Sparkle 미도입 상태에서도 앱이 컴파일·동작한다.
public final class NoopUpdaterService: UpdaterService, @unchecked Sendable {
    public var automaticallyChecksForUpdates: Bool = false
    public init() {}
    public func checkForUpdates() {
        Log.app.info("업데이트 확인: Sparkle 미도입(no-op). RELEASE.md의 로드맵 참고.")
    }
}

/*
 Sparkle 도입 절차(요약, docs/RELEASE.md 참고):
   1. SPM: https://github.com/sparkle-project/Sparkle 추가
   2. SparkleUpdaterService: UpdaterService 구현 (SPUStandardUpdaterController 래핑)
   3. Info.plist: SUFeedURL, SUPublicEDKey 설정
   4. CI: 릴리스 시 서명된 zip + appcast.xml 자동 갱신
*/
