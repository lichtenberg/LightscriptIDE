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
    
    // Static reference for C callbacks
    private static weak var sharedInstance: ViewController?
    
    private static let playbackEndCallback: @convention(c) () -> Void = {
        DispatchQueue.main.async {
            ViewController.sharedInstance?.handlePlaybackEnded()
        }
    }
    // Add this method to handle natural script ending
    private func handlePlaybackEnded() {
        setButtonsForIdleState()
        setTimeDisplay("00:00.00")
        appendToStatus("Playback completed\n")
        // Any other cleanup you need
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Store reference for C callbacks
        ViewController.sharedInstance = self
        
        setupSplitView()
        setupTextEditor()
        setupStatusWindow()
        updateWindowTitle()
        
        updateCompletionsInBackground()
        initializeLightscript()
    }
    
    private func initializeLightscript() {
        // Initialize the lightscript library
        let result = lightscript_init()
        if result != 0 {
            appendToStatus("Failed to initialize lightscript library\n")
            return
        }
        
        // Set up callbacks
        lightscript_set_time_callback(ViewController.timeCallback)
        lightscript_set_status_callback(ViewController.statusCallback)
        lightscript_set_playback_end_callback(ViewController.playbackEndCallback)
    }
    
    // Static callback functions for C interface
    private static let timeCallback: @convention(c) (Double) -> Void = { time in
        let minutes = Int(time / 60)
        let seconds = Int(time.truncatingRemainder(dividingBy: 60))
        let hundredths = Int((time * 100).truncatingRemainder(dividingBy: 100))
        let timeString = String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
        
        DispatchQueue.main.async {
            ViewController.sharedInstance?.setTimeDisplay(timeString)
        }
    }
    
    private static let statusCallback: @convention(c) (Int32, UnsafePointer<CChar>?) -> Void = { isError, message in
        if let message = message {
            let messageStr = String(cString: message)
            DispatchQueue.main.async {
                ViewController.sharedInstance?.appendToStatus(messageStr + "\n")
                
                // If it's an error, highlight the error line
                if isError != 0 {
                    let errorLine = lightscript_get_error_line()
                    if errorLine > 0 {
                        ViewController.sharedInstance?.highlightErrorLine(Int(errorLine))
                    }
                }
            }
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(self)
        
        // Set up time display after window is fully loaded
        setupTimeDisplay()
        setButtonsForIdleState()
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
    
    func loadFileFromURL(_ url: URL) {
          loadFile(from: url)
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
        guard let scriptText = textView.text, !scriptText.isEmpty else {
            appendToStatus("No script to run\n")
            return
        }
        statusTextView.string = ""

        setButtonsForIdleState()
        // Reset previous script
        lightscript_reset()
        clearErrorHighlight()
        
        // Dig out preferences
        let panelConfig = PreferencesViewController.panelConfigFile
        let lightscriptConfig = PreferencesViewController.lightscriptConfigFile

        guard !panelConfig.isEmpty else {
            appendToStatus("Error: Panel config file not set. Please configure in Settings.\n")
            return
        }

        guard !lightscriptConfig.isEmpty else {
            appendToStatus("Error: Lightscript config file not set. Please configure in Settings.\n")
            return
        }

        if lightscript_tokenize_file(panelConfig) != 0 {
            return
        }
        if lightscript_tokenize_file(lightscriptConfig) != 0 {
            return
        }

        // Parse the script
        let tokenizeResult = lightscript_tokenize_string(scriptText)
        if tokenizeResult != 0 {
            // Error parsing - the callback will handle displaying the error
            return
        }
        
        let parseResult = lightscript_parse_script()
        if parseResult != 0 {
            if parseResult == -3 {
                // Scroll the view to the error line
                highlightErrorLine(Int(lightscript_get_error_line()))
            }
            return
        }
        
        // Connect to device
        lightscript_set_device(PreferencesViewController.deviceAddress)
        let connectResult = lightscript_connect()
        if connectResult != 0 {
            appendToStatus("Failed to connect to device\n")
            return
        }
        
        lightscript_set_script_directory(getCurrentScriptDirectory())
        
        // Start playback with music
        let playbackResult = lightscript_playback_start(1)
        if playbackResult != 0 {
            appendToStatus("Failed to start playback\n")
            lightscript_disconnect()
            return
        }
        setButtonsForPlayingState()
        appendToStatus("Playback started\n")
    }
    
    @IBAction func checkScript(_ sender: Any?) {
        statusTextView.string = ""

        guard let scriptText = textView.text, !scriptText.isEmpty else {
            appendToStatus("No script to check\n")
            return
        }

        // Reset previous script
        lightscript_reset()
        clearErrorHighlight()
  
        // Dig out preferences
        let panelConfig = PreferencesViewController.panelConfigFile
        let lightscriptConfig = PreferencesViewController.lightscriptConfigFile

        guard !panelConfig.isEmpty else {
            appendToStatus("Error: Panel config file not set. Please configure in Settings.\n")
            return
        }

        guard !lightscriptConfig.isEmpty else {
            appendToStatus("Error: Lightscript config file not set. Please configure in Settings.\n")
            return
        }

        if lightscript_tokenize_file(panelConfig) != 0 {
            return
        }
        if lightscript_tokenize_file(lightscriptConfig) != 0 {
            return
        }

        // Parse the script for syntax check only
        let tokenizeResult = lightscript_tokenize_string(scriptText)
        if tokenizeResult == 0 {
            appendToStatus("Script tokenized successfully\n")
            let parserResult = lightscript_parse_script()
            if parserResult == 0 {
                appendToStatus("Script parsed successfully\n")
            } else {
                if parserResult == -3 {
                    highlightErrorLine(Int(lightscript_get_error_line()))
                }
                appendToStatus("Script parsing failed\n")
            }
        }
        
        // Error case is handled by the callback
    }
    
    @IBAction func stopScript(_ sender: Any?) {
        lightscript_playback_stop()
        //lightscript_disconnect()
        setTimeDisplay("00:00.00")
        appendToStatus("Playback interrupted\n")
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
            
            // Add to recent documents
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
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
            
            // Add to recent documents
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch {
            appendToStatus("Error saving file: \(error.localizedDescription)\n")
            NSAlert(error: error).runModal()
        }
    }
    
    // MARK: - File Path Helpers
    
    /// Get the directory path where the currently opened script file lives
    /// - Returns: Directory path as String, or nil if no file is open
    func getCurrentScriptDirectory() -> String? {
        guard let fileURL = currentFileURL else {
            return nil
        }
        return fileURL.deletingLastPathComponent().path
    }
    
    /// Get a path relative to the current script's directory
    /// - Parameter filename: The filename to append to the script directory
    /// - Returns: Full path string, or nil if no script is open
    func getPathRelativeToScript(_ filename: String) -> String? {
        guard let scriptDir = getCurrentScriptDirectory() else {
            return nil
        }
        return URL(fileURLWithPath: scriptDir).appendingPathComponent(filename).path
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
        guard let window = view.window,
              let toolbar = window.toolbar,
              let timeItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "TIME_DISPLAY" }),
              let timeView = timeItem.view,
              let textField = timeView.subviews.first(where: { $0 is NSTextField }) as? NSTextField else {
            return
        }
        
        timeDisplayField = textField
        setTimeDisplay("00:00.00")
    }
    
    /// Updates the time display in the toolbar. Call this from your script engine.
    /// - Parameter timeString: Time in format "MM:SS.HH" (e.g. "01:23.45")
    func setTimeDisplay(_ timeString: String) {
        DispatchQueue.main.async {
            self.timeDisplayField?.stringValue = timeString
        }
    }
    
    // MARK: - Toolbar Button Control
    
    /// Enable or disable the Play button in the toolbar
    /// - Parameter enabled: true to enable, false to gray out
    func setPlayButtonEnabled(_ enabled: Bool) {
        DispatchQueue.main.async {
            if let toolbar = self.view.window?.toolbar,
               let playItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "RUN_SCRIPT" }) {
                playItem.isEnabled = enabled
            }
        }
    }
    
    /// Enable or disable the Check button in the toolbar  
    /// - Parameter enabled: true to enable, false to gray out
    func setCheckButtonEnabled(_ enabled: Bool) {
        DispatchQueue.main.async {
            if let toolbar = self.view.window?.toolbar,
               let checkItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "CHECK_SCRIPT" }) {
                checkItem.isEnabled = enabled
            }
        }
    }
    
    /// Enable or disable the Stop button in the toolbar
    /// - Parameter enabled: true to enable, false to gray out  
    func setStopButtonEnabled(_ enabled: Bool) {
        DispatchQueue.main.async {
            if let toolbar = self.view.window?.toolbar,
               let stopItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "STOP_SCRIPT" }) {
                stopItem.isEnabled = enabled
            }
        }
    }
    
    /// Set button states for idle mode (not playing)
    func setButtonsForIdleState() {
        setPlayButtonEnabled(true)
        setCheckButtonEnabled(true) 
        setStopButtonEnabled(false)
    }
    
    /// Set button states for playing mode
    func setButtonsForPlayingState() {
        setPlayButtonEnabled(false)
        setCheckButtonEnabled(false)
        setStopButtonEnabled(true)
    }
    
    // MARK: - Error Highlighting
    
    private func highlightErrorLine(_ lineNumber: Int) {
        let workItem = DispatchWorkItem {
            // Convert 1-based line number to 0-based
            let targetLine = max(0, lineNumber - 1)
            
            // Get the text content
            guard let text = self.textView.text else { return }
            
            // Find the range for the specified line
            let lines = text.components(separatedBy: .newlines)
            
            guard targetLine < lines.count else { return }
            
            // Calculate the character range for the line
            var charIndex = 0
            for i in 0..<targetLine {
                charIndex += lines[i].count + 1 // +1 for newline
            }
            
            let lineLength = lines[targetLine].count
            let lineRange = NSRange(location: charIndex, length: lineLength)
            
            // For STTextView, work with the text layout manager directly
            let textLayoutManager = self.textView.textLayoutManager
            let textContentManager = self.textView.textContentManager
            
            // Convert NSRange to NSTextRange for STTextView
            if let textRange = NSTextRange(lineRange, in: textContentManager) {
                // Get the bounding rect for the text range
                if let boundingRect = textLayoutManager.textSegmentFrame(in: textRange, type: .standard) {
                    // Scroll to show the error line
                    self.textView.scrollToVisible(boundingRect)
                }
            }
        }
        DispatchQueue.main.async(execute: workItem)
    }
    
    private func clearErrorHighlight() {
        let workItem = DispatchWorkItem {
            // For now, this is a no-op since we need to research STTextView's highlighting API
            // TODO: Implement proper highlight clearing once we understand STTextView's attribute API
        }
        DispatchQueue.main.async(execute: workItem)
    }

    @IBAction func showPreferences(_ sender: Any?) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        if let preferencesController = storyboard.instantiateController(withIdentifier: "PreferencesWindow") as? NSWindowController {
            preferencesController.showWindow(nil)
            preferencesController.window?.center()
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        lightscript_shutdown()
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
        case #selector(showPreferences(_:)):
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

