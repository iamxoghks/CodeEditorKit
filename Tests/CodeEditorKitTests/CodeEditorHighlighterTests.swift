import Testing
@testable import CodeEditorKit

struct CodeEditorHighlighterTests {
    @Test
    func postgreSQLKeywordCompletionAppears() {
        let completions = CodeEditorHighlighter.completions(
            for: "sel",
            language: .postgresql,
            cursorLocation: 3
        )

        #expect(completions.contains(where: { $0.title == "SELECT" }))
    }

    @Test
    func jsonReportsUnclosedBrace() {
        let diagnostics = CodeEditorHighlighter.diagnostics(
            for: "{ \"query\": { ",
            language: .json
        )

        #expect(!diagnostics.isEmpty)
    }
}
