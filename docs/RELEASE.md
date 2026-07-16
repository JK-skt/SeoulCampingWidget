# 릴리스 가이드

## 버전 정책

[Semantic Versioning](https://semver.org): `MAJOR.MINOR.PATCH`

- `MARKETING_VERSION` (예: 0.1.0) — 사용자 표시 버전
- `CURRENT_PROJECT_VERSION` — 빌드 번호(정수 증가)

## 릴리스 절차

1. `CHANGELOG.md`에 변경 내용 정리 (Keep a Changelog 형식)
2. 버전 갱신
   - Xcode 타깃 빌드 설정의 `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`
   - 또는 `project.yml`의 `settings` 갱신 후 `xcodegen generate`
3. 태그 생성
   ```bash
   git tag -a v0.1.0 -m "v0.1.0"
   git push origin v0.1.0
   ```
4. 아카이브 & 공증 (배포 시)
   ```bash
   xcodebuild archive -project SeoulCampingWidget.xcodeproj \
     -scheme SeoulCampingWidget -archivePath build/App.xcarchive
   # xcrun notarytool submit ... (Apple Developer 계정 필요)
   ```

## Sparkle 자동 업데이트 (예정)

향후 [Sparkle](https://sparkle-project.org)을 통합할 때:

1. Sparkle SPM 의존성 추가
2. appcast.xml 호스팅 (GitHub Releases/Pages)
3. `SUFeedURL`, EdDSA 서명 키 설정
4. 릴리스 시 서명된 zip + appcast 갱신 자동화(CI)

> 현재 v0.1.0에서는 미구현. 로드맵 항목.
