# Playwright 크롤러 (스텁)

난지 캠핑장 예약 현황을 브라우저 자동화로 수집하는 폴백 경로.

## 상태

🟢 **동작** — Playwright로 난지캠핑장을 실크롤해 서비스 상태(접수중/마감)를
구역별로 집계, Swift 파서 계약 HTML을 출력한다. `node crawl.mjs`로 라이브 실행됨.

🟡 남은 것: **일자별 잔여 좌석 수**는 예약 신청 폼(`insertFormReserve.do`)이
**로그인**을 요구한다(실측). 계정 세션 쿠키(storageState)를 주입하면 확장 가능.

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
