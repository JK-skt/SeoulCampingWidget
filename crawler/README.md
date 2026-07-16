# Playwright 크롤러 (스텁)

난지 캠핑장 예약 현황을 브라우저 자동화로 수집하는 폴백 경로.

## 상태

⚠️ **스텁 단계** — 서울 공공예약 사이트의 실제 DOM/흐름이 확정되지 않아,
현재는 Swift 파서가 기대하는 계약 형식의 HTML을 mock 값으로 출력한다.

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
