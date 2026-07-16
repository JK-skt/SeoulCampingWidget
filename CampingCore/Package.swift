// swift-tools-version:6.0
import PackageDescription

// CampingCore
// 앱(App)·위젯(Widget) 양쪽에서 공유하는 순수 로직 라이브러리.
// SwiftUI/WidgetKit 등 UI 프레임워크에 의존하지 않으므로
// 커맨드라인(`swift test`)만으로 단위 테스트가 가능하다.
let package = Package(
    name: "CampingCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "CampingCore", targets: ["CampingCore"]),
        // 정식 Xcode(XCTest) 없이도 로직을 검증할 수 있는 스모크 테스트 실행 파일.
        // 사용법: `swift run CampingCoreDemo`
        .executable(name: "CampingCoreDemo", targets: ["CampingCoreDemo"])
    ],
    targets: [
        .target(
            name: "CampingCore",
            path: "Sources/CampingCore"
        ),
        .executableTarget(
            name: "CampingCoreDemo",
            dependencies: ["CampingCore"],
            path: "Sources/CampingCoreDemo"
        ),
        .testTarget(
            name: "CampingCoreTests",
            dependencies: ["CampingCore"],
            path: "Tests/CampingCoreTests"
        )
    ]
)
