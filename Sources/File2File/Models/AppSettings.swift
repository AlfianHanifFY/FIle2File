import SwiftUI
import AppKit

public enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System Default"
    case light = "Light Mode"
    case dark = "Dark Mode"
    
    public var id: String { rawValue }
    
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    @AppStorage("outputDirectoryPath") public var outputDirectoryPath: String = ""
    @AppStorage("appearanceRaw") public var appearanceRaw: String = AppAppearance.system.rawValue
    @AppStorage("customDescription") public var customDescription: String = "Converted using File2File Data Utility"
    @AppStorage("autoSaveToOutputDirectory") public var autoSaveToOutputDirectory: Bool = false

    public init() {
        if outputDirectoryPath.isEmpty {
            outputDirectoryPath = defaultDirectoryPath
        }
    }

    public var defaultDirectoryPath: String {
        if let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            return downloadsURL.path
        }
        return NSHomeDirectory()
    }

    public var appearance: AppAppearance {
        get { AppAppearance(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }

    public var outputDirectoryURL: URL {
        let path = outputDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return URL(fileURLWithPath: defaultDirectoryPath, isDirectory: true)
    }

    public func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Directory"
        panel.title = "Select Output Directory"
        if FileManager.default.fileExists(atPath: outputDirectoryPath) {
            panel.directoryURL = URL(fileURLWithPath: outputDirectoryPath)
        }

        if panel.runModal() == .OK, let url = panel.url {
            outputDirectoryPath = url.path
        }
    }

    public func resetOutputDirectory() {
        outputDirectoryPath = defaultDirectoryPath
    }

    public func saveOutputFile(filename: String, content: String) throws -> URL {
        let dirURL = outputDirectoryURL
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        let fileURL = dirURL.appendingPathComponent(filename)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
