//  Created by Marcin Krzyzanowski
//  https://github.com/krzyzanowskim/STTextView/blob/main/LICENSE.md

import AppKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
          let url = URL(fileURLWithPath: filename)

          // Get the main window's view controller and load the file
          if let mainWindow = NSApp.mainWindow,
             let viewController = mainWindow.contentViewController as? ViewController {
              viewController.loadFileFromURL(url)
              return true
          }
          return false
      }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        print("applicationShouldTerminate called")

        // Check if main window has unsaved changes
        if let mainWindow = NSApp.mainWindow,
           let viewController = mainWindow.contentViewController as? ViewController {

            // Add a method to ViewController to check if modified
            if viewController.isDocumentModified {
                let alert = NSAlert()
                alert.messageText = "Do you want to save the changes to your document?"
                alert.addButton(withTitle: "Save")
                alert.addButton(withTitle: "Don't Save")
                alert.addButton(withTitle: "Cancel")

                let response = alert.runModal()
                switch response {
                case .alertFirstButtonReturn: // Save
                    viewController.saveDocument(nil)
                    return viewController.isDocumentModified ? .terminateCancel : .terminateNow
                case .alertSecondButtonReturn: // Don't Save
                    return .terminateNow
                default: // Cancel
                    return .terminateCancel
                }
            }
        }
        return .terminateNow
    }


}

