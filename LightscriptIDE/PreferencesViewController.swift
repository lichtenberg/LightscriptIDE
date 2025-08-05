import AppKit

class PreferencesViewController: NSViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var deviceTextField: NSTextField!
    @IBOutlet weak var panelConfigTextField: NSTextField!
    @IBOutlet weak var lightscriptConfigTextField: NSTextField!
    @IBOutlet weak var verboseLoggingCheckbox: NSSwitch!
    
    // MARK: - UserDefaults Keys
    struct PrefsKeys {
        static let deviceAddress = "DeviceAddress"
        static let panelConfigFile = "PanelConfigFile" 
        static let lightscriptConfigFile = "LightscriptConfigFile"
        static let verboseLogging = "VerboseLogging"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadPreferences()
    }
    
    // MARK: - Actions
    
    @IBAction func selectPanelConfigFile(_ sender: NSButton) {
        selectConfigFile(for: panelConfigTextField, title: "Select Panel Config File")
    }
    
    @IBAction func selectLightscriptConfigFile(_ sender: NSButton) {
        selectConfigFile(for: lightscriptConfigTextField, title: "Select Lightscript Config File")
    }
    
    @IBAction func okButtonClicked(_ sender: NSButton) {
        savePreferences()
        view.window?.close()
    }
    
    @IBAction func cancelButtonClicked(_ sender: NSButton) {
        view.window?.close()
    }
    
    // MARK: - File Selection
    
    private func selectConfigFile(for textField: NSTextField, title: String) {
        let openPanel = NSOpenPanel()
        openPanel.title = title
        openPanel.allowedContentTypes = [.init(filenameExtension: "cfg")!]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        
        if openPanel.runModal() == .OK,
           let url = openPanel.url {
            textField.stringValue = url.path
        }
    }
    
    // MARK: - Preferences Management
    
    private func loadPreferences() {
        let defaults = UserDefaults.standard
        
        deviceTextField?.stringValue = defaults.string(forKey: PrefsKeys.deviceAddress) ?? "usb"
        panelConfigTextField?.stringValue = defaults.string(forKey: PrefsKeys.panelConfigFile) ?? ""
        lightscriptConfigTextField?.stringValue = defaults.string(forKey: PrefsKeys.lightscriptConfigFile) ?? ""
        verboseLoggingCheckbox?.state = defaults.bool(forKey: PrefsKeys.verboseLogging) ? .on : .off
    }
    
    private func savePreferences() {
        let defaults = UserDefaults.standard
        
        defaults.set(deviceTextField.stringValue, forKey: PrefsKeys.deviceAddress)
        defaults.set(panelConfigTextField.stringValue, forKey: PrefsKeys.panelConfigFile) 
        defaults.set(lightscriptConfigTextField.stringValue, forKey: PrefsKeys.lightscriptConfigFile)
        defaults.set(verboseLoggingCheckbox.state == .on, forKey: PrefsKeys.verboseLogging)
    }
    
    // MARK: - Public Access to Settings
    
    static var deviceAddress: String {
        return UserDefaults.standard.string(forKey: PrefsKeys.deviceAddress) ?? "usb"
    }
    
    static var panelConfigFile: String {
        return UserDefaults.standard.string(forKey: PrefsKeys.panelConfigFile) ?? ""
    }
    
    static var lightscriptConfigFile: String {
        return UserDefaults.standard.string(forKey: PrefsKeys.lightscriptConfigFile) ?? ""
    }
    
    static var verboseLogging: Bool {
        return UserDefaults.standard.bool(forKey: PrefsKeys.verboseLogging)
    }
}
