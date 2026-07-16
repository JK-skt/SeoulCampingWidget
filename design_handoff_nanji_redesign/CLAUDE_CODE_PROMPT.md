# Claude Code 실행 명령어

아래 내용을 프로젝트 루트(`SeoulCampingWidget/`)에서 Claude Code에 그대로 붙여넣으세요.
먼저 이 `design_handoff_nanji_redesign/` 폴더를 프로젝트 루트에 복사해 두세요.

---

## 붙여넣을 프롬프트

```
난지캠핑장 예약 현황 앱의 UI/UX를 전면 리디자인한다.
디자인 레퍼런스와 상세 스펙은 `design_handoff_nanji_redesign/` 폴더에 있다.
먼저 `design_handoff_nanji_redesign/README.md`를 정독하고,
`난지캠핑장 리디자인.dc.html`을 브라우저로 열어 의도한 룩앤필을 확인하라.

## 원칙 (반드시 준수)
1. HTML/CSS를 복사하지 말 것. README의 명세를 기존 SwiftUI 코드베이스의 패턴으로 재현하라.
2. 기존 예약 조회·파싱·자동갱신·캐시·오류 처리 로직(CampViewModel, YeyakClient,
   CalendarStore, CampService, CalendarData)을 절대 훼손하지 않는다.
3. 샘플 데이터로 대체하지 않는다. 실제 데이터 계층에 연결된 상태로 동작해야 한다.
4. 색상은 하드코딩하지 말고 시맨틱 컬러 토큰(Asset Catalog 또는 Color 확장)으로 정의한다.
   README "Design Tokens" 표의 값을 macOS 시스템 컬러에 매핑한다.
5. 상태는 색상만으로 구분하지 말고 텍스트(여유/임박/마감)+기호(● ▲ —)를 병기한다.
6. 잔여 수량·날짜 숫자에는 .monospacedDigit()을 적용한다.
7. 아이콘은 SF Symbols를 사용한다(README "Assets" 목록 참고).
8. 접근성: VoiceOver 라벨/값, 키보드 탐색, Reduce Motion, Increased Contrast를 지원한다.
9. 메뉴바·메인 앱·위젯이 단일 데이터 소스(App Group 캐시)를 공유하고 중복 요청하지 않는다.

## 작업 전
저장소 전체 구조와 데이터 흐름을 먼저 분석하고, 다음을 출력하라:
(1) 현재 구조 요약 (2) 수정 대상 파일 목록 (3) 개선 계획 (4) 회귀 위험 요소.
그 후 승인 없이 바로 구현하지 말고 계획을 보여준 뒤 진행하라.

## 구현 순서 (단계마다 빌드/타입체크로 검증)
Phase 1. 디자인 시스템: 시맨틱 컬러 토큰 + 타이포 확장 + 상태 판정 헬퍼
        (statusOf(total): 0=마감/1~10=임박/>10=여유) + 공통 컴포넌트
        (AvailabilityBadge, SiteAvailabilityChip, DateAvailabilityCell,
         AvailabilitySummaryCard, RefreshStatusView, EmptyStateView, ErrorStateView,
         LoadingSkeleton, FilterChip, LegendView, WeekendAvailabilityRow).
Phase 2. 메인 앱(ContentView/CalendarView): 툴바 → 컨트롤 행(보기 전환/필터/범례)
        → 요약 카드 5종 → 2개월 달력(금·토 강조, A/B/C/D 칩, 오늘/과거/선택 상태)
        → 우측 상세 인스펙터. 주말 목록 보기 추가.
Phase 3. 메뉴바(App.swift PopoverView): Control Center 스타일 팝오버 + 상태별 라벨 아이콘.
Phase 4. 위젯(CampingWidget.swift): Small/Medium/Large 3종.
Phase 5. 설정(SettingsView): System Settings 스타일 그룹 리스트.
Phase 6. 상태 화면: 로딩 스켈레톤/오류(캐시)/빈데이터/전체마감.

## 완료 조건
- 오류 없이 빌드된다. 기존 예약 조회 기능이 그대로 동작한다.
- 이번달/다음달 데이터가 정상 표시되고 금·토 빈자리를 빠르게 찾을 수 있다.
- 메뉴바·메인 앱·위젯 데이터가 일치한다.
- Light/Dark 모두 가독성이 확보된다. 작은 창/큰 창에서 레이아웃이 안 깨진다.
- 로딩/오류/빈데이터/오래된 데이터 상태가 구분된다.
- 접근성 라벨과 키보드 탐색이 적용된다.

각 Phase가 끝날 때마다 무엇을/왜 바꿨는지, 어떤 HIG 원칙을 따랐는지 요약하라.
```

---

## 참고
- `난지캠핑장 리디자인.dc.html`은 Design Component 형식이라 `support.js`, `camp_data.json`과 같은 폴더에 있어야 브라우저에서 정상 렌더됩니다(폰트/디자인시스템 리소스는 CDN·선택 사항).
- 스크린샷이 함께 필요하면 알려주세요 — 5개 화면 이미지를 이 폴더에 추가해 드립니다.
