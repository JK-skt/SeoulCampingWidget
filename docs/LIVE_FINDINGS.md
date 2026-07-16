# 실 API 라이브 검증 결과 (2026-07-16)

발급받은 서울 열린데이터 인증키로 공개 API 전체를 실조회하여 확인한 사실.

## ★ 돌파: 난지캠핑장 실데이터를 키·Playwright 없이 조회
공개 API엔 없지만, **yeyak 캠핑장 카테고리 목록**의 정적 HTML에 난지캠핑장
서비스의 `svc_id`·제목·예약상태가 포함되어 순수 HTTP(GET)로 조회된다.

- 엔드포인트: `/web/search/selectPageListDetailSearchImg.do?code=T500&dCode=T502` (T502=캠핑장)
- 라이브 결과(2026-07-16): 난지캠핑장 **6개 존 전부 접수중**
  (프리캠핑존 / 일반캠핑존 A·B·D형 / 바비큐존 / 캠프파이어존)
- Swift 실구현: [`YeyakCampingClient`](../CampingCore/Sources/CampingCore/Services/YeyakCampingClient.swift)
  + [`YeyakCampingDataSource`](../CampingCore/Sources/CampingCore/Services/YeyakCampingClient.swift),
  실행: `swift run NanjiLive` → HybridProvider 기본 primary로 연결(키 불필요)
- 한계: 목록의 **서비스 단위 상태(접수중/마감)**까지는 순수 HTTP로 가능하나,
  일자별 **잔여 좌석 수**는 상세/캘린더 AJAX(세션)가 필요.

## (참고) 공개 OpenAPI 쪽 결론
**난지 오토캠핑장 예약은 서울 공개 API(ListPublicReservation*)에 존재하지 않는다.**

- 전 카테고리 전수 조회: Sport 599 / Culture 977 / Education 377 = 총 1,953건
- "난지" 매칭 37건 → 전부 체육시설·생태프로그램(축구/테니스/야구/풋살/농구/족구,
  한강야생탐사센터, 난지생태습지원 등). **오토캠핑장 A~D 구역 없음.**
- "캠핑" 매칭: 성인야구장(캠핑장옆) 2건 + **중랑캠핑숲/관악 캠핑숲** 7건(숲체험 프로그램).
- 즉, 난지 오토캠핑장은 yeyak.seoul.go.kr에서만 예약되며, 공개 API로 미노출.
  → 실시간 잔여는 **세션 기반 크롤(Playwright)** 로만 접근 가능(로드맵).

## 공개 API가 실제로 주는 것
서비스 단위 **예약 상태**(SVCSTATNM: 접수중/예약마감/접수종료/예약일시중지)와
접수기간(RCPTBGNDT/ENDDT). **사이트별 잔여 좌석 수는 제공하지 않는다.**

## 라이브 동작(실측)
`SEOUL_API_KEY` + `SEOUL_KEYWORD`로 임의 키워드의 실시간 예약 상태를 집계한다.

```
$ SEOUL_API_KEY=<키> SEOUL_KEYWORD="난지" swift run CampingLive
매칭 서비스: 37건
상태 분포: 접수중=25  예약마감=9  접수종료=2  예약일시중지=1
▶ 예약 가능(접수중): 25건 …

$ SEOUL_API_KEY=<키> SEOUL_KEYWORD="캠핑숲" swift run CampingLive
매칭 서비스: 7건 / 접수중 3건
```

## 시사점 (모델 재해석)
프롬프트의 "난지 캠핑장 A/B/C/D 잔여 수"는 실제 공개 데이터와 맞지 않는다.
현실적 선택지:
1. **공개 API 기반**: 키워드(난지/캠핑숲 등) 서비스의 접수중/마감 상태를 추적(현재 라이브 동작).
2. **난지 오토캠핑 정밀**: yeyak 세션 크롤로 구역·잔여를 수집(Playwright 필요).
3. 모델을 "구역별 잔여" → "서비스별 예약상태"로 일반화.

> 보안: 인증키는 환경변수로만 사용하며 저장소에 커밋하지 않는다.
