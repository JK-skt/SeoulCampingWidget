# 서울 캠핑 위젯 (Seoul Camping Widget)

난지 캠핑장(A/B/C/D 구역)의 **금·토 예약 가능 현황**을 모니터링하는
macOS 네이티브 앱(메뉴바 + WidgetKit).

> **상태: MVP 골격 (v0.1.0)** — 핵심 아키텍처와 로직이 동작하며,
> 실제 데이터 소스는 추상화된 seam 뒤에 mock으로 연결되어 있습니다.
> 원본 요구사항 대비 구현 범위는 [로드맵](#로드맵)을 참고하세요.

## 무엇이 되나요

- ✅ **CampingCore**: 순수 Swift 로직(모델·Provider·파서·캐시·저장소·적응형 폴러) — **테스트 통과, 실행 검증 완료**
- ✅ **메뉴바 앱**: `MenuBarExtra` 기반 상주 앱, `🏕 A3 B2 C1 D4` 요약 표시
- ✅ **WidgetKit 위젯**: 이번 달/다음 달 A~D 예약 가능 수
- ✅ **하이브리드 데이터 수집**: OpenAPI → 크롤러 → Mock 폴백 (실패해도 UI가 항상 렌더)
- ✅ **Playwright 크롤러 스텁**: 파서 계약(`data-site`/`data-available`) 기반
- ⏳ 실제 서울 예약 사이트 연동, 알림 트리거, 캘린더/히트맵, Sparkle 자동 업데이트 등 → 로드맵

## 빠른 시작

### 1) 핵심 로직 검증 (정식 Xcode 불필요)

```bash
cd CampingCore
swift run CampingCoreDemo   # 스모크 테스트: 17개 검증 항목 전부 통과
swift test                  # XCTest (정식 Xcode/CI 필요)
```

> 참고: 앱/위젯 소스도 SDK 대비 `swiftc -typecheck`로 검증되었습니다
> (자세한 내용은 [docs/BUILD.md](docs/BUILD.md)). 다만 `.app`/`.appex` 번들
> 빌드와 실행에는 정식 Xcode가 필요합니다.

### 2) 앱/위젯 실행 (정식 Xcode 필요)

```bash
open SeoulCampingWidget.xcodeproj
```

Xcode에서 **Signing & Capabilities** > App Group `group.com.seoulcamping.widget`을
App/Widget 두 타깃에 설정한 뒤 실행하세요. 자세한 절차는
[docs/BUILD.md](docs/BUILD.md).

## 프로젝트 구조

```
SeoulCampingWidget/
├── CampingCore/        # 순수 로직 SwiftPM 패키지 (앱·위젯 공유, 여기서 테스트)
│   ├── Sources/CampingCore/   {Models, Providers, Services, Scheduler, Util}
│   ├── Sources/CampingCoreDemo/  # 스모크 테스트 실행 파일
│   └── Tests/CampingCoreTests/   # XCTest
├── App/                # 메뉴바 앱 타깃 (SwiftUI, MVVM)
├── Widget/             # WidgetKit 익스텐션 타깃
├── crawler/            # Playwright 크롤러 (Node, 스텁)
├── docs/               # 아키텍처/빌드/릴리스 문서 + 다이어그램
├── SeoulCampingWidget.xcodeproj
└── project.yml         # XcodeGen 정본(프로젝트 재생성용)
```

## 아키텍처 한눈에

```
UI(메뉴바/위젯) → ReservationViewModel → ReservationRepository
                                              ├── ReservationProvider (Hybrid)
                                              │     ├── OpenAPIDataSource   (스텁)
                                              │     ├── CrawlerDataSource   (Playwright 브리지)
                                              │     │     └── ReservationParser
                                              │     └── MockProvider (폴백)
                                              └── AvailabilityCache (App Group 공유 파일 캐시)
```

핵심 설계 원칙: **실제 데이터 소스를 몰라도 앱 전체가 컴파일·실행·테스트되도록**
모든 외부 의존을 프로토콜 뒤로 숨기고 Mock 폴백을 둔다. 자세한 내용은
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## 로드맵

| 구분 | 상태 |
|------|------|
| 핵심 모델/저장소/파서/폴러 | ✅ 구현·검증 |
| 메뉴바 앱 / 위젯 UI | ✅ 골격 |
| 하이브리드 Provider (API→크롤러→Mock) | ✅ 구조 완성, 실소스 미연결 |
| 실 연동 스캐폴드 (OpenAPI URL 빌더 + Process 크롤러 브리지) | ✅ 구현·검증 (실 서비스명/디코더만 ⏳) |
| App Intents / Siri / Spotlight | ✅ 스캐폴드 (새로고침 인텐트+단축어) |
| Sparkle 자동 업데이트 | ⏳ seam(UpdaterService)만 — SPM/서명 도입 남음 |
| 알림 트리거(변화 감지 diff) + 적응형 자동 새로고침 | ✅ 구현·검증 |
| 주말 히트맵 데이터/뷰 | ✅ 구현 (일자별 실데이터는 ⏳) |
| 즐겨찾기 사이트 필터 | ✅ 구현·검증 |
| 공휴일·연휴 판정 | ✅ 양력 고정 공휴일 (음력은 ⏳) |
| CSV/JSON 내보내기 | ✅ 구현·검증 (Excel 호환 CSV 포함, .xlsx는 ⏳) |
| 스파크라인 / 예약 확률 예측 / 취소 패턴 | ⏳ |
| 스냅샷/UI 테스트, DocC | ⏳ |

## 라이선스

미정.
