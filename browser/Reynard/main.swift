//
//  main.swift
//  Reynard
//
//  Created by Minh Ton on 1/2/26.
//

import Foundation
import GeckoView
import UIKit
import Darwin

private let reynardAcceptLanguages = "zh-CN,zh,en-US,en"
private let reynardLocale = "zh_CN.UTF-8"

private func configureSimplifiedChineseRuntimeLocale() {
    setenv("LANGUAGE", "zh_CN:zh:en_US:en", 1)
    setenv("LC_ALL", reynardLocale, 1)
    setenv("LANG", reynardLocale, 1)
}

private func ensureSimplifiedChineseGeckoUserPreferences() {
    let fileManager = FileManager.default
    let roots = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .flatMap { applicationSupportDirectory in
            [
                applicationSupportDirectory
                    .appendingPathComponent(".mozilla", isDirectory: true)
                    .appendingPathComponent("firefox", isDirectory: true),
                applicationSupportDirectory
                    .appendingPathComponent("mozilla", isDirectory: true)
                    .appendingPathComponent("firefox", isDirectory: true),
                applicationSupportDirectory
                    .appendingPathComponent("Firefox", isDirectory: true),
            ]
        }

    var profileDirectories = Set<URL>()

    for root in roots {
        collectGeckoProfileDirectories(from: root, fileManager: fileManager, into: &profileDirectories)
    }

    for profileDirectory in profileDirectories {
        writeSimplifiedChineseGeckoUserPreferences(in: profileDirectory, fileManager: fileManager)
    }
}

private func collectGeckoProfileDirectories(
    from root: URL,
    fileManager: FileManager,
    into profileDirectories: inout Set<URL>
) {
    guard fileManager.fileExists(atPath: root.path) else {
        return
    }

    var queue: [(url: URL, depth: Int)] = [(root, 0)]
    var visited = Set<URL>()

    while let item = queue.first {
        queue.removeFirst()

        let url = item.url.standardizedFileURL
        guard visited.insert(url).inserted else {
            continue
        }

        let prefsURL = url.appendingPathComponent("prefs.js", isDirectory: false)
        let userPrefsURL = url.appendingPathComponent("user.js", isDirectory: false)

        if fileManager.fileExists(atPath: prefsURL.path) ||
            fileManager.fileExists(atPath: userPrefsURL.path) {
            profileDirectories.insert(url)
        }

        guard item.depth < 3,
              let children = try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsPackageDescendants]
              ) else {
            continue
        }

        for child in children {
            guard (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                continue
            }
            queue.append((child, item.depth + 1))
        }
    }
}

private func writeSimplifiedChineseGeckoUserPreferences(in profileDirectory: URL, fileManager: FileManager) {
    let userPrefsURL = profileDirectory.appendingPathComponent("user.js", isDirectory: false)
    let managedPrefs = [
        "intl.accept_languages": reynardAcceptLanguages,
        "intl.locale.requested": "zh-CN",
    ]

    var lines: [String] = []

    if let existing = try? String(contentsOf: userPrefsURL, encoding: .utf8) {
        let managedKeys = Set(managedPrefs.keys)
        lines = existing.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                !managedKeys.contains { key in
                    line.contains("\"\(key)\"") || line.contains("'\(key)'")
                }
            }
    }

    if !lines.isEmpty, lines.last?.isEmpty == false {
        lines.append("")
    }

    lines.append("// Reynard zh-Hans defaults for website language negotiation.")
    for (key, value) in managedPrefs.sorted(by: { $0.key < $1.key }) {
        lines.append("user_pref(\"\(key)\", \"\(value)\");")
    }

    do {
        try lines.joined(separator: "\n").appending("\n").write(to: userPrefsURL, atomically: true, encoding: .utf8)
    } catch {
        return
    }
}

@available(iOS, introduced: 13.0, obsoleted: 14.0)
private func configureUnsandboxedAppDataDirectories() {
    guard let cachesDirectory = FileManager.default.urls(
        for: .cachesDirectory,
        in: .userDomainMask
    ).first else {
        return
    }
    
    guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
        return
    }
    
    let appDataDirectory = cachesDirectory
        .appendingPathComponent(bundleIdentifier, isDirectory: true)
        .appendingPathComponent(".mozilla", isDirectory: true)
        .appendingPathComponent("firefox", isDirectory: true)
    
    do {
        try FileManager.default.createDirectory(
            at: appDataDirectory,
            withIntermediateDirectories: true
        )
    } catch {
        return
    }
    
    setenv("MOZ_APP_DATA", appDataDirectory.path, 1)
    setenv("MOZ_LOCAL_APP_DATA", appDataDirectory.path, 1)
}

configureSimplifiedChineseRuntimeLocale()
UserDataMigration.shared.run()
JITController.shared.start()
if #unavailable(iOS 14.0),
   getEntitlementValue("com.apple.private.security.no-sandbox") {
    configureUnsandboxedAppDataDirectories()
}
ensureSimplifiedChineseGeckoUserPreferences()
GeckoRuntime.main(argc: CommandLine.argc, argv: CommandLine.unsafeArgv)
