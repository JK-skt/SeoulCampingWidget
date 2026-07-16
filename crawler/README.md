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

> ⚠️ **빠른 자동 요청은 브라우저에서도 WAF에 차단된다.** 아래 ①(DOM 읽기)만이
> 네트워크 요청을 하지 않아 안전하다. ②③(fetch/자동 크롤)은 IP를 차단시킬 수 있으니
> 비권장(교육/참고용).

### ① 페이지 DOM 읽기 — 유일한 안전 방법 ★권장 (`page_collect.js`)
네트워크 요청을 **전혀 하지 않고**, 사람이 직접 연 상세페이지에 **이미 렌더된 달력**
(신청수/총모집수)을 DOM에서 읽어 누적·다운로드한다. WAF를 자극하지 않는다.
```
1) 난지캠핑장 상세페이지를 사람이 직접 연다(달력 보이는 화면).
2) F12 → Console 에 crawler/page_collect.js 붙여넣고 Enter.
3) 그 서비스 저장 + 지금까지 누적본이 nanji_calendar.json 로 다운로드.
4) 다른 사이트/월 페이지로 '천천히' 이동해 반복(급하게 넘기지 말 것).
5) 마지막 파일을 ~/SeoulCampingWidget/crawler/ 에 저장 → 앱 [갱신].
```

### ②③ (비권장) fetch/자동 크롤 — WAF 차단 유발
`browser_collect.js`(브라우저 fetch)·`calendar.mjs`(서버 크롤)는 빠른 반복 요청으로
WAF(`ipRedirect.do?threatGb=DNP`)를 유발한다. **사용하지 말 것.** 차단되면 탭 닫고
10~30분 대기(또는 IP 변경) 후 ①로 진행.

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
