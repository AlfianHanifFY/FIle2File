import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var showSavedToast: Bool = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .font(.title)
                            .foregroundColor(.accentColor)
                        Text("Application Settings")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    Text("Configure output destination, appearance mode, and export metadata.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Section 1: Output Directory
                VStack(alignment: .leading, spacing: 12) {
                    Label("Set Output Directory", systemImage: "folder.badge.gearshape")
                        .font(.headline)

                    Text("All generated output files (e.g. .sql statements) will be saved to this folder by default.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.accentColor)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current Destination Path:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(settings.outputDirectoryPath)
                                .font(.system(.callout, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        Button(action: { settings.chooseDirectory() }) {
                            Label("Choose Directory...", systemImage: "ellipsis.circle")
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: openDirectoryInFinder) {
                            Label("Open Folder", systemImage: "arrow.up.forward.app")
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: { settings.resetOutputDirectory() }) {
                            Text("Reset")
                        }
                        .buttonStyle(.bordered)
                        .help("Reset to default Downloads folder")
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1)
                    )

                    Toggle("Automatically save generated files directly to the output directory", isOn: $settings.autoSaveToOutputDirectory)
                        .toggleStyle(.checkbox)
                        .font(.callout)
                        .padding(.top, 2)
                }

                Divider()

                // Section 2: Appearance Mode
                VStack(alignment: .leading, spacing: 12) {
                    Label("Appearance", systemImage: "paintbrush.fill")
                        .font(.headline)

                    Text("Select your preferred color theme for File2File.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Theme Mode:", selection: $settings.appearanceRaw) {
                        ForEach(AppAppearance.allCases) { mode in
                            Text(mode.rawValue).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 400)
                }

                Divider()

                // Section 3: Description
                VStack(alignment: .leading, spacing: 12) {
                    Label("Description & Header Metadata", systemImage: "doc.text.fill")
                        .font(.headline)

                    Text("Set a custom description to include in exported headers and application header info.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom Description / Note:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        TextEditor(text: $settings.customDescription)
                            .font(.body)
                            .frame(height: 90)
                            .padding(6)
                            .scrollContentBackground(.hidden)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(NSColor.separatorColor).opacity(0.6), lineWidth: 1)
                            )
                    }

                    if !settings.customDescription.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("HEADER PREVIEW IN GENERATED FILES:")
                                .font(.caption2.bold())
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("-- Generated by File2File (Xlsx2SQL Module)")
                                ForEach(settings.customDescription.components(separatedBy: .newlines), id: \.self) { line in
                                    Text("-- Description: \(line)")
                                }
                            }
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                        }
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(24)
        }
    }

    private func openDirectoryInFinder() {
        let url = settings.outputDirectoryURL
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
}
