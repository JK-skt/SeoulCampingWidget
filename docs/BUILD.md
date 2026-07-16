# 빌드 가이드

## 요구사항

- macOS 14 (Sonoma) 이상
- **핵심 로직만**: Swift 6 툴체인(Command Line Tools로 충분)
- **앱/위젯 빌드·실행**: 정식 **Xcode 15+**

## 1. 핵심 로직 (Xcode 없이)

```bash
cd CampingCore
swift build
swift run CampingCoreDemo   # 스모크 테스트
swift test                  # XCTest (XCTest는 정식 Xcode 툴체인 필요)
```

> Command Line Tools에는 XCTest가 없어 `swift test`가 실패할 수 있습니다.
> 이 경우 `swift run CampingCoreDemo`로 로직을 검증하거나, 정식 Xcode 환경에서
> 테스트하세요.

## 2. 앱/위젯 (Xcode)

```bash
open SeoulCampingWidget.xcodeproj
```

### App Group 설정 (필수)

앱과 위젯이 캐시를 공유하려면 두 타깃 모두에 App Group을 설정해야 합니다.

1. 각 타깃 > **Signing & Capabilities**
2. **+ Capability** > **App Groups**
3. `group.com.seoulcamping.widget` 추가 (entitlements와 동일)
4. 팀(Team) 선택 후 자동 서명

### 실행

- 스킴: **SeoulCampingWidget** 선택 → Run
- 메뉴바에 `🏕 A.. B.. C.. D..` 표시
- 위젯: 알림센터/데스크톱에서 위젯 추가 → "난지 캠핑장"

## 3. 프로젝트 재생성 (선택)

`.xcodeproj`가 손상되거나 구조를 바꾸려면 XcodeGen 정본으로 재생성:

```bash
brew install xcodegen
xcodegen generate
```

## 문제 해결

| 증상 | 조치 |
|------|------|
| `no such module 'CampingCore'` | File > Packages > Resolve, 또는 로컬 패키지 경로 확인 |
| 위젯이 데이터 없음 | App Group을 두 타깃에 동일하게 설정했는지 확인 |
| 서명 오류 | Team 선택 후 Automatic signing, 또는 `CODE_SIGNING_ALLOWED=NO`로 빌드 |
