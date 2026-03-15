//
//  CodeEditor.swift
//  CodeEditorKit
//

import SwiftUI

#if os(macOS)
import AppKit
private typealias PlatformColor = NSColor
private typealias PlatformFont = NSFont
#else
import UIKit
private typealias PlatformColor = UIColor
private typealias PlatformFont = UIFont
#endif

public struct CodeEditor<Accessory: View>: View {
    @Binding var text: String
    let language: CodeEditorLanguage

    @Environment(\.colorScheme) private var colorScheme
    @State private var snapshot = CodeEditorSnapshot()
    @State private var requestedAction: CodeEditorAction = .none
    @State private var actionToken = 0

    private let accessoryBuilder: ((CodeEditorSnapshot, @escaping (CodeEditorAction) -> Void) -> Accessory)?

    public init(text: Binding<String>, language: CodeEditorLanguage) where Accessory == EmptyView {
        self._text = text
        self.language = language
        self.accessoryBuilder = nil
    }

    public init(
        text: Binding<String>,
        language: CodeEditorLanguage,
        @ViewBuilder accessory: @escaping (CodeEditorSnapshot, @escaping (CodeEditorAction) -> Void) -> Accessory
    ) {
        self._text = text
        self.language = language
        self.accessoryBuilder = accessory
    }

    public var body: some View {
        VStack(spacing: 0) {
            PlatformCodeEditor(
                text: $text,
                language: language,
                colorScheme: colorScheme,
                action: requestedAction,
                actionToken: actionToken,
                onSnapshotChange: { snapshot = $0 }
            )

            if let accessoryBuilder {
                Divider()
                accessoryBuilder(snapshot) { action in
                    trigger(action)
                }
            }
        }
    }

    private func trigger(_ action: CodeEditorAction) {
        requestedAction = action
        actionToken += 1
    }
}

public struct CodeEditorSnapshot: Equatable {
    public var diagnostics: [CodeDiagnostic] = []
    public var completions: [CodeCompletionItem] = []
    public var hasFoldableRegion = false
    public var isFocusedRegionActive = false
    public var focusedRegionTitle: String?
    public var isLargeDocumentMode = false

    public init(
        diagnostics: [CodeDiagnostic] = [],
        completions: [CodeCompletionItem] = [],
        hasFoldableRegion: Bool = false,
        isFocusedRegionActive: Bool = false,
        focusedRegionTitle: String? = nil,
        isLargeDocumentMode: Bool = false
    ) {
        self.diagnostics = diagnostics
        self.completions = completions
        self.hasFoldableRegion = hasFoldableRegion
        self.isFocusedRegionActive = isFocusedRegionActive
        self.focusedRegionTitle = focusedRegionTitle
        self.isLargeDocumentMode = isLargeDocumentMode
    }
}

public enum CodeEditorAction: Equatable {
    case none
    case triggerCompletion
    case applyCompletion(CodeCompletionItem)
    case foldCurrentBlock
    case unfoldAll
}

private struct CodeEditorTheme {
    let backgroundColor: PlatformColor
    let textColor: PlatformColor
    let keywordColor: PlatformColor
    let commandColor: PlatformColor
    let stringColor: PlatformColor
    let numberColor: PlatformColor
    let commentColor: PlatformColor
    let identifierColor: PlatformColor
    let literalColor: PlatformColor
    let punctuationColor: PlatformColor
    let matchBackgroundColor: PlatformColor

    static func make(for colorScheme: ColorScheme) -> CodeEditorTheme {
        switch colorScheme {
        case .dark:
            return CodeEditorTheme(
                backgroundColor: PlatformColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 1),
                textColor: PlatformColor(white: 0.92, alpha: 1),
                keywordColor: PlatformColor(red: 0.43, green: 0.71, blue: 1.00, alpha: 1),
                commandColor: PlatformColor(red: 0.98, green: 0.74, blue: 0.02, alpha: 1),
                stringColor: PlatformColor(red: 0.88, green: 0.65, blue: 0.34, alpha: 1),
                numberColor: PlatformColor(red: 0.78, green: 0.56, blue: 0.95, alpha: 1),
                commentColor: PlatformColor(red: 0.47, green: 0.56, blue: 0.54, alpha: 1),
                identifierColor: PlatformColor(red: 0.43, green: 0.84, blue: 0.82, alpha: 1),
                literalColor: PlatformColor(red: 0.51, green: 0.84, blue: 0.50, alpha: 1),
                punctuationColor: PlatformColor(red: 0.72, green: 0.77, blue: 0.83, alpha: 1),
                matchBackgroundColor: PlatformColor(red: 0.22, green: 0.46, blue: 0.88, alpha: 0.28)
            )
        default:
            #if os(macOS)
            let background = PlatformColor.textBackgroundColor
            let text = PlatformColor.textColor
            let punctuation = PlatformColor.secondaryLabelColor
            #else
            let background = PlatformColor.systemBackground
            let text = PlatformColor.label
            let punctuation = PlatformColor.secondaryLabel
            #endif

            return CodeEditorTheme(
                backgroundColor: background,
                textColor: text,
                keywordColor: PlatformColor(red: 0.10, green: 0.31, blue: 0.74, alpha: 1),
                commandColor: PlatformColor(red: 0.85, green: 0.41, blue: 0.13, alpha: 1),
                stringColor: PlatformColor(red: 0.63, green: 0.27, blue: 0.07, alpha: 1),
                numberColor: PlatformColor(red: 0.51, green: 0.27, blue: 0.72, alpha: 1),
                commentColor: PlatformColor(white: 0.47, alpha: 1),
                identifierColor: PlatformColor(red: 0.02, green: 0.51, blue: 0.51, alpha: 1),
                literalColor: PlatformColor(red: 0.17, green: 0.53, blue: 0.25, alpha: 1),
                punctuationColor: punctuation,
                matchBackgroundColor: PlatformColor(red: 0.32, green: 0.55, blue: 0.93, alpha: 0.18)
            )
        }
    }

    func color(for kind: CodeTokenKind) -> PlatformColor {
        switch kind {
        case .keyword: return keywordColor
        case .command: return commandColor
        case .string: return stringColor
        case .number: return numberColor
        case .comment: return commentColor
        case .identifier: return identifierColor
        case .literal: return literalColor
        case .punctuation: return punctuationColor
        case .plain: return textColor
        }
    }
}

private enum CodeEditorStyler {
    static func apply(
        to storage: NSMutableAttributedString,
        spans: [CodeHighlightSpan],
        matchingPair: CodeMatchingPair?,
        theme: CodeEditorTheme,
        font: PlatformFont
    ) {
        let fullRange = NSRange(location: 0, length: storage.length)
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: theme.textColor,
        ]

        storage.beginEditing()
        storage.setAttributes(baseAttributes, range: fullRange)

        for span in spans where NSMaxRange(span.range) <= storage.length {
            storage.addAttribute(.foregroundColor, value: theme.color(for: span.kind), range: span.range)
        }

        if let matchingPair {
            storage.addAttribute(.backgroundColor, value: theme.matchBackgroundColor, range: matchingPair.openRange)
            storage.addAttribute(.backgroundColor, value: theme.matchBackgroundColor, range: matchingPair.closeRange)
        }

        storage.endEditing()
    }
}

private func clampedRange(_ range: NSRange, maxLength: Int) -> NSRange {
    let location = min(max(range.location, 0), maxLength)
    let length = min(max(range.length, 0), max(0, maxLength - location))
    return NSRange(location: location, length: length)
}

#if os(macOS)
private struct PlatformCodeEditor: NSViewRepresentable {
    @Binding var text: String
    let language: CodeEditorLanguage
    let colorScheme: ColorScheme
    let action: CodeEditorAction
    let actionToken: Int
    let onSnapshotChange: (CodeEditorSnapshot) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, language: language, colorScheme: colorScheme, onSnapshotChange: onSnapshotChange)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textStorage = NSTextStorage(string: text)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.isEditable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.delegate = context.coordinator
        context.coordinator.attach(textView: textView)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.autoresizingMask = [.width, .height]
        scrollView.documentView = textView

        context.coordinator.applyCurrentState(to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.text = $text
        context.coordinator.language = language
        context.coordinator.colorScheme = colorScheme
        context.coordinator.onSnapshotChange = onSnapshotChange

        if context.coordinator.lastHandledActionToken != actionToken {
            context.coordinator.lastHandledActionToken = actionToken
            context.coordinator.handle(action: action, textView: textView)
        }

        context.coordinator.applyCurrentState(to: textView)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        private static let largeDocumentThreshold = 16_000

        var text: Binding<String>
        var language: CodeEditorLanguage
        var colorScheme: ColorScheme
        var onSnapshotChange: (CodeEditorSnapshot) -> Void
        var isSynchronizing = false
        var lastHandledActionToken = 0
        private var focusedRegion: CodeFocusRegion?
        private var lastRenderedText = ""
        private var lastRenderedSelection = NSRange(location: 0, length: 0)
        private var lastRenderedLanguage: CodeEditorLanguage = .postgresql
        private var lastRenderedScheme: ColorScheme = .light
        private var pendingStyleWorkItem: DispatchWorkItem?
        private weak var textView: NSTextView?

        init(text: Binding<String>, language: CodeEditorLanguage, colorScheme: ColorScheme, onSnapshotChange: @escaping (CodeEditorSnapshot) -> Void) {
            self.text = text
            self.language = language
            self.colorScheme = colorScheme
            self.onSnapshotChange = onSnapshotChange
        }

        func attach(textView: NSTextView) {
            self.textView = textView
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            guard !isSynchronizing else { return }
            guard focusedRegion == nil else { return }

            let newText = textView.string
            if text.wrappedValue != newText {
                text.wrappedValue = newText
            }
            applyCurrentState(to: textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView else { return }
            applyCurrentState(to: textView)
        }

        func handle(action: CodeEditorAction, textView: NSTextView) {
            switch action {
            case .none:
                break
            case .triggerCompletion:
                applyFirstCompletion(textView: textView)
            case .applyCompletion(let item):
                applyCompletion(item, textView: textView)
            case .foldCurrentBlock:
                foldCurrentBlock(textView: textView)
            case .unfoldAll:
                focusedRegion = nil
            }
        }

        func applyCurrentState(to textView: NSTextView) {
            let sourceText = text.wrappedValue
            let displayText = focusedRegion.map { (sourceText as NSString).substring(with: $0.sourceRange) } ?? sourceText
            let editable = focusedRegion == nil

            if textView.string != displayText {
                isSynchronizing = true
                textView.string = displayText
                isSynchronizing = false
            }

            textView.isEditable = editable
            textView.isSelectable = true

            let selectedRange = editable ? clampedRange(textView.selectedRange(), maxLength: (textView.string as NSString).length) : NSRange(location: 0, length: 0)
            publishSnapshot(sourceText: sourceText, selectedRange: selectedRange)
            restyle(textView: textView, displayText: displayText, selectedRange: selectedRange)
        }

        private func publishSnapshot(sourceText: String, selectedRange: NSRange) {
            let diagnostics = CodeEditorHighlighter.diagnostics(for: sourceText, language: language)
            let completions = focusedRegion == nil
                ? CodeEditorHighlighter.completions(for: sourceText, language: language, cursorLocation: selectedRange.location)
                : []
            let hasFoldableRegion = focusedRegion == nil && CodeEditorHighlighter.focusRegion(in: sourceText, language: language, selectedRange: selectedRange) != nil

            onSnapshotChange(
                CodeEditorSnapshot(
                    diagnostics: diagnostics,
                    completions: completions,
                    hasFoldableRegion: hasFoldableRegion,
                    isFocusedRegionActive: focusedRegion != nil,
                    focusedRegionTitle: focusedRegion?.previewTitle,
                    isLargeDocumentMode: sourceText.utf16.count > Self.largeDocumentThreshold
                )
            )
        }

        private func restyle(textView: NSTextView, displayText: String, selectedRange: NSRange) {
            let theme = CodeEditorTheme.make(for: colorScheme)
            let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

            textView.font = font
            textView.backgroundColor = theme.backgroundColor
            textView.textColor = theme.textColor
            textView.insertionPointColor = theme.textColor
            textView.typingAttributes = [
                .font: font,
                .foregroundColor: theme.textColor,
            ]

            guard
                lastRenderedText != displayText ||
                lastRenderedSelection != selectedRange ||
                lastRenderedLanguage != language ||
                lastRenderedScheme != colorScheme
            else { return }

            lastRenderedText = displayText
            lastRenderedSelection = selectedRange
            lastRenderedLanguage = language
            lastRenderedScheme = colorScheme

            let matchingPair = focusedRegion == nil
                ? CodeEditorHighlighter.matchingPair(in: displayText, language: language, cursorLocation: selectedRange.location)
                : nil

            pendingStyleWorkItem?.cancel()

            if displayText.utf16.count > Self.largeDocumentThreshold {
                let textSnapshot = displayText
                let languageSnapshot = language
                let selectedRangeSnapshot = selectedRange
                let workItem = DispatchWorkItem { [weak textView] in
                    guard let textView, let storage = textView.textStorage else { return }
                    guard textView.string == textSnapshot else { return }
                    let currentSelection = clampedRange(textView.selectedRange(), maxLength: (textView.string as NSString).length)
                    guard currentSelection == selectedRangeSnapshot else { return }
                    let preservedSelection = textView.selectedRanges
                    let spans = CodeEditorHighlighter.spans(for: textSnapshot, language: languageSnapshot)
                    CodeEditorStyler.apply(to: storage, spans: spans, matchingPair: matchingPair, theme: theme, font: font)
                    textView.selectedRanges = preservedSelection
                }
                pendingStyleWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
            } else if let storage = textView.textStorage {
                let preservedSelection = textView.selectedRanges
                let spans = CodeEditorHighlighter.spans(for: displayText, language: language)
                CodeEditorStyler.apply(to: storage, spans: spans, matchingPair: matchingPair, theme: theme, font: font)
                textView.selectedRanges = preservedSelection
            }
        }

        private func applyFirstCompletion(textView: NSTextView) {
            guard let first = CodeEditorHighlighter.completions(for: text.wrappedValue, language: language, cursorLocation: textView.selectedRange().location).first else { return }
            applyCompletion(first, textView: textView)
        }

        private func applyCompletion(_ item: CodeCompletionItem, textView: NSTextView) {
            guard focusedRegion == nil else { return }
            let nsText = text.wrappedValue as NSString
            guard NSMaxRange(item.replacementRange) <= nsText.length else { return }
            let newText = nsText.replacingCharacters(in: item.replacementRange, with: item.insertText)
            let newCursor = item.replacementRange.location + (item.insertText as NSString).length
            text.wrappedValue = newText
            isSynchronizing = true
            textView.string = newText
            textView.setSelectedRange(NSRange(location: newCursor, length: 0))
            isSynchronizing = false
            applyCurrentState(to: textView)
        }

        private func foldCurrentBlock(textView: NSTextView) {
            guard focusedRegion == nil else { return }
            if let region = CodeEditorHighlighter.focusRegion(in: text.wrappedValue, language: language, selectedRange: textView.selectedRange()) {
                focusedRegion = region
            }
        }
    }
}
#else
private struct PlatformCodeEditor: UIViewRepresentable {
    @Binding var text: String
    let language: CodeEditorLanguage
    let colorScheme: ColorScheme
    let action: CodeEditorAction
    let actionToken: Int
    let onSnapshotChange: (CodeEditorSnapshot) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, language: language, colorScheme: colorScheme, onSnapshotChange: onSnapshotChange)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.spellCheckingType = .no
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.textContainer.lineFragmentPadding = 0
        textView.backgroundColor = .clear
        context.coordinator.attach(textView: textView)
        context.coordinator.applyCurrentState(to: textView)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.language = language
        context.coordinator.colorScheme = colorScheme
        context.coordinator.onSnapshotChange = onSnapshotChange

        if context.coordinator.lastHandledActionToken != actionToken {
            context.coordinator.lastHandledActionToken = actionToken
            context.coordinator.handle(action: action, textView: textView)
        }

        context.coordinator.applyCurrentState(to: textView)
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        private static let largeDocumentThreshold = 16_000

        var text: Binding<String>
        var language: CodeEditorLanguage
        var colorScheme: ColorScheme
        var onSnapshotChange: (CodeEditorSnapshot) -> Void
        var isSynchronizing = false
        var lastHandledActionToken = 0
        private var focusedRegion: CodeFocusRegion?
        private var lastRenderedText = ""
        private var lastRenderedSelection = NSRange(location: 0, length: 0)
        private var lastRenderedLanguage: CodeEditorLanguage = .postgresql
        private var lastRenderedScheme: ColorScheme = .light
        private var pendingStyleWorkItem: DispatchWorkItem?
        private weak var textView: UITextView?

        init(text: Binding<String>, language: CodeEditorLanguage, colorScheme: ColorScheme, onSnapshotChange: @escaping (CodeEditorSnapshot) -> Void) {
            self.text = text
            self.language = language
            self.colorScheme = colorScheme
            self.onSnapshotChange = onSnapshotChange
        }

        func attach(textView: UITextView) {
            self.textView = textView
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isSynchronizing else { return }
            guard focusedRegion == nil else { return }

            let newText = textView.text ?? ""
            if text.wrappedValue != newText {
                text.wrappedValue = newText
            }
            applyCurrentState(to: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            applyCurrentState(to: textView)
        }

        func handle(action: CodeEditorAction, textView: UITextView) {
            switch action {
            case .none:
                break
            case .triggerCompletion:
                applyFirstCompletion(textView: textView)
            case .applyCompletion(let item):
                applyCompletion(item, textView: textView)
            case .foldCurrentBlock:
                foldCurrentBlock(textView: textView)
            case .unfoldAll:
                focusedRegion = nil
            }
        }

        func applyCurrentState(to textView: UITextView) {
            let sourceText = text.wrappedValue
            let displayText = focusedRegion.map { (sourceText as NSString).substring(with: $0.sourceRange) } ?? sourceText
            let editable = focusedRegion == nil

            if textView.text != displayText {
                isSynchronizing = true
                textView.text = displayText
                isSynchronizing = false
            }

            textView.isEditable = editable
            textView.isSelectable = true

            let selectedRange = editable ? clampedRange(textView.selectedRange, maxLength: (textView.text as NSString).length) : NSRange(location: 0, length: 0)
            publishSnapshot(sourceText: sourceText, selectedRange: selectedRange)
            restyle(textView: textView, displayText: displayText, selectedRange: selectedRange)
        }

        private func publishSnapshot(sourceText: String, selectedRange: NSRange) {
            let diagnostics = CodeEditorHighlighter.diagnostics(for: sourceText, language: language)
            let completions = focusedRegion == nil
                ? CodeEditorHighlighter.completions(for: sourceText, language: language, cursorLocation: selectedRange.location)
                : []
            let hasFoldableRegion = focusedRegion == nil && CodeEditorHighlighter.focusRegion(in: sourceText, language: language, selectedRange: selectedRange) != nil

            onSnapshotChange(
                CodeEditorSnapshot(
                    diagnostics: diagnostics,
                    completions: completions,
                    hasFoldableRegion: hasFoldableRegion,
                    isFocusedRegionActive: focusedRegion != nil,
                    focusedRegionTitle: focusedRegion?.previewTitle,
                    isLargeDocumentMode: sourceText.utf16.count > Self.largeDocumentThreshold
                )
            )
        }

        private func restyle(textView: UITextView, displayText: String, selectedRange: NSRange) {
            let theme = CodeEditorTheme.make(for: colorScheme)
            let font = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)

            textView.font = font
            textView.backgroundColor = theme.backgroundColor
            textView.textColor = theme.textColor
            textView.tintColor = theme.textColor
            textView.typingAttributes = [
                .font: font,
                .foregroundColor: theme.textColor,
            ]

            guard
                lastRenderedText != displayText ||
                lastRenderedSelection != selectedRange ||
                lastRenderedLanguage != language ||
                lastRenderedScheme != colorScheme
            else { return }

            lastRenderedText = displayText
            lastRenderedSelection = selectedRange
            lastRenderedLanguage = language
            lastRenderedScheme = colorScheme

            let matchingPair = focusedRegion == nil
                ? CodeEditorHighlighter.matchingPair(in: displayText, language: language, cursorLocation: selectedRange.location)
                : nil

            pendingStyleWorkItem?.cancel()

            if displayText.utf16.count > Self.largeDocumentThreshold {
                let textSnapshot = displayText
                let languageSnapshot = language
                let selectedRangeSnapshot = selectedRange
                let workItem = DispatchWorkItem { [weak textView] in
                    guard let textView else { return }
                    guard textView.text == textSnapshot else { return }
                    guard clampedRange(textView.selectedRange, maxLength: textView.textStorage.length) == selectedRangeSnapshot else { return }
                    let preservedSelection = textView.selectedRange
                    let spans = CodeEditorHighlighter.spans(for: textSnapshot, language: languageSnapshot)
                    CodeEditorStyler.apply(to: textView.textStorage, spans: spans, matchingPair: matchingPair, theme: theme, font: font)
                    textView.selectedRange = clampedRange(preservedSelection, maxLength: textView.textStorage.length)
                }
                pendingStyleWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
            } else {
                let preservedSelection = textView.selectedRange
                let spans = CodeEditorHighlighter.spans(for: displayText, language: language)
                CodeEditorStyler.apply(to: textView.textStorage, spans: spans, matchingPair: matchingPair, theme: theme, font: font)
                textView.selectedRange = clampedRange(preservedSelection, maxLength: textView.textStorage.length)
            }
        }

        private func applyFirstCompletion(textView: UITextView) {
            guard let first = CodeEditorHighlighter.completions(for: text.wrappedValue, language: language, cursorLocation: textView.selectedRange.location).first else { return }
            applyCompletion(first, textView: textView)
        }

        private func applyCompletion(_ item: CodeCompletionItem, textView: UITextView) {
            guard focusedRegion == nil else { return }
            let nsText = text.wrappedValue as NSString
            guard NSMaxRange(item.replacementRange) <= nsText.length else { return }
            let newText = nsText.replacingCharacters(in: item.replacementRange, with: item.insertText)
            let newCursor = item.replacementRange.location + (item.insertText as NSString).length
            text.wrappedValue = newText
            isSynchronizing = true
            textView.text = newText
            textView.selectedRange = NSRange(location: newCursor, length: 0)
            isSynchronizing = false
            applyCurrentState(to: textView)
        }

        private func foldCurrentBlock(textView: UITextView) {
            guard focusedRegion == nil else { return }
            if let region = CodeEditorHighlighter.focusRegion(in: text.wrappedValue, language: language, selectedRange: textView.selectedRange) {
                focusedRegion = region
            }
        }
    }
}
#endif
