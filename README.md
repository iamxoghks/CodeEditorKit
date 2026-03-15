# CodeEditorKit

`CodeEditorKit`은 iPhone, iPad, macOS에서 공통으로 사용할 수 있는 SwiftUI 코드 에디터 패키지입니다.

SwiftUI 진입점은 단순하게 유지하면서, 내부에서는 `NSTextView`와 `UITextView`를 공통 규칙으로 감싼 편집기 코어를 제공합니다.

현재는 아래와 같은 구조화된 텍스트 입력 시나리오를 우선 지원합니다.

| Language | Notes |
| --- | --- |
| PostgreSQL | SQL dialect highlighting |
| MySQL | SQL dialect highlighting |
| MariaDB | SQL dialect highlighting |
| Redis Command | CLI-style command input |
| JSON | Query editors and structured payloads |

## 패키지 상태

- Swift Package Manager 기반 로컬/원격 패키지 사용 가능
- Apple 플랫폼 전용 구현
- 초기 공개 API 정리 단계
- 의미 분석이나 LSP 연동 없이, 가벼운 편집 경험에 집중
- 현재 런타임 외부 패키지 의존성 없음

## 설계 목표

- Apple 플랫폼 공통 편집 경험
- 앱별 크롬은 바깥에서 얹고, 편집기 본체는 패키지에서 재사용
- 외부 하이라이터 의존성 없이 하이라이팅/진단/완성 기능 제공
- SwiftUI 진입점은 단순하게 유지하고, AppKit/UIKit 브리지는 내부에 숨김

## 포함 기능

- 공통 SwiftUI 진입점 `CodeEditor`
- iOS/iPadOS `UITextView` 기반 렌더링
- macOS `NSTextView` 기반 렌더링
- 방언별 문법 하이라이팅
- 간단한 구조 진단
- 자동완성 후보
- bracket matching
- 현재 블록 기준 fold / unfold
- 대용량 문서 모드 표시

## 지원 환경

- Swift 6
- iOS 17+
- macOS 14+

## 설치

Xcode에서 Swift Package로 추가하거나, `Package.swift`에 dependency로 연결할 수 있습니다.

첫 정식 릴리즈 전까지는 태그 대신 branch 또는 revision 고정을 권장합니다.

### Xcode

`File > Add Package Dependencies...`

private repo URL을 추가합니다.

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/iamxoghks/CodeEditorKit.git", branch: "<integration-branch>")
]
```

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "CodeEditorKit", package: "CodeEditorKit")
        ]
    )
]
```

## 사용 예시

```swift
import SwiftUI
import CodeEditorKit

struct ExampleView: View {
    @State private var text = "SELECT * FROM users;"
    private let configuration = CodeEditorConfiguration(
        fontSize: 13,
        contentInsets: .init(horizontal: 10, vertical: 10),
        largeDocumentThreshold: 20_000
    )

    var body: some View {
        CodeEditor(text: $text, language: .postgresql, configuration: configuration) { snapshot, trigger in
            HStack {
                Text(snapshot.diagnostics.first?.message ?? "No lint issues")
                    .font(.caption2)
                Spacer()
                Button("Complete") { trigger(.triggerCompletion) }
                Button("Fold") { trigger(.foldCurrentBlock) }
                Button("Unfold") { trigger(.unfoldAll) }
            }
            .padding(8)
        }
    }
}
```

액세서리 뷰가 필요 없으면 기본 이니셜라이저만 써도 됩니다.

```swift
CodeEditor(text: $text, language: .json)
```

기본 설정을 바꾸고 싶으면 `CodeEditorConfiguration`을 전달하면 됩니다.

```swift
CodeEditor(
    text: $text,
    language: .redisCommand,
    configuration: .init(fontSize: 12, contentInsets: .init(horizontal: 12, vertical: 8))
)
```

## 통합 방향

패키지는 편집기 본체만 책임지고, 앱별 버튼/툴바/상태 뷰는 바깥에서 얹는 구조를 권장합니다.

- package responsibility: text editing, highlighting, lightweight diagnostics, completions
- app responsibility: command execution, persistence, inspector panels, domain-specific chrome

## 공개 API

주요 타입:

- `CodeEditor`
- `CodeEditorLanguage`
- `CodeEditorConfiguration`
- `CodeEditorInsets`
- `CodeEditorSnapshot`
- `CodeEditorAction`
- `CodeEditorHighlighter`
- `CodeDiagnostic`
- `CodeCompletionItem`

직접 하이라이터 유틸리티만 사용할 수도 있습니다.

```swift
let spans = CodeEditorHighlighter.spans(
    for: "SELECT * FROM users;",
    language: .postgresql
)
```

## 개발

패키지 테스트:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift test
```

GitHub Actions에서도 같은 패키지 테스트를 실행하도록 workflow가 포함되어 있습니다.

## 라이선스

MIT

## 현재 한계

- IDE 수준 의미 분석이나 LSP 연동은 아직 없음
- formatter, auto-indent, lint rule 커스터마이징은 아직 없음
- folding은 현재 선택 블록 기준의 단순 focus 모드
- 하이라이팅은 범용 parser가 아니라 앱 입력 시나리오 중심 구현
- line numbers, minimap, multi-cursor 같은 IDE급 기능은 아직 없음

## 로드맵

- 언어 규칙 모듈화
- 테스트 확대
- formatter / indentation 정책 추가
- 문서화 및 샘플 앱 정리
