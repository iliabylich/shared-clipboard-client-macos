import Cocoa
import Carbon
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var settingsWindow: NSWindow!
    var monitor: Any?

    var clipboardTimer: Timer?
    var lastChangeCount: Int = NSPasteboard.general.changeCount
    var pollingTimer: Timer?
    var trayButton: NSStatusBarButton?

    var redImage: NSImage?
    var greenImage: NSImage?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Hide Dock icon
        NSApp.setActivationPolicy(.accessory)

        redImage = NSImage(named: "red")
        greenImage = NSImage(named: "green")

        buildMenu()
        startClipboardPolling()

        mpclipboard_setup()
        let config = mpclipboard_config_read_from_xdg_config_dir()
        if config == nil {
            fputs("failed to read config, exiting...", stderr)
            NSApp.terminate(self)
        }
        mpclipboard_start_thread(config)

        startPolling()
    }

    func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = redImage
            trayButton = button
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(AppDelegate.quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc
    func quit() {
        mpclipboard_stop_thread()
        print("Quitting...")
        NSApp.terminate(self)
    }

    func startClipboardPolling() {
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let pasteboard = NSPasteboard.general
            if pasteboard.changeCount != self.lastChangeCount {
                self.lastChangeCount = pasteboard.changeCount
                if let copiedText = pasteboard.string(forType: .string) {
                    copiedText.withCString { cString in
                        let ptr: UnsafePointer<UInt8> = UnsafeRawPointer(cString).assumingMemoryBound(to: UInt8.self)
                        mpclipboard_send(ptr)
                    }
                }
            }
        }

        RunLoop.main.add(clipboardTimer!, forMode: .common)
    }

    func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { [self] _ in
            let output = mpclipboard_poll()
            if let connectivityPtr = output.connectivity {
                let connectivity = connectivityPtr.pointee == true
                free(connectivityPtr)
                if connectivity {
                    trayButton?.image = greenImage
                } else {
                    trayButton?.image = redImage
                }
            }
            if let textPtr = output.text {
                let text = String(cString: textPtr)
                free(textPtr)
                let pasteboard = NSPasteboard.general
                pasteboard.declareTypes([.string], owner: nil)
                pasteboard.setString(text, forType: .string)
            }
        })
    }
}
