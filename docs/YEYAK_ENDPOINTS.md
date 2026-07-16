# yeyak.seoul.go.kr 엔드포인트 맵 (실측)

`/web/main.do` HTML에서 추출한 실제 엔드포인트. 크롤러/실연동의 기준 자료.

## 진입 / 세션
| 경로 | 용도 |
|------|------|
| `/web/main.do` | 메인. 세션 쿠키 발급(진입점) |
| `/web/loginForm.do`, `/web/logout.do` | 로그인/로그아웃 |

## 검색 / 목록
| 경로 | 용도 |
|------|------|
| `/web/search/selectPageListTotalSearch.do?searchKeyword=난지 캠핑` | 통합검색 |
| `/web/reservation/selectPageListFacilitySvc.do` | 시설 서비스 목록 |
| `/web/reservation/selectPageListReserveStatus.do` | 예약현황 목록 |

## 예약현황(잔여) — 세션 필요
| 경로 | 용도 |
|------|------|
| `/web/reservation/selectReservView.do?rsv_svc_id={SVCID}` | 서비스 상세 |
| `/web/reservation/selectListReservCalAjax.do` | ★ 날짜별 예약현황(캘린더) |
| `/web/reservation/selectListReservCalUnitAjax.do` | 구역/단위별 잔여 |
| `/web/reservation/selectAllTimeCheckAjax.do` | 시간대 체크 |

## 실측 특이사항
- `selectListReservCalAjax.do`를 **직접 GET** 하면 `302`(로그인/세션으로 리다이렉트).
  → 순수 HTTP 불가, **브라우저 세션(Playwright)** 필요. (프롬프트가 Playwright를 지정한 이유)
- 서비스 식별자 형식: `SVCID = S<17자리 숫자>` (예: `S251121100349891778`).
- 상세 URL 패턴은 서울 공공예약 OpenAPI의 `SVCURL` 필드와 동일:
  `https://yeyak.seoul.go.kr/web/reservation/selectReservView.do?rsv_svc_id=...`

## 공식 OpenAPI (키 필요, 잔여좌석 아님)
- `http://openapi.seoul.go.kr:8088/{KEY}/json/ListPublicReservationSport/{start}/{end}/`
  (Culture/Education 카테고리 동일). `SVCSTATNM`(접수중/마감) 제공, 사이트별 잔여수는 미제공.
- 이 API는 [SeoulReservationClient](../CampingCore/Sources/CampingCore/Services/SeoulReservationClient.swift)로 연동됨.
