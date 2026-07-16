# Playwright 크롤러 (스텁)

난지 캠핑장 예약 현황을 브라우저 자동화로 수집하는 폴백 경로.

## ⚠️ 근본 원인: WAF (봇 차단) — 반드시 읽기

yeyak의 **예약 달력 AJAX**(`selectListReservCalAjax.do`)는 WAF(WebMonitor)가 보호한다.
외부 자동화(curl/서버 크롤러)의 POST는 `/management/ipRedirect.do?threatGb=DNP`
(**비정상 접근으로 인한 차단**)으로 302 리다이렉트된다. **로그인 문제가 아니라 봇 차단**이다.

- 상세페이지 달력은 inline JS 함수 `fnDraw()`가 `$('#aform').serialize()`를 POST해 채운다.
- **실제 브라우저**(WAF 통과 세션) 안에서 호출하면 정상 JSON을 받는다.
- 과도한 자동 접근 시 IP가 일시 플래그되어 목록 GET까지 차단된다(수십 분).

## 잔여 수집 방법 (권장 순)

### ① 브라우저 수집 — 가장 확실 (WAF 항상 통과) ★권장
`browser_collect.js`를 **yeyak 사이트 콘솔에 붙여넣기**:
```
1) 브라우저에서 https://yeyak.seoul.go.kr 접속
2) F12 → Console 에 crawler/browser_collect.js 전체 붙여넣고 Enter
3) nanji_calendar.json 자동 다운로드
4) ~/SeoulCampingWidget/crawler/nanji_calendar.json 로 저장 → 앱에서 [갱신]
```
사용자의 실제 브라우저 세션(이미 WAF 통과)을 쓰므로 항상 동작한다. 앱/웹이 이 JSON을 읽는다.

### ② 자동 크롤러 — 깨끗한 IP에서 정중히 1회
`node calendar.mjs` — 실브라우저로 상세페이지 진입 후 `fnDraw()`를 호출해 달력 AJAX를
가로챈다. IP가 플래그 안 된 상태에서만 통과(차단 감지 시 즉시 중단·백오프).

### ③ 서비스 단위(접수중/마감)만
`node crawl.mjs` — 목록만으로 서비스 상태를 얻는다(일자별 잔여 없음).

## 환경 준비 (node 없을 때)

```bash
# 1) node 로컬 설치(예: ~/.local, PATH에 ~/.local/bin 포함 가정)
curl -sSL https://nodejs.org/dist/v22.11.0/node-v22.11.0-darwin-arm64.tar.gz | tar -xz -C ~/.local/opt
ln -sf ~/.local/opt/node-v22.11.0-darwin-arm64/bin/{node,npm,npx} ~/.local/bin/

# 2) Playwright + Chromium
cd crawler && npm install    # postinstall이 chromium 설치
```

## 실행

```bash
node crawl.mjs          # 난지캠핑장 라이브 크롤 → 계약 HTML(A/B/C/D 접수중 수)
node crawl.mjs --json   # 서비스 상세 JSON
node crawl.mjs --mock   # 브라우저 없이 mock
```

Swift 연동(파이프라인 검증):
```bash
CRAWLER_PATH=$PWD/crawler/crawl.mjs swift run --package-path CampingCore NanjiLive
# → "크롤러→파서 결과: A=1 B=1 C=0 D=1  ✅ Playwright→Swift 파이프라인 동작"
```

엔드포인트 맵: [docs/YEYAK_ENDPOINTS.md](../docs/YEYAK_ENDPOINTS.md)

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
