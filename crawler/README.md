# Playwright 크롤러 (스텁)

난지 캠핑장 예약 현황을 브라우저 자동화로 수집하는 폴백 경로.

## 상태

🟡 **실측 기반 스캐폴드** — 실제 yeyak 엔드포인트를 리버스 엔지니어링해
`crawl.mjs`가 진짜 흐름(진입→검색→상세→캘린더)을 타도록 작성됨.
엔드포인트 맵은 [docs/YEYAK_ENDPOINTS.md](../docs/YEYAK_ENDPOINTS.md) 참고.

남은 것: 상세 페이지의 **구역(A~D)·잔여 수량 DOM 셀렉터** 확정(실 계정 세션 필요).
예약현황 AJAX는 직접 GET 시 302(로그인)이라 Playwright 브라우저 세션이 필수다.

## 계약(Contract)

Swift `ReservationParser`는 아래 속성을 가진 요소를 파싱한다:

```html
<li data-site="A" data-available="3"></li>
```

- `data-site`: `A` | `B` | `C` | `D`
- `data-available`: 정수(예약 가능 수)

## 사용

```bash
npm install                 # playwright + chromium 설치
node crawl.mjs --month 2026-07        # mock HTML 출력
node crawl.mjs --month 2026-07 --no-mock   # 실제 크롤(미구현)
```

## 실제 연동 시 할 일

`crawl.mjs`의 `crawlReal()` 내부 TODO를 사이트 구조에 맞게 구현:

1. 난지 캠핑장 페이지 이동
2. 대상 월 선택
3. 사이트(A~D)별 잔여 수량 DOM 추출 → `{ A, B, C, D }` 반환

Swift 쪽에서는 `CrawlerDataSource(htmlProvider:)`에 이 스크립트를
서브프로세스로 호출하는 클로저를 주입하면 파이프라인이 연결된다.
