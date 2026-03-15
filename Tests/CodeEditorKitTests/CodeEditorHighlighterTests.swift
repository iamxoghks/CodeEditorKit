import Foundation
import Testing
@testable import CodeEditorKit

struct CodeEditorHighlighterTests {
    @Test
    func publicConfigurationTypesAreHashable() {
        let snapshot = CodeEditorSnapshot(
            diagnostics: [.init(severity: .warning, message: "warn", location: 1)],
            completions: [.init(title: "SELECT", insertText: "SELECT", replacementRange: NSRange(location: 0, length: 0), detail: "Keyword")],
            hasFoldableRegion: true,
            isFocusedRegionActive: false,
            focusedRegionTitle: "SELECT",
            isLargeDocumentMode: false
        )

        let configurations: Set<CodeEditorConfiguration> = [
            .standard,
            .init(fontSize: 15, contentInsets: .init(horizontal: 12, vertical: 10), largeDocumentThreshold: 32_000),
        ]
        let snapshots: Set<CodeEditorSnapshot> = [snapshot]
        let actions: Set<CodeEditorAction> = [.none, .foldCurrentBlock]

        #expect(configurations.count == 2)
        #expect(snapshots.count == 1)
        #expect(actions.count == 2)
    }

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

    @Test
    func mySQLKeywordCompletionAppears() {
        let completions = CodeEditorHighlighter.completions(
            for: "deli",
            language: .mysql,
            cursorLocation: 4
        )

        #expect(completions.contains(where: { $0.title == "DELIMITER" }))
    }

    @Test
    func mariaDBKeywordCompletionAppears() {
        let completions = CodeEditorHighlighter.completions(
            for: "vers",
            language: .mariadb,
            cursorLocation: 4
        )

        #expect(completions.contains(where: { $0.title == "VERSIONING" }))
    }

    @Test
    func redisHighlightsCommandAndNumericArgument() {
        let spans = CodeEditorHighlighter.spans(
            for: "SET retry_count 3",
            language: .redisCommand
        )
        let hasCommand = spans.contains(where: { span in
            span.kind == .command && span.range.location == 0 && span.range.length == 3
        })
        let hasNumericArgument = spans.contains(where: { span in
            span.kind == .number && span.range.location == 16 && span.range.length == 1
        })

        #expect(hasCommand)
        #expect(hasNumericArgument)
    }

    @Test
    func jsonMatchingPairFindsRootBraces() {
        let text = """
        {
          "query": {
            "match": { "title": "octo" }
          }
        }
        """

        let pair = CodeEditorHighlighter.matchingPair(
            in: text,
            language: .json,
            cursorLocation: 0
        )

        #expect(pair?.openRange == NSRange(location: 0, length: 1))
        #expect(pair?.closeRange.location == text.utf16.count - 1)
    }

    @Test
    func sqlFocusRegionFindsMultilineCTEBlock() {
        let text = """
        WITH recent AS (
          SELECT *
          FROM users
        )
        SELECT * FROM recent;
        """

        let region = CodeEditorHighlighter.focusRegion(
            in: text,
            language: .postgresql,
            selectedRange: NSRange(location: 18, length: 0)
        )

        #expect(region != nil)
        #expect(region?.sourceRange.location == 15)
        #expect(region?.previewTitle == "(")
    }

    @Test
    func jsonHighlightsObjectKeysAsIdentifiers() {
        let spans = CodeEditorHighlighter.spans(
            for: "{ \"query\": true }",
            language: .json
        )
        let hasIdentifierKey = spans.contains(where: { span in
            span.kind == .identifier && span.range.location == 2 && span.range.length == 7
        })
        let hasLiteral = spans.contains(where: { $0.kind == .literal })

        #expect(hasIdentifierKey)
        #expect(hasLiteral)
    }

    @Test
    func postgreSQLDollarQuotedStringIsHighlighted() {
        let spans = CodeEditorHighlighter.spans(
            for: "SELECT $$hello$$, $tag$world$tag$;",
            language: .postgresql
        )

        let stringSpans = spans.filter { $0.kind == .string }
        #expect(stringSpans.count == 2)
    }

    @Test
    func sqlReportsUnterminatedBlockComment() {
        let diagnostics = CodeEditorHighlighter.diagnostics(
            for: "/* comment",
            language: .mysql
        )

        #expect(diagnostics.contains(where: { $0.message == "Unterminated block comment" }))
    }

    @Test
    func redisReportsUnterminatedQuotedArgument() {
        let diagnostics = CodeEditorHighlighter.diagnostics(
            for: #"SET key "unterminated"#,
            language: .redisCommand
        )

        #expect(diagnostics.contains(where: { $0.message == "Unterminated quoted Redis argument" }))
    }

    @Test
    func jsonCompletionAcceptsQuotedPrefix() {
        let completions = CodeEditorHighlighter.completions(
            for: "{ \"que",
            language: .json,
            cursorLocation: 6
        )

        #expect(completions.contains(where: { $0.title == "\"query\": " }))
    }

    @Test
    func matchingPairIgnoresBracketsInsideJSONString() {
        let text = #"{"query":"value with } brace","size":1}"#

        let pair = CodeEditorHighlighter.matchingPair(
            in: text,
            language: .json,
            cursorLocation: 0
        )

        #expect(pair?.openRange == NSRange(location: 0, length: 1))
        #expect(pair?.closeRange.location == text.utf16.count - 1)
    }
}
