# 난지캠핑장 웹 위젯

브라우저에서 보는 난지캠핑장 예약 현황 위젯. macOS 메뉴바 앱과 **동일한 실데이터**를 사용한다.

![미리보기](../docs/webwidget-preview.png)

## 특징
- macOS 메뉴바 모습 재현(`⛺ 금·토 N`) + 위젯 카드
- 금·토 예약 가능 요약, 일반캠핑존 A/B/C/D, 서비스 목록(예약 링크)
- 다크 테마, 반응형

## 빌드
```bash
cd webwidget
./build.sh                 # 크롤러로 라이브 데이터 주입 → dist/index.html
open dist/index.html
```
> `index.html`은 `__DATA__` 자리표시자를 가진 템플릿이며, `build.sh`가
> [crawler/crawl.mjs](../crawler/crawl.mjs)의 라이브 JSON을 주입해 `dist/index.html`을 만든다.

## 참고
- 브라우저에서 yeyak를 직접 fetch하면 CORS로 막히므로, 데이터는 빌드 시 주입(정적)한다.
  주기적 갱신은 `build.sh`를 스케줄러(cron/launchd)로 돌리거나 크롤러 출력과 연동한다.
- 일자별 잔여 좌석은 yeyak 로그인 세션 필요(메뉴바 앱/크롤러 공통 한계).
