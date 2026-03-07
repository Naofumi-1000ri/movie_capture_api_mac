#!/usr/bin/env swift

import AppKit
import Foundation

struct FixtureConfiguration {
    let title: String
    let token: String
    let width: Double
    let height: Double
    let readyFile: String?

    static func parse() throws -> FixtureConfiguration {
        var title: String?
        var token: String?
        var width = 980.0
        var height = 740.0
        var readyFile: String?

        var iterator = CommandLine.arguments.dropFirst().makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--title":
                title = iterator.next()
            case "--token":
                token = iterator.next()
            case "--width":
                if let value = iterator.next(), let parsed = Double(value) {
                    width = parsed
                } else {
                    throw FixtureError.invalidArgument("--width requires a number")
                }
            case "--height":
                if let value = iterator.next(), let parsed = Double(value) {
                    height = parsed
                } else {
                    throw FixtureError.invalidArgument("--height requires a number")
                }
            case "--ready-file":
                readyFile = iterator.next()
            default:
                throw FixtureError.invalidArgument("Unknown argument: \(argument)")
            }
        }

        guard let title else {
            throw FixtureError.invalidArgument("--title is required")
        }

        return FixtureConfiguration(
            title: title,
            token: token ?? title,
            width: width,
            height: height,
            readyFile: readyFile
        )
    }
}

enum FixtureError: Error, CustomStringConvertible {
    case invalidArgument(String)

    var description: String {
        switch self {
        case .invalidArgument(let message):
            return message
        }
    }
}

final class FixtureBackgroundView: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor(calibratedRed: 0.96, green: 0.94, blue: 0.88, alpha: 1.0).setFill()
        dirtyRect.fill()

        let sidebarRect = NSRect(x: 0, y: 0, width: 72, height: bounds.height)
        NSColor(calibratedRed: 0.06, green: 0.30, blue: 0.54, alpha: 1.0).setFill()
        sidebarRect.fill()

        let accentRect = NSRect(x: 72, y: 0, width: bounds.width - 72, height: 120)
        NSColor(calibratedRed: 0.94, green: 0.47, blue: 0.25, alpha: 1.0).setFill()
        accentRect.fill()
    }
}

final class FixtureAppDelegate: NSObject, NSApplicationDelegate {
    private let configuration: FixtureConfiguration
    private var window: NSWindow?

    init(configuration: FixtureConfiguration) {
        self.configuration = configuration
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.mainMenu = makeMainMenu()

        let visibleFrame = NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
            ?? NSRect(x: 120, y: 120, width: 1440, height: 900)

        let frame = NSRect(
            x: visibleFrame.minX + 120,
            y: visibleFrame.maxY - configuration.height - 120,
            width: configuration.width,
            height: configuration.height
        )

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = configuration.title
        window.titleVisibility = .visible
        window.isReleasedWhenClosed = false
        window.center()
        window.collectionBehavior = [.moveToActiveSpace]
        window.contentView = makeContentView()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
        publishReadyState()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        let quitItem = NSMenuItem(
            title: "Quit Fixture",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu

        return mainMenu
    }

    private func makeContentView() -> NSView {
        let root = FixtureBackgroundView(frame: .zero)

        let badge = NSTextField(labelWithString: "MCP SELF-CAPTURE FIXTURE")
        badge.font = .systemFont(ofSize: 13, weight: .semibold)
        badge.textColor = NSColor.white
        badge.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: configuration.token)
        title.font = .monospacedSystemFont(ofSize: 34, weight: .bold)
        title.textColor = NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.17, alpha: 1.0)
        title.maximumNumberOfLines = 2
        title.lineBreakMode = .byWordWrapping
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = NSTextField(labelWithString: "Target this exact window title and verify that the recorded file is created.")
        subtitle.font = .systemFont(ofSize: 19, weight: .medium)
        subtitle.textColor = NSColor(calibratedRed: 0.16, green: 0.19, blue: 0.24, alpha: 1.0)
        subtitle.maximumNumberOfLines = 0
        subtitle.lineBreakMode = .byWordWrapping
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let flow = NSTextField(labelWithString: "Expected flow: list_sources -> resolve_target -> start_recording -> get_status")
        flow.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        flow.textColor = NSColor(calibratedRed: 0.16, green: 0.19, blue: 0.24, alpha: 1.0)
        flow.maximumNumberOfLines = 0
        flow.lineBreakMode = .byWordWrapping
        flow.translatesAutoresizingMaskIntoConstraints = false

        let footer = NSTextField(labelWithString: "This window is intentionally deterministic so AI can resolve it without AppleScript or browser automation.")
        footer.font = .systemFont(ofSize: 15, weight: .regular)
        footer.textColor = NSColor(calibratedRed: 0.20, green: 0.23, blue: 0.28, alpha: 1.0)
        footer.maximumNumberOfLines = 0
        footer.lineBreakMode = .byWordWrapping
        footer.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(badge)
        root.addSubview(title)
        root.addSubview(subtitle)
        root.addSubview(flow)
        root.addSubview(footer)

        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: root.topAnchor, constant: 44),
            badge.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 104),

            title.topAnchor.constraint(equalTo: badge.bottomAnchor, constant: 54),
            title.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 104),
            title.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -56),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 28),
            subtitle.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 104),
            subtitle.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -56),

            flow.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 32),
            flow.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 104),
            flow.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -56),

            footer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 104),
            footer.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -56),
            footer.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -48)
        ])

        return root
    }

    private func publishReadyState() {
        if let readyFile = configuration.readyFile {
            FileManager.default.createFile(
                atPath: readyFile,
                contents: Data(configuration.title.utf8)
            )
        }
    }
}

do {
    let configuration = try FixtureConfiguration.parse()
    let app = NSApplication.shared
    let delegate = FixtureAppDelegate(configuration: configuration)
    app.delegate = delegate
    app.run()
} catch {
    fputs("capture_fixture.swift: \(error)\n", stderr)
    exit(1)
}
