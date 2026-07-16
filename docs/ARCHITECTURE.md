# 아키텍처

## 설계 목표

1. **데이터 소스 불확실성 격리** — 실제 서울 예약 API/HTML 구조를 몰라도
   앱 전체가 컴파일·실행·테스트되어야 한다. 모든 외부 의존은 프로토콜 뒤에 두고,
   최종 폴백으로 `MockProvider`를 둔다.
2. **UI-무관 코어** — `CampingCore`는 SwiftUI/WidgetKit에 의존하지 않아
   커맨드라인(`swift test`)만으로 검증 가능하다.
3. **앱·위젯 공유** — App Group 파일 캐시로 위젯이 앱의 최신 스냅샷을 읽는다.

## 레이어

| 레이어 | 구성요소 | 책임 |
|--------|----------|------|
| UI | `MenuBarView`, `ContentView`, `CalendarView`, `CampingWidget` | 렌더링 |
| ViewModel | `ReservationViewModel` | 상태 보관, 새로고침, 위젯 리로드 |
| Domain/저장소 | `ReservationRepository` | Provider+Cache 오케스트레이션 |
| Provider | `HybridProvider`, `MockProvider` | 스냅샷 조립 |
| DataSource | `OpenAPIDataSource`, `CrawlerDataSource` | 원시 수집 |
| 파싱 | `ReservationParser` | HTML → 사이트별 수량 |
| 저장 | `AvailabilityCache`(File/InMemory) | 스냅샷 캐시 |
| 스케줄 | `AdaptivePoller` | 폴링 주기 계산 |

## 클래스 다이어그램

```mermaid
classDiagram
    class ReservationProvider {
        <<protocol>>
        +campground: Campground
        +fetchSnapshot(months) AvailabilitySnapshot
    }
    class MonthlyDataSource {
        <<protocol>>
        +siteCounts(campground, month) [Campsite:Int]
    }
    class AvailabilityCache {
        <<protocol>>
        +load(campground) AvailabilitySnapshot?
        +save(snapshot)
    }
    class ReservationParsing {
        <<protocol>>
        +parseSiteCounts(html) [Campsite:Int]
    }

    ReservationProvider <|.. MockProvider
    ReservationProvider <|.. HybridProvider
    MonthlyDataSource <|.. OpenAPIDataSource
    MonthlyDataSource <|.. CrawlerDataSource
    AvailabilityCache <|.. FileAvailabilityCache
    AvailabilityCache <|.. InMemoryCache
    ReservationParsing <|.. ReservationParser

    HybridProvider --> MonthlyDataSource : primary/secondary
    HybridProvider --> ReservationProvider : fallback(Mock)
    CrawlerDataSource --> ReservationParsing
    ReservationRepository --> ReservationProvider
    ReservationRepository --> AvailabilityCache
    ReservationViewModel --> ReservationRepository
    AvailabilitySnapshot "1" --> "*" MonthlyAvailability
    MonthlyAvailability "1" --> "*" SiteAvailability
```

## 시퀀스: 새로고침

```mermaid
sequenceDiagram
    participant UI as MenuBar/Widget
    participant VM as ReservationViewModel
    participant Repo as ReservationRepository
    participant Prov as HybridProvider
    participant API as OpenAPIDataSource
    participant Crawl as CrawlerDataSource
    participant Cache as AvailabilityCache

    UI->>VM: refresh()
    VM->>Repo: currentSnapshot()
    Repo->>Prov: fetchSnapshot(months)
    loop 각 월
        Prov->>API: siteCounts()
        alt API 성공
            API-->>Prov: [Campsite:Int]
        else API 실패
            Prov->>Crawl: siteCounts()
            alt 크롤러 성공
                Crawl-->>Prov: [Campsite:Int]
            else 둘 다 실패
                Note over Prov: 라이브 데이터 없음
            end
        end
    end
    alt 라이브 데이터 없음
        Prov->>Prov: MockProvider 폴백
    end
    Prov-->>Repo: AvailabilitySnapshot
    Repo->>Cache: save(snapshot)
    Repo-->>VM: snapshot
    VM->>UI: 상태 갱신 + WidgetCenter.reload
```

## 적응형 폴링 상태

```mermaid
stateDiagram-v2
    [*] --> idle
    idle --> preOpen: 오픈 10분 전
    preOpen --> opening: 오픈 시각 도달
    opening --> idle: 오픈 윈도우 종료
    note right of idle: 15분 주기
    note right of preOpen: 1분 주기
    note right of opening: 10초 주기
```

## 확장 지점 (Seam)

- **실제 API**: `OpenAPIDataSource.siteCounts()`의 TODO 구현
- **실제 크롤러**: `crawler/crawl.mjs`의 `crawlReal()` + `CrawlerDataSource(htmlProvider:)` 주입
- **SwiftData 캐시**: `AvailabilityCache` 새 구현으로 교체
- **다중 캠핑장**: `Campground` case별 Provider 등록
