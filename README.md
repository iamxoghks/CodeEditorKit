# CodeEditorKit

`CodeEditorKit`은 iPhone, iPad, macOS에서 공통으로 사용할 수 있는 SwiftUI 코드 에디터 패키지입니다.

현재 Octo에서 분리한 1차 버전이며, 다음 입력 시나리오를 대상으로 합니다.

- PostgreSQL SQL
- MySQL SQL
- MariaDB SQL
- Redis command
- Elasticsearch JSON DSL

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

### Xcode

`File > Add Package Dependencies...`

private repo URL을 추가합니다.

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/iamxoghks/CodeEditorKit.git", branch: "chore/initial-package-import")
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

    var body: some View {
        CodeEditor(text: $text, language: .postgresql) { snapshot, trigger in
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

## 공개 API

주요 타입:

- `CodeEditor`
- `CodeEditorLanguage`
- `CodeEditorSnapshot`
- `CodeEditorAction`
- `CodeEditorHighlighter`
- `CodeDiagnostic`
- `CodeCompletionItem`

## 현재 한계

- IDE 수준 의미 분석이나 LSP 연동은 아직 없음
- formatter, auto-indent, lint rule 커스터마이징은 아직 없음
- folding은 현재 선택 블록 기준의 단순 focus 모드
- 하이라이팅은 범용 parser가 아니라 앱 입력 시나리오 중심 구현

## 로드맵

- public API 이름 정리
- 언어 규칙 모듈화
- 테스트 확대
- formatter / indentation 정책 추가
- 문서화 및 샘플 앱 정리
