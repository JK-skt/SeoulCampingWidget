# 변경 이력

이 프로젝트는 [Semantic Versioning](https://semver.org/lang/ko/)을 따릅니다.

## [0.1.0] - 2026-07-16

### 추가됨 (Added)
- **CampingCore** 순수 로직 패키지
  - 모델: `Campsite`, `Campground`, `MonthKey`, `AvailabilitySnapshot` 등
  - Provider 추상화: `ReservationProvider`, `MockProvider`, `HybridProvider`
  - 데이터 소스: `OpenAPIDataSource`(스텁), `CrawlerDataSource`(Playwright 브리지)
  - `ReservationParser` — `data-site`/`data-available` 계약 기반 HTML 파싱
  - 캐시: `AvailabilityCache` 프로토콜 + 파일/인메모리 구현 (App Group 공유)
  - `ReservationRepository` — 네트워크→캐시→placeholder 폴백
  - `AdaptivePoller` — 평상시 15분 / 오픈 10분 전 1분 / 오픈 중 10초
  - `DateHelper` — 주말·공휴일·연휴 판정, 이번달/다음달 계산
- **메뉴바 앱**(SwiftUI, MVVM): `MenuBarExtra`, 요약/캘린더/설정 화면
- **WidgetKit 위젯**: 이번 달/다음 달 A~D 예약 가능 수
- **NotificationManager**: 예약 가능/변경 로컬 알림 (코어 `AvailabilityDiff` 재사용)
- **AvailabilityDiff**: 스냅샷 비교로 새로 열린 자리 감지 (알림 근거)
- **SnapshotExporter**: CSV / JSON / Excel 호환 CSV(BOM) 내보내기
- **Favorites**: 즐겨찾기 사이트 필터 (`snapshot.filtered(by:)`)
- **HeatmapBuilder**: 주말 히트맵 셀 데이터 + 캘린더 뷰 히트맵
- **적응형 자동 새로고침**: `ReservationViewModel.startAutoRefresh()`가 `AdaptivePoller` 주기 사용
- **★ 난지캠핑장 실연동** (yeyak, 인증키·Playwright 불필요)
  - `YeyakCampingClient`: 캠핑장 카테고리 목록(정적 HTML)에서 svc_id·제목·상태 파싱
  - `YeyakCampingDataSource`: 월·구역별 접수중 캠핑존 집계(순수 매핑 테스트)
  - `NanjiLive` 실행 파일: `swift run NanjiLive`로 난지캠핑장 라이브 조회
  - HybridProvider 기본 primary를 yeyak 난지캠핑장으로 연결
  - 라이브 검증: 난지캠핑장 6개 존(프리/일반 A·B·D형/바비큐/캠프파이어) 전부 접수중
  - `NanjiLive`가 이번달/다음달(7·8월) 구역별 접수중 수를 스냅샷으로 출력 (7월 마감·8월 오픈 실측)
  - `YeyakDetailClient`: 일자별 잔여 좌석 조회 시도(세션 AJAX) — 302 확인, 완전 조회는 Playwright 필요
  - `crawl.mjs`: 캠핑장 카테고리 목록(T500/T502)으로 svc_id 수집하도록 갱신
- **서울 공공예약 실 API 연동** (라이브 호출 검증)
  - `ReservationService`: 실 응답 스키마(SVCNM/SVCSTATNM/RCPTBGNDT 등) 모델
  - `SeoulReservationClient`: 실 엔드포인트 호출·페이징(실키)·JSON 디코딩, `SEOUL_API_KEY` 환경변수 지원
  - `SeoulReservationDataSource`: 접수중 서비스 → 구역별 집계(순수 매핑 함수 테스트)
  - `CampingLive` 실행 파일: `swift run CampingLive`로 실 API 라이브 호출
  - HybridProvider 기본 primary를 서울 실 API로 연결
- **실 연동 스캐폴드**
  - `SeoulOpenAPIDataSource`: 서울 OpenAPI 표준 URL 빌더 + 주입식 디코더
  - `ProcessCrawlerDataSource`: 외부 크롤러(node)를 서브프로세스로 실행→파서 연결 (macOS)
- **App Intents**: `RefreshAvailabilityIntent` + `CampingShortcuts` (Siri/Spotlight/단축어)
- **UpdaterService**: Sparkle 자동 업데이트 seam(현재 no-op)
- **Playwright 크롤러 스텁**(Node)
- Xcode 프로젝트(.xcodeproj) + XcodeGen 정본(project.yml)
- CI(GitHub Actions), SwiftLint/SwiftFormat 설정
- 문서: README, 아키텍처/빌드/릴리스 가이드, 다이어그램

### 검증 (Verified)
- `swift run CampingCoreDemo` — 20개 스모크 테스트 전체 통과
  (Process 크롤러 브리지는 `/bin/sh`로 실제 실행, 서울 API 스키마 매핑 검증)
- `swift run CampingLive` — **실 인증키로 라이브 검증 완료**: 키워드 "난지" 37건(접수중 25),
  "캠핑숲" 7건(접수중 3) 실시간 상태 조회. `SEOUL_KEYWORD`로 키워드 설정 가능.
- **실측 확인**: 난지 오토캠핑장은 공개 API 미제공(1,953건 전수 확인) → yeyak 세션 크롤 필요.
  자세한 내용: [docs/LIVE_FINDINGS.md](docs/LIVE_FINDINGS.md)
- 앱/위젯 소스 `swiftc -typecheck` 통과 (App Intents/Updater 포함, SDK+모듈 대비)
- `project.pbxproj` 24자 ID(63개)/참조 무결성 + plist 문법 검증

### 알려진 제한 (Known limitations)
- 실제 서울 예약 사이트 연동 미완(소스 스펙 미확정) — 현재 Mock 폴백
- 앱/위젯 `.app`/`.appex` 번들 빌드·실행은 정식 Xcode 필요
- `.xcodeproj`는 Xcode에서 열림 검증 미수행(본 환경에 Xcode 없음) — 문제 시 `xcodegen generate`
