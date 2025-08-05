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


}

