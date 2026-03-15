//
//  CodeEditorHighlighter.swift
//  CodeEditorKit
//

import Foundation

public enum CodeEditorLanguage: Hashable, Sendable {
    case postgresql
    case mysql
    case mariadb
    case redisCommand
    case json
}
typealias OctoCodeLanguage = CodeEditorLanguage

public enum CodeTokenKind: Sendable {
    case keyword
    case command
    case string
    case number
    case comment
    case identifier
    case literal
    case punctuation
    case plain
}
typealias OctoCodeTokenKind = CodeTokenKind

public enum CodeDiagnosticSeverity: String, Sendable {
    case warning
    case error
}
typealias OctoCodeDiagnosticSeverity = CodeDiagnosticSeverity

public struct CodeHighlightSpan: Sendable, Equatable {
    public let range: NSRange
    public let kind: CodeTokenKind

    public init(range: NSRange, kind: CodeTokenKind) {
        self.range = range
        self.kind = kind
    }
}
typealias HighlightSpan = CodeHighlightSpan

public struct CodeDiagnostic: Identifiable, Sendable, Equatable {
    public let severity: CodeDiagnosticSeverity
    public let message: String
    public let location: Int?

    public var id: String {
        "\(severity.rawValue)-\(location ?? -1)-\(message)"
    }

    public init(severity: CodeDiagnosticSeverity, message: String, location: Int?) {
        self.severity = severity
        self.message = message
        self.location = location
    }
}
typealias OctoCodeDiagnostic = CodeDiagnostic

public struct CodeCompletionItem: Identifiable, Sendable, Equatable {
    public let title: String
    public let insertText: String
    public let replacementRange: NSRange
    public let detail: String?

    public var id: String {
        "\(title)-\(replacementRange.location)-\(replacementRange.length)"
    }

    public init(title: String, insertText: String, replacementRange: NSRange, detail: String?) {
        self.title = title
        self.insertText = insertText
        self.replacementRange = replacementRange
        self.detail = detail
    }
}
typealias OctoCodeCompletionItem = CodeCompletionItem

public struct CodeMatchingPair: Sendable, Equatable {
    public let openRange: NSRange
    public let closeRange: NSRange

    public init(openRange: NSRange, closeRange: NSRange) {
        self.openRange = openRange
        self.closeRange = closeRange
    }
}
typealias OctoCodeMatchingPair = CodeMatchingPair

public struct CodeFocusRegion: Sendable, Equatable {
    public let sourceRange: NSRange
    public let previewTitle: String

    public init(sourceRange: NSRange, previewTitle: String) {
        self.sourceRange = sourceRange
        self.previewTitle = previewTitle
    }
}
typealias OctoCodeFocusRegion = CodeFocusRegion

public enum CodeEditorHighlighter {
    public static func spans(for text: String, language: CodeEditorLanguage) -> [CodeHighlightSpan] {
        OctoCodeHighlighter.spans(for: text, language: language)
    }

    public static func diagnostics(for text: String, language: CodeEditorLanguage) -> [CodeDiagnostic] {
        OctoCodeHighlighter.diagnostics(for: text, language: language)
    }

    public static func completions(for text: String, language: CodeEditorLanguage, cursorLocation: Int) -> [CodeCompletionItem] {
        OctoCodeHighlighter.completions(for: text, language: language, cursorLocation: cursorLocation)
    }

    public static func matchingPair(in text: String, language: CodeEditorLanguage, cursorLocation: Int) -> CodeMatchingPair? {
        OctoCodeHighlighter.matchingPair(in: text, language: language, cursorLocation: cursorLocation)
    }

    public static func focusRegion(in text: String, language: CodeEditorLanguage, selectedRange: NSRange) -> CodeFocusRegion? {
        OctoCodeHighlighter.focusRegion(in: text, language: language, selectedRange: selectedRange)
    }
}

enum OctoCodeHighlighter {
    private enum SQLDialect {
        case postgresql
        case mysql
        case mariadb
    }

    private static let sqlBaseKeywords: Set<String> = [
        "select", "from", "where", "insert", "into", "values", "update", "set", "delete",
        "truncate", "drop", "alter", "create", "table", "view", "index", "and", "or", "not",
        "is", "in", "exists", "between", "like", "join", "inner", "left", "right", "full",
        "outer", "cross", "on", "group", "by", "order", "having", "limit", "offset",
        "union", "all", "distinct", "as", "case", "when", "then", "else", "end", "with",
        "primary", "key", "foreign", "references", "constraint", "default", "check",
        "cascade", "restrict", "if", "begin", "commit", "rollback", "grant", "revoke",
        "over", "partition", "window", "using", "return", "asc", "desc", "nulls",
        "true", "false", "null", "do", "exists", "any", "some", "into", "returning"
    ]

    private static let postgresqlKeywords: Set<String> = sqlBaseKeywords.union([
        "ilike", "returning", "conflict", "recursive", "vacuum", "analyze",
        "materialized", "extension", "schema", "unlogged", "serial", "bigserial",
        "jsonb", "lateral", "filter", "generated", "stored", "parallel", "tablespace"
    ])

    private static let mysqlKeywords: Set<String> = sqlBaseKeywords.union([
        "replace", "show", "describe", "use", "engine", "delimiter", "explain",
        "lock", "unlock", "database", "databases", "keys", "ignore", "straight_join",
        "optimize", "analyze", "cache", "partition", "rename"
    ])

    private static let mariadbKeywords: Set<String> = mysqlKeywords.union([
        "regexp", "rlike", "virtual", "persistent", "sequence", "optimizer_trace",
        "returning", "system", "versioning"
    ])

    private static let sqlFunctions: [String] = [
        "COUNT", "SUM", "AVG", "MIN", "MAX", "NOW", "COALESCE", "LOWER", "UPPER",
        "SUBSTRING", "DATE_TRUNC", "JSON_EXTRACT", "JSONB_BUILD_OBJECT"
    ]

    private static let redisCommands: [String] = [
        "GET", "SET", "DEL", "EXISTS", "HGET", "HSET", "HGETALL", "HMGET", "HMSET",
        "LPUSH", "RPUSH", "LRANGE", "SADD", "SMEMBERS", "ZADD", "ZRANGE", "SCAN",
        "KEYS", "TTL", "EXPIRE", "TYPE", "PING", "INFO", "DBSIZE", "SELECT"
    ]

    private static let jsonSuggestions: [String] = [
        "\"query\": ",
        "\"bool\": {  }",
        "\"must\": [  ]",
        "\"filter\": [  ]",
        "\"should\": [  ]",
        "\"must_not\": [  ]",
        "\"match\": {  }",
        "\"term\": {  }",
        "\"range\": {  }",
        "\"aggs\": {  }",
        "\"sort\": [  ]",
        "\"size\": ",
        "\"from\": ",
        "true",
        "false",
        "null",
    ]

    static func spans(for text: String, language: OctoCodeLanguage) -> [HighlightSpan] {
        tokenize(text, language: language).spans
    }

    static func diagnostics(for text: String, language: OctoCodeLanguage) -> [OctoCodeDiagnostic] {
        tokenize(text, language: language).diagnostics
    }

    static func completions(for text: String, language: OctoCodeLanguage, cursorLocation: Int) -> [OctoCodeCompletionItem] {
        let clampedLocation = min(max(cursorLocation, 0), (text as NSString).length)
        let context = completionContext(in: text, language: language, cursorLocation: clampedLocation)
        let normalizedPrefix = normalizeCompletionPrefix(context.prefix, language: language)

        let candidates: [String]
        switch language {
        case .postgresql:
            candidates = completionCandidates(
                words: postgresqlKeywords.map { $0.uppercased() } + sqlFunctions,
                prefix: normalizedPrefix
            )
        case .mysql:
            candidates = completionCandidates(
                words: mysqlKeywords.map { $0.uppercased() } + sqlFunctions,
                prefix: normalizedPrefix
            )
        case .mariadb:
            candidates = completionCandidates(
                words: mariadbKeywords.map { $0.uppercased() } + sqlFunctions,
                prefix: normalizedPrefix
            )
        case .redisCommand:
            candidates = completionCandidates(words: redisCommands, prefix: normalizedPrefix)
        case .json:
            candidates = completionCandidates(words: jsonSuggestions, prefix: normalizedPrefix)
        }

        return candidates.prefix(8).map { candidate in
            OctoCodeCompletionItem(
                title: candidate,
                insertText: candidate,
                replacementRange: context.replacementRange,
                detail: completionDetail(for: candidate, language: language)
            )
        }
    }

    static func matchingPair(in text: String, language: OctoCodeLanguage, cursorLocation: Int) -> OctoCodeMatchingPair? {
        guard !text.isEmpty else { return nil }
        let nsText = text as NSString
        let clampedLocation = min(max(cursorLocation, 0), nsText.length)

        let candidateLocations = [clampedLocation - 1, clampedLocation]
        for location in candidateLocations where location >= 0 && location < nsText.length {
            let scalar = nsText.character(at: location)
            if let match = pairForBracket(in: text, at: location, scalar: scalar, language: language) {
                return match
            }
        }
        return nil
    }

    static func focusRegion(in text: String, language: OctoCodeLanguage, selectedRange: NSRange) -> OctoCodeFocusRegion? {
        guard !text.isEmpty else { return nil }
        let nsText = text as NSString
        let clampedRange = NSRange(
            location: min(max(selectedRange.location, 0), nsText.length),
            length: min(max(selectedRange.length, 0), max(0, nsText.length - min(max(selectedRange.location, 0), nsText.length)))
        )

        if clampedRange.length > 0, spansMultipleLines(in: nsText, range: clampedRange) {
            let lineRange = nsText.lineRange(for: clampedRange)
            return OctoCodeFocusRegion(sourceRange: lineRange, previewTitle: previewTitle(for: nsText.substring(with: lineRange)))
        }

        switch language {
        case .redisCommand:
            let currentLine = nsText.lineRange(for: NSRange(location: clampedRange.location, length: 0))
            guard currentLine.length > 0 else { return nil }
            return OctoCodeFocusRegion(sourceRange: currentLine, previewTitle: previewTitle(for: nsText.substring(with: currentLine)))
        case .json, .postgresql, .mysql, .mariadb:
            if let pair = nearestEnclosingPair(in: text, cursorLocation: clampedRange.location, language: language) {
                let fullRange = NSRange(location: pair.openRange.location, length: NSMaxRange(pair.closeRange) - pair.openRange.location)
                guard spansMultipleLines(in: nsText, range: fullRange) else { return nil }
                return OctoCodeFocusRegion(sourceRange: fullRange, previewTitle: previewTitle(for: nsText.substring(with: fullRange)))
            }

            if let commentRange = enclosingMultilineComment(in: text, cursorLocation: clampedRange.location, language: language) {
                return OctoCodeFocusRegion(sourceRange: commentRange, previewTitle: previewTitle(for: nsText.substring(with: commentRange)))
            }
            return nil
        }
    }

    private static func completionDetail(for candidate: String, language: OctoCodeLanguage) -> String? {
        switch language {
        case .postgresql, .mysql, .mariadb:
            return "Keyword"
        case .redisCommand:
            return "Redis Command"
        case .json:
            return candidate.hasPrefix("\"") ? "JSON Key" : "JSON Literal"
        }
    }

    private static func completionCandidates(words: [String], prefix: String) -> [String] {
        if prefix.isEmpty {
            return Array(words.prefix(8))
        }
        return words
            .filter { $0.lowercased().hasPrefix(prefix.lowercased()) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs < rhs
                }
                return lhs.count < rhs.count
            }
    }

    private static func normalizeCompletionPrefix(_ prefix: String, language: OctoCodeLanguage) -> String {
        switch language {
        case .json:
            return prefix.replacingOccurrences(of: "\"", with: "")
        default:
            return prefix
        }
    }

    private static func completionContext(in text: String, language: OctoCodeLanguage, cursorLocation: Int) -> (prefix: String, replacementRange: NSRange) {
        let nsText = text as NSString
        var start = cursorLocation
        var end = cursorLocation

        func isCompletionCharacter(_ scalar: unichar) -> Bool {
            switch language {
            case .json:
                return isWordCharacter(scalar) || scalar == quote
            default:
                return isWordCharacter(scalar)
            }
        }

        while start > 0, isCompletionCharacter(nsText.character(at: start - 1)) {
            start -= 1
        }
        while end < nsText.length, isCompletionCharacter(nsText.character(at: end)) {
            end += 1
        }

        let range = NSRange(location: start, length: end - start)
        return (nsText.substring(with: range), range)
    }

    private static func spansMultipleLines(in text: NSString, range: NSRange) -> Bool {
        let snippet = text.substring(with: range)
        return snippet.contains("\n") || snippet.contains("\r")
    }

    private static func previewTitle(for snippet: String) -> String {
        let compact = snippet
            .split(whereSeparator: \.isNewline)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let shortened = compact.count > 48 ? String(compact.prefix(48)) + "…" : compact
        return shortened.isEmpty ? "Folded Block" : shortened
    }

    private static func nearestEnclosingPair(in text: String, cursorLocation: Int, language: OctoCodeLanguage) -> OctoCodeMatchingPair? {
        let nsText = text as NSString
        let location = min(max(cursorLocation, 0), nsText.length)
        let tokens = tokenize(text, language: language)
        let ignoredRanges = tokens.spans
            .filter { $0.kind == .comment || $0.kind == .string || $0.kind == .identifier }
            .map(\.range)

        var stack: [(openScalar: unichar, range: NSRange)] = []
        var candidate: OctoCodeMatchingPair?

        for index in 0..<nsText.length {
            guard !ignoredRanges.contains(where: { NSLocationInRange(index, $0) }) else { continue }
            let scalar = nsText.character(at: index)
            if isOpenBracket(scalar) {
                stack.append((scalar, NSRange(location: index, length: 1)))
            } else if isCloseBracket(scalar), let last = stack.last, bracketsMatch(last.openScalar, scalar) {
                let open = stack.removeLast()
                let closeRange = NSRange(location: index, length: 1)
                let fullRange = NSRange(location: open.range.location, length: NSMaxRange(closeRange) - open.range.location)
                if NSLocationInRange(location, fullRange) {
                    candidate = OctoCodeMatchingPair(openRange: open.range, closeRange: closeRange)
                }
            }
        }

        return candidate
    }

    private static func enclosingMultilineComment(in text: String, cursorLocation: Int, language: OctoCodeLanguage) -> NSRange? {
        guard matchesLanguageComments(language) else { return nil }
        let commentRanges = tokenize(text, language: language).spans
            .filter { $0.kind == .comment }
            .map(\.range)
            .filter { spansMultipleLines(in: text as NSString, range: $0) }
        return commentRanges.first(where: { NSLocationInRange(cursorLocation, $0) })
    }

    private static func matchesLanguageComments(_ language: OctoCodeLanguage) -> Bool {
        switch language {
        case .postgresql, .mysql, .mariadb:
            return true
        case .redisCommand, .json:
            return false
        }
    }

    private static func pairForBracket(in text: String, at location: Int, scalar: unichar, language: OctoCodeLanguage) -> OctoCodeMatchingPair? {
        let nsText = text as NSString
        let tokens = tokenize(text, language: language)
        let ignoredRanges = tokens.spans
            .filter { $0.kind == .comment || $0.kind == .string || $0.kind == .identifier }
            .map(\.range)
        guard !ignoredRanges.contains(where: { NSLocationInRange(location, $0) }) else { return nil }

        if isOpenBracket(scalar) {
            var depth = 0
            for index in location..<nsText.length {
                guard !ignoredRanges.contains(where: { NSLocationInRange(index, $0) }) else { continue }
                let current = nsText.character(at: index)
                if current == scalar {
                    depth += 1
                } else if bracketsMatch(scalar, current) {
                    depth -= 1
                    if depth == 0 {
                        return OctoCodeMatchingPair(
                            openRange: NSRange(location: location, length: 1),
                            closeRange: NSRange(location: index, length: 1)
                        )
                    }
                }
            }
        } else if isCloseBracket(scalar) {
            var depth = 0
            for index in stride(from: location, through: 0, by: -1) {
                guard !ignoredRanges.contains(where: { NSLocationInRange(index, $0) }) else { continue }
                let current = nsText.character(at: index)
                if current == scalar {
                    depth += 1
                } else if bracketsMatch(current, scalar) {
                    depth -= 1
                    if depth == 0 {
                        return OctoCodeMatchingPair(
                            openRange: NSRange(location: index, length: 1),
                            closeRange: NSRange(location: location, length: 1)
                        )
                    }
                }
            }
        }

        return nil
    }

    private static func bracketsMatch(_ open: unichar, _ close: unichar) -> Bool {
        (open == leftParen && close == rightParen) ||
        (open == leftBracket && close == rightBracket) ||
        (open == leftBrace && close == rightBrace)
    }

    private static func isOpenBracket(_ scalar: unichar) -> Bool {
        scalar == leftParen || scalar == leftBracket || scalar == leftBrace
    }

    private static func isCloseBracket(_ scalar: unichar) -> Bool {
        scalar == rightParen || scalar == rightBracket || scalar == rightBrace
    }

    private static func tokenize(_ text: String, language: OctoCodeLanguage) -> (spans: [HighlightSpan], diagnostics: [OctoCodeDiagnostic]) {
        switch language {
        case .postgresql:
            return sqlTokens(text, dialect: .postgresql)
        case .mysql:
            return sqlTokens(text, dialect: .mysql)
        case .mariadb:
            return sqlTokens(text, dialect: .mariadb)
        case .redisCommand:
            return redisTokens(text)
        case .json:
            return jsonTokens(text)
        }
    }

    private static func sqlTokens(_ text: String, dialect: SQLDialect) -> (spans: [HighlightSpan], diagnostics: [OctoCodeDiagnostic]) {
        let nsText = text as NSString
        let length = nsText.length
        let keywords = keywords(for: dialect)
        var spans: [HighlightSpan] = []
        var diagnostics: [OctoCodeDiagnostic] = []
        var parenStack: [Int] = []
        var index = 0

        while index < length {
            let scalar = nsText.character(at: index)

            if isWhitespace(scalar) {
                index += 1
                continue
            }

            if scalar == hyphen, index + 1 < length, nsText.character(at: index + 1) == hyphen {
                let start = index
                index += 2
                while index < length, !isLineBreak(nsText.character(at: index)) {
                    index += 1
                }
                spans.append(HighlightSpan(range: NSRange(location: start, length: index - start), kind: .comment))
                continue
            }

            if (dialect == .mysql || dialect == .mariadb), scalar == hash {
                let start = index
                index += 1
                while index < length, !isLineBreak(nsText.character(at: index)) {
                    index += 1
                }
                spans.append(HighlightSpan(range: NSRange(location: start, length: index - start), kind: .comment))
                continue
            }

            if scalar == slash, index + 1 < length, nsText.character(at: index + 1) == star {
                let start = index
                index += 2
                var depth = 1
                while index < length, depth > 0 {
                    let current = nsText.character(at: index)
                    if current == slash, index + 1 < length, nsText.character(at: index + 1) == star {
                        depth += 1
                        index += 2
                    } else if current == star, index + 1 < length, nsText.character(at: index + 1) == slash {
                        depth -= 1
                        index += 2
                    } else {
                        index += 1
                    }
                }
                if depth != 0 {
                    diagnostics.append(
                        OctoCodeDiagnostic(severity: .error, message: "Unterminated block comment", location: start)
                    )
                    index = length
                }
                spans.append(HighlightSpan(range: NSRange(location: start, length: index - start), kind: .comment))
                continue
            }

            if scalar == quote {
                let start = index
                index += 1
                while index < length {
                    let current = nsText.character(at: index)
                    if current == quote {
                        if index + 1 < length, nsText.character(at: index + 1) == quote {
                            index += 2
                            continue
                        }
                        index += 1
                        break
                    }
                    index += 1
                }
                if index > length || (index == length && nsText.character(at: max(start, length - 1)) != quote) {
                    diagnostics.append(
                        OctoCodeDiagnostic(severity: .error, message: "Unterminated string literal", location: start)
                    )
                }
                spans.append(HighlightSpan(range: NSRange(location: start, length: max(0, index - start)), kind: .string))
                continue
            }

            if dialect == .postgresql, scalar == dollar {
                if let dollarRange = sqlDollarQuotedRange(in: nsText, start: index) {
                    spans.append(HighlightSpan(range: dollarRange, kind: .string))
                    index = NSMaxRange(dollarRange)
                    continue
                }
            }

            if dialect == .postgresql, scalar == doubleQuote {
                let start = index
                index += 1
                while index < length {
                    let current = nsText.character(at: index)
                    if current == doubleQuote {
                        if index + 1 < length, nsText.character(at: index + 1) == doubleQuote {
                            index += 2
                            continue
                        }
                        index += 1
                        break
                    }
                    index += 1
                }
                spans.append(HighlightSpan(range: NSRange(location: start, length: max(0, index - start)), kind: .identifier))
                continue
            }

            if (dialect == .mysql || dialect == .mariadb), scalar == backtick {
                let start = index
                index += 1
                while index < length {
                    let current = nsText.character(at: index)
                    if current == backtick {
                        index += 1
                        break
                    }
                    index += 1
                }
                spans.append(HighlightSpan(range: NSRange(location: start, length: max(0, index - start)), kind: .identifier))
                continue
            }

            if isPunctuation(scalar, language: .postgresql) {
                if scalar == leftParen {
                    parenStack.append(index)
                } else if scalar == rightParen {
                    if parenStack.isEmpty {
                        diagnostics.append(
                            OctoCodeDiagnostic(severity: .warning, message: "Unmatched closing parenthesis", location: index)
                        )
                    } else {
                        _ = parenStack.removeLast()
                    }
                }
                spans.append(HighlightSpan(range: NSRange(location: index, length: 1), kind: .punctuation))
                index += 1
                continue
            }

            if isDigit(scalar) {
                let start = index
                index += 1
                while index < length, isNumberPart(nsText.character(at: index)) {
                    index += 1
                }
                spans.append(HighlightSpan(range: NSRange(location: start, length: index - start), kind: .number))
                continue
            }

            if isIdentifierStart(scalar) {
                let start = index
                index += 1
                while index < length, isIdentifierPart(nsText.character(at: index)) {
                    index += 1
                }
                let word = nsText.substring(with: NSRange(location: start, length: index - start))
                let lowercased = word.lowercased()
                if keywords.contains(lowercased) {
                    spans.append(HighlightSpan(range: NSRange(location: start, length: index - start), kind: .keyword))
                } else if lowercased == "true" || lowercased == "false" || lowercased == "null" {
                    spans.append(HighlightSpan(range: NSRange(location: start, length: index - start), kind: .literal))
                }
                continue
            }

            index += 1
        }

        for unmatched in parenStack {
            diagnostics.append(
                OctoCodeDiagnostic(severity: .warning, message: "Unmatched opening parenthesis", location: unmatched)
            )
        }

        return (spans, diagnostics)
    }

    private static func sqlDollarQuotedRange(in text: NSString, start: Int) -> NSRange? {
        let length = text.length
        guard start < length, text.character(at: start) == dollar else { return nil }

        var delimiterEnd = start + 1
        while delimiterEnd < length {
            let current = text.character(at: delimiterEnd)
            if current == dollar { break }
            guard isIdentifierPart(current) else { return nil }
            delimiterEnd += 1
        }

        guard delimiterEnd < length, text.character(at: delimiterEnd) == dollar else { return nil }
        let delimiterRange = NSRange(location: start, length: delimiterEnd - start + 1)
        let delimiter = text.substring(with: delimiterRange)
        let searchStart = delimiterEnd + 1
        guard searchStart <= length else { return nil }
        let searchRange = NSRange(location: searchStart, length: max(0, length - searchStart))
        let found = text.range(of: delimiter, options: [], range: searchRange)
        guard found.location != NSNotFound else { return NSRange(location: start, length: length - start) }
        return NSRange(location: start, length: NSMaxRange(found) - start)
    }

    private static func redisTokens(_ text: String) -> (spans: [HighlightSpan], diagnostics: [OctoCodeDiagnostic]) {
        let nsText = text as NSString
        let length = nsText.length
        var spans: [HighlightSpan] = []
        var diagnostics: [OctoCodeDiagnostic] = []
        var index = 0

        while index < length {
            let lineRange = nsText.lineRange(for: NSRange(location: index, length: 0))
            let lineEnd = NSMaxRange(lineRange)
            var cursor = lineRange.location
            var didCaptureCommand = false

            while cursor < lineEnd {
                let scalar = nsText.character(at: cursor)
                if isWhitespace(scalar) || isLineBreak(scalar) {
                    cursor += 1
                    continue
                }

                if scalar == quote || scalar == doubleQuote {
                    let delimiter = scalar
                    let start = cursor
                    cursor += 1
                    var terminated = false
                    while cursor < lineEnd {
                        let current = nsText.character(at: cursor)
                        if current == backslash {
                            cursor += min(2, lineEnd - cursor)
                            continue
                        }
                        if current == delimiter {
                            cursor += 1
                            terminated = true
                            break
                        }
                        cursor += 1
                    }
                    if !terminated {
                        diagnostics.append(
                            OctoCodeDiagnostic(severity: .error, message: "Unterminated quoted Redis argument", location: start)
                        )
                    }
                    spans.append(HighlightSpan(range: NSRange(location: start, length: cursor - start), kind: .string))
                    continue
                }

                let start = cursor
                cursor += 1
                while cursor < lineEnd {
                    let current = nsText.character(at: cursor)
                    if isWhitespace(current) || isLineBreak(current) {
                        break
                    }
                    cursor += 1
                }
                let tokenRange = NSRange(location: start, length: cursor - start)
                let token = nsText.substring(with: tokenRange)
                if !didCaptureCommand {
                    spans.append(HighlightSpan(range: tokenRange, kind: .command))
                    didCaptureCommand = true
                } else if Double(token) != nil {
                    spans.append(HighlightSpan(range: tokenRange, kind: .number))
                }
            }

            index = lineEnd
        }

        return (spans, diagnostics)
    }

    private static func jsonTokens(_ text: String) -> (spans: [HighlightSpan], diagnostics: [OctoCodeDiagnostic]) {
        let nsText = text as NSString
        let length = nsText.length
        var spans: [HighlightSpan] = []
        var diagnostics: [OctoCodeDiagnostic] = []
        var bracketStack: [(scalar: unichar, index: Int)] = []
        var index = 0

        while index < length {
            let scalar = nsText.character(at: index)

            if isWhitespace(scalar) {
                index += 1
                continue
            }

            if scalar == doubleQuote {
                let start = index
                index += 1
                var terminated = false
                while index < length {
                    let current = nsText.character(at: index)
                    if current == backslash {
                        index += min(2, length - index)
                        continue
                    }
                    if current == doubleQuote {
                        index += 1
                        terminated = true
                        break
                    }
                    index += 1
                }
                if !terminated {
                    diagnostics.append(
                        OctoCodeDiagnostic(severity: .error, message: "Unterminated JSON string", location: start)
                    )
                }

                let range = NSRange(location: start, length: index - start)
                let nextNonWhitespace = nextNonWhitespaceIndex(in: nsText, from: index)
                let kind: OctoCodeTokenKind = {
                    if let next = nextNonWhitespace, next < length, nsText.character(at: next) == colon {
                        return .identifier
                    }
                    return .string
                }()
                spans.append(HighlightSpan(range: range, kind: kind))
                continue
            }

            if isJSONNumberStart(scalar, text: nsText, index: index) {
                let start = index
                index += 1
                while index < length, isJSONNumberContinuation(nsText.character(at: index)) {
                    index += 1
                }
                spans.append(HighlightSpan(range: NSRange(location: start, length: index - start), kind: .number))
                continue
            }

            if let literalLength = literalLength(in: nsText, at: index, candidates: ["true", "false", "null"]) {
                spans.append(HighlightSpan(range: NSRange(location: index, length: literalLength), kind: .literal))
                index += literalLength
                continue
            }

            if isPunctuation(scalar, language: .json) {
                if scalar == leftBrace || scalar == leftBracket {
                    bracketStack.append((scalar, index))
                } else if scalar == rightBrace || scalar == rightBracket {
                    guard let last = bracketStack.last, bracketsMatch(last.scalar, scalar) else {
                        diagnostics.append(
                            OctoCodeDiagnostic(severity: .warning, message: "Unmatched closing bracket", location: index)
                        )
                        spans.append(HighlightSpan(range: NSRange(location: index, length: 1), kind: .punctuation))
                        index += 1
                        continue
                    }
                    _ = bracketStack.removeLast()
                }
                spans.append(HighlightSpan(range: NSRange(location: index, length: 1), kind: .punctuation))
                index += 1
                continue
            }

            index += 1
        }

        for unmatched in bracketStack {
            diagnostics.append(
                OctoCodeDiagnostic(severity: .warning, message: "Unmatched opening bracket", location: unmatched.index)
            )
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let data = text.data(using: .utf8) {
            do {
                _ = try JSONSerialization.jsonObject(with: data)
            } catch {
                let message = (error as NSError).localizedDescription
                diagnostics.append(OctoCodeDiagnostic(severity: .warning, message: message, location: nil))
            }
        }

        return (spans, diagnostics)
    }

    private static func literalLength(in text: NSString, at index: Int, candidates: [String]) -> Int? {
        for candidate in candidates {
            let candidateLength = candidate.utf16.count
            guard index + candidateLength <= text.length else { continue }
            let range = NSRange(location: index, length: candidateLength)
            if text.substring(with: range) == candidate {
                return candidateLength
            }
        }
        return nil
    }

    private static func nextNonWhitespaceIndex(in text: NSString, from index: Int) -> Int? {
        var cursor = index
        while cursor < text.length {
            if !isWhitespace(text.character(at: cursor)) {
                return cursor
            }
            cursor += 1
        }
        return nil
    }

    private static func keywords(for dialect: SQLDialect) -> Set<String> {
        switch dialect {
        case .postgresql: return postgresqlKeywords
        case .mysql: return mysqlKeywords
        case .mariadb: return mariadbKeywords
        }
    }
}

private let leftParen: unichar = "(".utf16.first!
private let rightParen: unichar = ")".utf16.first!
private let leftBracket: unichar = "[".utf16.first!
private let rightBracket: unichar = "]".utf16.first!
private let leftBrace: unichar = "{".utf16.first!
private let rightBrace: unichar = "}".utf16.first!
private let quote: unichar = "'".utf16.first!
private let doubleQuote: unichar = "\"".utf16.first!
private let backtick: unichar = "`".utf16.first!
private let slash: unichar = "/".utf16.first!
private let star: unichar = "*".utf16.first!
private let hyphen: unichar = "-".utf16.first!
private let hash: unichar = "#".utf16.first!
private let dollar: unichar = "$".utf16.first!
private let colon: unichar = ":".utf16.first!
private let comma: unichar = ",".utf16.first!
private let period: unichar = ".".utf16.first!
private let semicolon: unichar = ";".utf16.first!
private let backslash: unichar = "\\".utf16.first!

private func isWhitespace(_ scalar: unichar) -> Bool {
    scalar == 32 || scalar == 9 || scalar == 10 || scalar == 13
}

private func isLineBreak(_ scalar: unichar) -> Bool {
    scalar == 10 || scalar == 13
}

private func isDigit(_ scalar: unichar) -> Bool {
    scalar >= 48 && scalar <= 57
}

private func isASCIIAlpha(_ scalar: unichar) -> Bool {
    (scalar >= 65 && scalar <= 90) || (scalar >= 97 && scalar <= 122)
}

private func isIdentifierStart(_ scalar: unichar) -> Bool {
    isASCIIAlpha(scalar) || scalar == 95
}

private func isIdentifierPart(_ scalar: unichar) -> Bool {
    isIdentifierStart(scalar) || isDigit(scalar) || scalar == dollar
}

private func isWordCharacter(_ scalar: unichar) -> Bool {
    isIdentifierPart(scalar)
}

private func isNumberPart(_ scalar: unichar) -> Bool {
    isDigit(scalar) || scalar == period
}

private func isJSONNumberStart(_ scalar: unichar, text: NSString, index: Int) -> Bool {
    if isDigit(scalar) { return true }
    if scalar == hyphen, index + 1 < text.length {
        return isDigit(text.character(at: index + 1))
    }
    return false
}

private func isJSONNumberContinuation(_ scalar: unichar) -> Bool {
    isDigit(scalar) || scalar == period || scalar == hyphen || scalar == 43 || scalar == 69 || scalar == 101
}

private func isPunctuation(_ scalar: unichar, language: OctoCodeLanguage) -> Bool {
    switch language {
    case .postgresql, .mysql, .mariadb:
        return scalar == leftParen || scalar == rightParen || scalar == leftBracket || scalar == rightBracket || scalar == comma || scalar == period || scalar == semicolon
    case .json:
        return scalar == leftBrace || scalar == rightBrace || scalar == leftBracket || scalar == rightBracket || scalar == colon || scalar == comma
    case .redisCommand:
        return false
    }
}
