# 난지캠핑장 메뉴바 앱 (macOS)

정식 Xcode 없이 **swiftc만으로 빌드·실행되는** macOS 메뉴바 전용 앱.

## 특징
- 🏕 **메뉴바 상주**(`LSUIElement`) — Dock 아이콘 없이 메뉴바에만 표시
- **금·토 예약 가능 시 메뉴바에 직접 개수 표시** — 예: `⛺ 금·토 6`
  (가능한 사이트가 없으면 텐트 아이콘만)
- 클릭 시 팝오버: 금·토 가용 요약, 일반캠핑존 A/B/C/D, 서비스 목록(클릭→예약 페이지)
- 15분마다 자동 새로고침, 수동 새로고침
- 데이터: `yeyak.seoul.go.kr` 캠핑장 목록을 URLSession으로 직접 조회(인증 불필요)
- 자체 제작 앱 아이콘([icon.svg](icon.svg) → `AppIcon.icns`)

## 빌드 & 실행
```bash
cd macapp
./build.sh
open SeoulCamping.app     # 메뉴바에 텐트 아이콘 등장
```
> 요구: macOS 13+, Swift 툴체인(Command Line Tools로 충분). 정식 Xcode 불필요.

## 구조
```
macapp/
├── Sources/
│   ├── App.swift      # @main, MenuBarExtra, 뷰모델, 팝오버 UI
│   └── Yeyak.swift    # 난지캠핑장 조회/파싱(URLSession)
├── icon.svg           # 아이콘 원본
├── AppIcon.icns       # 빌드된 앱 아이콘
└── build.sh           # swiftc 컴파일 + .app 번들 조립 + 애드혹 서명
```

## 검증(라이브)
```
난지캠핑장 6건 · 금·토 예약 가능 6곳 · 구역 A=1 B=1 C=0 D=1
```
