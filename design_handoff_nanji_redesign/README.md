# Handoff: 난지캠핑장 예약 현황 앱 — Apple 네이티브 다크 리디자인

## Overview
난지캠핑장(A/B/C/D + 프리/바비큐/캠프파이어) 금·토 예약 가능 현황을 조회하는 macOS 메뉴바 앱 + WidgetKit 위젯의 UI/UX 전면 리디자인이다. macOS Human Interface Guidelines를 따르는 **다크 모드** 디자인으로, 사용자가 3초 안에 "가장 가까운 예약 가능한 금·토 + 총 잔여 + A/B/C/D 잔여"를 파악하도록 정보 구조를 재설계했다.

대상 화면: 메인 앱 창 · 메뉴바 팝오버 · 위젯(S/M/L) · 설정 · 상태(로딩/오류/빈데이터/마감).

## About the Design Files
이 번들의 `난지캠핑장 리디자인.dc.html`은 **HTML로 만든 디자인 레퍼런스(프로토타입)** 이다. 그대로 이식하는 코드가 아니라, **의도한 룩앤필과 동작을 보여주는 시각 스펙**이다.

작업 목표는 이 HTML 디자인을 **기존 SwiftUI 코드베이스(`SeoulCampingWidget`)의 패턴·프레임워크로 재현**하는 것이다. HTML/CSS를 복사하지 말고, 아래 명세된 레이아웃·색상·타이포·상태를 SwiftUI View로 구현하라. 기존 데이터 계층(`CampViewModel`, `YeyakClient`, `CalendarStore`, `CampService`, `CalendarData`)과 예약 조회/파싱/자동갱신/캐시 로직은 **절대 훼손하지 않는다.**

## Fidelity
**High-fidelity (hifi)** — 최종 색상·타이포·간격·인터랙션이 확정된 목업이다. 색상값과 크기를 그대로 SwiftUI 시맨틱 컬러/폰트 토큰으로 옮겨 픽셀에 가깝게 재현하라. (단, 하드코딩 대신 아래 "Design Tokens"를 `Color`/`Font` 확장 또는 Asset Catalog 시맨틱 컬러로 정의해 사용.)

---

## Design Tokens

색상은 하드코딩하지 말고 시맨틱 토큰으로 정의한다(Asset Catalog 또는 `Color` 확장). 다크 모드 기준값 + 라이트 대응값은 macOS 시스템 컬러(`Color(nsColor:)`)에 매핑 권장.

### 색상 (다크 기준값)
| 토큰 | HEX | 용도 | 시스템 매핑 권장 |
|---|---|---|---|
| `availabilityHigh` (여유) | `#30d158` | 잔여 넉넉 | `.green` (systemGreen) |
| `availabilityMedium`/`Low` (임박) | `#ff9f0a` | 잔여 1~10 / 사이트 1~3 | `.orange` (systemOrange) |
| `availabilityClosed` (마감) | `#8e8e93` | 잔여 0 | `.secondary` / systemGray |
| `error` | `#ff453a` | 오류·일요일 | `.red` (systemRed) |
| `weekendFriday` | `#0a84ff` | 금요일 강조 | `.blue` (systemBlue) |
| `weekendSaturday` | `#30d158` | 토요일 강조 | systemGreen |
| `accent` (기본) | `#0a84ff` | 주요 버튼·선택 | `.accentColor` |
| `bg-window` | `#232326` | 창 배경 | `Color(nsColor: .windowBackgroundColor)` |
| `bg-elevated` | `#2c2c30` | 툴바 버튼·토글 | `.controlBackgroundColor` |
| `bg-card` | `#2a2a2e` | 카드 | `.underPageBackgroundColor` |
| `separator` | `rgba(255,255,255,0.09)` | 구분선 | `.separatorColor` |
| `separator-strong` | `rgba(255,255,255,0.16)` | 강조 구분 | — |
| `text-primary` | `#f5f5f7` | 본문 | `.labelColor` |
| `text-secondary` | `rgba(235,235,245,0.62)` | 보조 | `.secondaryLabelColor` |
| `text-tertiary` | `rgba(235,235,245,0.38)` | 캡션 | `.tertiaryLabelColor` |

색상 배경 tint는 해당 색 `opacity(0.12~0.16)`, 테두리는 `opacity(0.24~0.30)`.

### 타이포그래피 (시스템 폰트 + 한글 Pretendard/SF)
잔여 수량·날짜 숫자는 반드시 `.monospacedDigit()` 적용.
| 계층 | size / weight | SwiftUI |
|---|---|---|
| 화면 제목(앱명) | 15 / bold | `.headline` |
| 월 제목 | 16 / bold | `.title3.bold()` |
| 날짜 숫자(달력) | 12 / bold | `.caption.bold().monospacedDigit()` |
| 총 잔여(상세) | 30 / heavy | `.system(size:30,weight:.heavy).monospacedDigit()` |
| 요약 카드 큰 수 | 26 / bold | `.title.bold().monospacedDigit()` |
| 사이트 코드 | 10~12 / semibold | `.caption2` |
| 사이트별 수량(칩) | 9.5~15 / bold | `.monospacedDigit()` |
| 보조 설명 | 12~13 / regular | `.subheadline`/`.footnote` |
| 갱신 시간 | 11~12 / regular | `.caption2` |
| 오류 문구 | 13.5 / bold + 12 본문 | `.callout.bold()` |

### 간격 · 모양
- 카드 radius `12`, 창/큰 컨테이너 `16`, 위젯 `22`, 칩 `5~8`, 버튼 `9~10`.
- 카드 padding `14`, 창 본문 `18`, 위젯 `16~18`.
- 상태 dot: 원형, 7~9px, `box-shadow 0 0 0 3px <color>/0.22` glow(선택).
- 그림자: `0 30px 60px -20px rgba(0,0,0,0.6)` (창), `0 20px 40px -14px rgba(0,0,0,0.6)` (위젯). SwiftUI `.shadow` 근사.

### 상태 판정 로직 (색상만으로 구분 금지 — 텍스트+기호 병기)
- 총 잔여 `total == 0` → **마감**, 회색, 기호 `—`
- `1 ≤ total ≤ 10` → **임박**, 주황, 기호 `▲`
- `total > 10` → **여유**, 초록, 기호 `●`
- 사이트별 칩 색: `remain == 0` 회색(흐리게 opacity 0.55), `1~3` 주황, `>3` 초록.

---

## Screens / Views

### 1. 메인 앱 창 (ContentView 대체)
**Purpose:** 이번달·다음달 달력에서 금·토 빈자리를 빠르게 찾고 상세 확인.

**Layout:** 세로 스택. ① 타이틀바+툴바 → ② 컨트롤 행(보기 전환+필터+범례) → ③ 요약 카드 5열 그리드 → ④ 본문 2열 그리드 `[1fr | 300px]` (달력/목록 + 인스펙터). Regular 폭에서 달력 2개월 나란히, Compact에서 세로 전환, Wide에서 인스펙터 노출.

**Components:**
- **툴바:** 왼쪽 텐트 아이콘(`tent.fill`, 초록)+앱명, "실시간" 상태 pill(초록 dot+텍스트), 우측에 "갱신 방금 전 · 시각", 새로고침 버튼(`arrow.clockwise`, 갱신 중 회전 애니메이션 0.9s linear), 자동 갱신 토글+주기(15분), 설정 기어. 새로고침은 중복 요청 방지(`isLoading` 가드).
- **컨트롤 행:** 세그먼트(달력/주말 목록) — 선택 시 elevated 배경+그림자. 필터 칩(금요일=파랑, 토요일=초록, 잔여 있음=accent) — 선택 시 채워짐. 우측 인라인 범례(여유●/임박▲/마감— + 금/토 색 스와치).
- **요약 카드 5개:** 가까운 금요일(파랑 tint), 가까운 토요일(초록 tint), 이번달 예약가능 주말 수, 다음달 주말 수, 잔여 최다 날짜. 각 카드 클릭 시 해당 날짜 선택/스크롤.
- **달력 셀:** radius 9, 최소 높이 금·토 86 / 평일 60. 상단 행에 날짜(요일별 색: 일=빨강, 토=파랑, 오늘=accent 배경 pill)+총 잔여 수(상태색). 그 아래 상태 라벨(여유/임박/마감). 금·토 셀에만 A/B/C/D 칩(작은 pill, 사이트색). 과거 날짜 opacity 0.4. 금 셀 배경 `blue/0.10`, 토 셀 `green/0.09`. 선택 셀 `box-shadow 0 0 0 2px accent`.
- **인스펙터(우측 300px):** 선택 날짜+요일, 상태 pill, 총 잔여 큰 숫자 카드, 사이트 유형별(프리/A/B/C/D/바비큐/캠파) 잔여 `remain / cap` + 진행 바, 하단 "예약 페이지 열기"(accent) + 즐겨찾기/알림 버튼 + 마지막 확인 시각.

### 2. 주말 목록 보기 (신규 View)
**Purpose:** 금·토만 시간순으로 빠르게 훑기.
**Layout:** 세로 리스트. 각 행 = 큰 날짜 숫자+요일 / 구분선 / "N월 N일"+총 잔여·상태 / A/B/C/D 4칸 미니 카드(수량 세로) / chevron. 필터(금만/토만/잔여있음)와 연동.

### 3. 메뉴바 (App.swift MenuBarExtra + PopoverView)
- **메뉴바 라벨:** 텐트 아이콘 + "금·토 N"(예약 가능 개수). 상태별 아이콘 전환: 빈자리 있음=강조 텐트, 갱신 중=진행, 오류=경고.
- **팝오버(width ~320):** Control Center 스타일 반투명(`.regularMaterial`/`.ultraThinMaterial`). ① 앱명+실시간 상태 → ② 가까운 금요일 카드(파랑) → ③ 가까운 토요일 카드(초록) 각각 큰 날짜+총잔여+상태+`A B C D` 모노 요약 → ④ "다가오는 주말" 5개 행(날짜/요일/총잔여/상태 dot) → ⑤ 새로고침+앱 열기 버튼 → ⑥ 하단 갱신시각/예약페이지/설정/종료.

### 4. 위젯 (Widget/CampingWidget.swift)
- **Small(170²):** 텐트+"난지캠핑", 가까운 주말 요일+날짜, 총 잔여 큰 숫자(초록), 상태+갱신.
- **Medium(364×170):** 헤더+갱신시각, 가까운 금/토 2개 카드(각 날짜/총잔여/상태/`A B C D` 모노).
- **Large(364²):** "다가오는 4개 주말" 리스트(날짜/요일 / N월N일+`A B C D` / 총잔여 큰 수+상태). 하단 "App Group 공유 저장소 기반".

### 5. 설정 (SettingsView 대체)
System Settings 스타일 그룹 리스트(회색 대문자 섹션 헤더 + 카드형 행). 그룹: **갱신**(자동 갱신 토글, 주기), **관심 조건**(관심 요일 금/토 세그, 관심 사이트 A·B·C·D, 최소 잔여 수량), **알림·표시**(새 빈자리 알림 토글, 메뉴바 표시 방식, 테마 시스템/라이트/다크 세그).

### 6. 상태 화면
- **로딩:** 스켈레톤(shimmer 애니메이션 1.4s).
- **오류/캐시:** 경고 삼각형(주황), "예약 정보를 가져오지 못했습니다 / 마지막 확인 7분 전 데이터 표시 / [다시 시도]". 스택 트레이스 노출 금지.
- **빈 데이터:** 캘린더 아이콘, "아직 예약이 열리지 않았습니다 / 매월 1일 오픈 / [오픈 알림 받기]".
- **전체 마감:** 자물쇠 아이콘, "현재 금·토 빈자리 없음 / [취소 대기 알림]".

## Interactions & Behavior
- 달력 셀/목록 행/요약 카드 클릭 → `selectedKey`(month-day) 갱신 → 인스펙터 반영.
- 보기 세그먼트: 달력 ↔ 주말 목록. 필터 칩 토글 시 목록 보기로 전환 후 필터 적용.
- 새로고침: 회전 애니메이션 + 중복 방지. 자동 갱신 토글 애니메이션(knob 0.2s).
- 애니메이션은 절제 — HIG `ease-out`, 220~360ms. Reduce Motion 대응 필수.

## State Management
기존 `CampViewModel` 확장(신규 요청 추가 금지):
- `selectedDate` / `selectedKey`, `viewMode`(.calendar/.list), `filterWeekday`(.all/.fri/.sat), `onlyAvailable: Bool`.
- 파생 계산: 가까운 금/토, 이번·다음달 주말 수, 잔여 최다 날짜 = 기존 `grid`/`calendar`에서 계산.
- 메뉴바·위젯·메인 앱은 **단일 데이터 소스**(App Group 캐시) 공유 — 중복 요청 금지.

## Assets
- 아이콘: **SF Symbols** 사용(`tent`, `tent.fill`, `arrow.clockwise`, `gearshape`, `arrow.up.right.square`, `star`, `bell`, `exclamationmark.triangle`, `calendar`, `lock`). HTML의 인라인 SVG는 대응 SF Symbol로 치환.
- 폰트: 시스템 폰트(한글 자동 Apple SD Gothic Neo). Pretendard는 웹 프리뷰용일 뿐 앱은 시스템 폰트 사용.
- 상태 기호 `● ▲ —`는 접근성용 텍스트 병기(색맹 대응). VoiceOver 라벨 예: "7월 24일 금요일, 총 8자리 남음, A 3, B 2, C 2, D 1".

## Files
- `난지캠핑장 리디자인.dc.html` — 전체 디자인 레퍼런스(5개 화면).
- 대상 코드: `App/Views/ContentView.swift`, `App/Views/CalendarView.swift`, `App/Views/MenuBarView.swift`, `App/Views/SettingsView.swift`, `macapp/Sources/App.swift`(PopoverView/MiniMonth), `Widget/CampingWidget.swift`. 데이터 계층은 변경 금지.
