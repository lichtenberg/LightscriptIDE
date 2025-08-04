//  Created by Marcin Krzyzanowski
//  https://github.com/krzyzanowskim/STTextView/blob/main/LICENSE.md

import AppKit
import STTextView
import SwiftUI
import UniformTypeIdentifiers

final class ViewController: NSViewController {
    private var textView: STTextView!
    private var statusTextView: NSTextView!
    private var splitView: NSSplitView!
    private var completions: [Completion.Item] = []
    private var currentFileURL: URL?
    
    // Time display
    private var timeDisplayField: NSTextField?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupSplitView()
        setupTextEditor()
        setupStatusWindow()
        updateWindowTitle()
        
        updateCompletionsInBackground()
        setupTimeDisplay()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(self)
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    private func setupSplitView() {
        splitView = NSSplitView()
        splitView.isVertical = false
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(splitView)
        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: view.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupTextEditor() {
        let scrollView = STTextView.scrollableTextView()
        textView = scrollView.documentView as? STTextView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true

        let paragraph = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraph.lineHeightMultiple = 1.2
        textView.defaultParagraphStyle = paragraph

        textView.font = NSFont.monospacedSystemFont(ofSize: 0, weight: .regular)
        textView.text = ""
        textView.isHorizontallyResizable = false
        textView.highlightSelectedLine = true
        textView.isIncrementalSearchingEnabled = true
        textView.showsInvisibleCharacters = false
        textView.textDelegate = self
        textView.showsLineNumbers = true
        textView.gutterView?.areMarkersEnabled = true
        textView.gutterView?.drawSeparator = true
        
        splitView.addArrangedSubview(scrollView)
    }
    
    private func setupStatusWindow() {
        let statusScrollView = NSScrollView()
        statusScrollView.translatesAutoresizingMaskIntoConstraints = false
        statusScrollView.hasVerticalScroller = true
        statusScrollView.hasHorizontalScroller = false
        statusScrollView.autohidesScrollers = true
        statusScrollView.borderType = .lineBorder
        
        statusTextView = NSTextView()
        statusTextView.isEditable = false
        statusTextView.isSelectable = true
        statusTextView.isRichText = false
        statusTextView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        statusTextView.backgroundColor = NSColor.controlBackgroundColor
        statusTextView.textColor = NSColor.textColor
        statusTextView.string = "Ready\n"
        
        // Configure text container
        statusTextView.textContainer?.widthTracksTextView = true
        statusTextView.textContainer?.containerSize = NSSize(width: statusScrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        statusTextView.isHorizontallyResizable = false
        statusTextView.isVerticallyResizable = true
        statusTextView.autoresizingMask = [.width]
        
        statusScrollView.documentView = statusTextView
        splitView.addArrangedSubview(statusScrollView)
        
        // Set initial split position after layout
        DispatchQueue.main.async {
            self.splitView.setPosition(self.splitView.bounds.height - 120, ofDividerAt: 0)
        }
    }

    @IBAction func toggleTextWrapMode(_ sender: Any?) {
        textView.isHorizontallyResizable.toggle()
    }

    @IBAction func toggleInvisibles(_ sender: Any?) {
        //textView.showsInvisibleCharacters.toggle()
    }
    
    @IBAction func toggleRuler(_ sender: Any?) {
        textView.showsLineNumbers.toggle()
    }
    
    @IBAction func runScript(_ sender: Any?) {
        appendToStatus("Running script...\n")
        setTimeDisplay("00:00.00")
        // TODO: Integrate with script interpreter
        appendToStatus("Script execution not yet implemented.\n")
    }
    
    @IBAction func checkScript(_ sender: Any?) {
        appendToStatus("Checking script syntax...\n")
        // TODO: Integrate with script syntax checker
        appendToStatus("Syntax check not yet implemented.\n")
    }
    
    @IBAction func stopScript(_ sender: Any?) {
        appendToStatus("Stopping script...\n")
        setTimeDisplay("00:00.00")
        // TODO: Stop script execution
        appendToStatus("Script stopped.\n")
    }
    
    private func appendToStatus(_ message: String) {
        DispatchQueue.main.async {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.textColor
            ]
            let attributedMessage = NSAttributedString(string: message, attributes: attributes)
            self.statusTextView.textStorage?.append(attributedMessage)
            self.statusTextView.scrollToEndOfDocument(nil)
        }
    }
    
    // MARK: - File Operations
    
    @IBAction func newDocument(_ sender: Any?) {
        textView.text = ""
        currentFileURL = nil
        updateWindowTitle()
        appendToStatus("New document created\n")
    }
    
    @IBAction func openDocument(_ sender: Any?) {
        let openPanel = NSOpenPanel()
        var allowedTypes: [UTType] = [.plainText]
        if let lightscriptType = UTType(filenameExtension: "ls2") {
            allowedTypes.append(lightscriptType)
        }
        if let lsType = UTType(filenameExtension: "ls") {
            allowedTypes.append(lsType)
        }
        openPanel.allowedContentTypes = allowedTypes
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        
        if openPanel.runModal() == .OK,
           let url = openPanel.url {
            loadFile(from: url)
        }
    }
    
    @IBAction func saveDocument(_ sender: Any?) {
        if let url = currentFileURL {
            saveFile(to: url)
        } else {
            saveDocumentAs(sender)
        }
    }
    
    @IBAction func saveDocumentAs(_ sender: Any?) {
        let savePanel = NSSavePanel()
        var allowedTypes: [UTType] = [.plainText]
        if let lightscriptType = UTType(filenameExtension: "ls") {
            allowedTypes.append(lightscriptType)
        }
        if let lsType = UTType(filenameExtension: "ls2") {
            allowedTypes.append(lsType)
        }
        savePanel.allowedContentTypes = allowedTypes
        savePanel.canCreateDirectories = true
        
        if savePanel.runModal() == .OK,
           let url = savePanel.url {
            saveFile(to: url)
            currentFileURL = url
            updateWindowTitle()
        }
    }
    
    private func loadFile(from url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            textView.text = content
            currentFileURL = url
            updateWindowTitle()
            appendToStatus("Loaded file: \(url.lastPathComponent)\n")
        } catch {
            appendToStatus("Error loading file: \(error.localizedDescription)\n")
            NSAlert(error: error).runModal()
        }
    }
    
    private func saveFile(to url: URL) {
        do {
            guard let text = textView.text else {
                appendToStatus("Error: No text to save\n")
                return
            }
            try text.write(to: url, atomically: true, encoding: .utf8)
            appendToStatus("Saved file: \(url.lastPathComponent)\n")
        } catch {
            appendToStatus("Error saving file: \(error.localizedDescription)\n")
            NSAlert(error: error).runModal()
        }
    }
    
    private func updateWindowTitle() {
        if let url = currentFileURL {
            view.window?.title = "LightscriptIDE - \(url.lastPathComponent)"
        } else {
            view.window?.title = "LightscriptIDE - Untitled"
        }
    }
    
    // MARK: - Time Display
    
    private func setupTimeDisplay() {
        // Find the time display field in the toolbar
        if let toolbar = view.window?.toolbar,
           let timeItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "TIME_DISPLAY" }),
           let timeView = timeItem.view,
           let textField = timeView.subviews.first(where: { $0 is NSTextField }) as? NSTextField {
            timeDisplayField = textField
            setTimeDisplay("00:00.00")
        }
    }
    
    /// Updates the time display in the toolbar. Call this from your script engine.
    /// - Parameter timeString: Time in format "MM:SS.HH" (e.g. "01:23.45")
    func setTimeDisplay(_ timeString: String) {
        DispatchQueue.main.async {
            self.timeDisplayField?.stringValue = timeString
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        completionTask?.cancel()
    }

    private var completionTask: Task<(), Never>?

    private func updateCompletionsInBackground() {
        completionTask?.cancel()
        completionTask = Task(priority: .background) {
            var arr: Set<String> = []

            for await word in Tokenizer.words(textView.text ?? "") where !Task.isCancelled {
                arr.insert(word.string)
            }

            if Task.isCancelled {
                return
            }

            self.completions = arr
                .filter {
                    $0.count > 2
                }
                .sorted { lhs, rhs in
                    lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
                }
                .map { word in
                    let symbol: String
                    if let firstCharacter = word.first, firstCharacter.isASCII, firstCharacter.isLetter {
                        symbol = "\(word.first!.lowercased()).square"
                    } else {
                        symbol = "note.text"
                    }

                    return Completion.Item(id: UUID().uuidString, label: word.localizedCapitalized, symbolName: symbol, insertText: word)
                }
        }
    }
}

// MARK: STTextViewDelegate

extension ViewController: STTextViewDelegate {

    func textView(_ textView: STTextView, didChangeTextIn affectedCharRange: NSTextRange, replacementString: String) {
        // Continous completion update disabled due to bad performance for large strings
        // updateCompletionsInBackground()
    }
    

    // Completion
    func textView(_ textView: STTextView, completionItemsAtLocation location: NSTextLocation) async -> [any STCompletionItem]? {
        
        // fake delay
        // try? await Task.sleep(nanoseconds: UInt64.random(in: 0...1) * 1_000_000_000)

        var word: String?
        textView.textLayoutManager.enumerateSubstrings(from: location, options: [.byWords, .reverse]) { substring, substringRange, enclosingRange, stop in
            word = substring
            stop.pointee = true
        }

        if let word {
            return completions.filter { item in
                if Task.isCancelled {
                    return false
                }
                return item.insertText.hasPrefix(word.localizedLowercase)
            }
        }

        return nil
    }

    func textView(_ textView: STTextView, insertCompletionItem item: any STCompletionItem) {
        guard let completionItem = item as? Completion.Item else {
            fatalError()
        }

        textView.insertText(completionItem.insertText)
    }
}

// MARK: - Menu Validation

extension ViewController: NSMenuItemValidation {
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(newDocument(_:)):
            return true
        case #selector(openDocument(_:)):
            return true
        case #selector(saveDocument(_:)):
            return true
        case #selector(saveDocumentAs(_:)):
            return true
        case #selector(runScript(_:)):
            return true
        case #selector(checkScript(_:)):
            return true
        case #selector(stopScript(_:)):
            return true
        case #selector(toggleTextWrapMode(_:)):
            return true
        case #selector(toggleInvisibles(_:)):
            return true
        case #selector(toggleRuler(_:)):
            return true
        default:
            return false
        }
    }
}

private extension StringProtocol {
    func linesRanges() -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        let stringRange = startIndex..<endIndex
        var currentIndex = startIndex
        while currentIndex < stringRange.upperBound {
            let lineRange = lineRange(for: currentIndex..<currentIndex)
            ranges.append(lineRange)
            if !stringRange.overlaps(lineRange) {
                break
            }
            currentIndex = lineRange.upperBound
        }
        return ranges
    }
}

