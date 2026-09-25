import SwiftUI
import UniformTypeIdentifiers

public struct FileSelectionStepView: View {
    @Binding var fileData: FileData?
    let onFileLoaded: (FileData) -> Void
    let onNextStep: () -> Void

    @State private var isTargeted: Bool = false
    @State private var isLoading: Bool = false
    @State private var loadingFileName: String? = nil
    @State private var errorMessage: String? = nil

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header Section
            VStack(alignment: .leading, spacing: 4) {
                Text("Select Source File")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Choose or drag & drop an Excel (.xlsx) or CSV (.csv) dataset to begin conversion.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Dropzone Container
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isTargeted ? Color.accentColor : Color(NSColor.separatorColor).opacity(0.8),
                        style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.5, dash: isTargeted ? [] : [6, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color(NSColor.controlBackgroundColor).opacity(0.5))
                    )
                    .frame(height: 200)

                if isLoading {
                    VStack(spacing: 14) {
                        ProgressView()
                            .controlSize(.large)
                            .padding(.bottom, 2)

                        VStack(spacing: 4) {
                            if let name = loadingFileName {
                                Text("Loading '\(name)'...")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            } else {
                                Text("Loading Dataset...")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                            Text("Reading headers & inspecting dataset preview...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "arrow.down.doc.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.system(size: 44))
                            .foregroundColor(isTargeted ? .accentColor : .secondary)

                        VStack(spacing: 4) {
                            Text("Drag & Drop your file here")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("Supports .xlsx, .csv, and tab-separated text files")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Button(action: selectFileWithDialog) {
                            Label("Browse", systemImage: "folder")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .help("Browse files on disk")
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                guard let provider = providers.first else { return false }
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLoading = true
                    loadingFileName = "dropped file"
                }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            processFileAt(url: url)
                        }
                    } else {
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isLoading = false
                            }
                        }
                    }
                }
                return true
            }

            // Error Callout Banner
            if let error = errorMessage {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.1)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.3), lineWidth: 1))
            }

            // Loaded File Details Panel
            if let file = fileData, !isLoading {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: file.format == .xlsx ? "tablecells.fill" : "doc.text.fill")
                                .symbolRenderingMode(.hierarchical)
                                .font(.title2)
                                .foregroundColor(.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(file.name)
                                    .font(.headline)
                                Text(file.format.rawValue.uppercased())
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                                    .foregroundColor(.accentColor)
                            }
                            Text("\(file.totalRows) rows • \(file.headers.count) columns • \(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: onNextStep) {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .help("Proceed to DDL Schema step")
                    }

                    Divider()
                        .opacity(0.5)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detected File Columns (\(file.headers.count)):")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(file.headers, id: \.self) { header in
                                    HStack(spacing: 4) {
                                        Image(systemName: "column")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(header)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.secondary.opacity(0.12))
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
                )
            }
        }
    }

    private func selectFileWithDialog() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType.commaSeparatedText,
            UTType.tabSeparatedText,
            UTType(filenameExtension: "xlsx")!
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            processFileAt(url: url)
        }
    }

    private func processFileAt(url: URL) {
        withAnimation(.easeInOut(duration: 0.2)) {
            isLoading = true
            loadingFileName = url.lastPathComponent
            errorMessage = nil
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try FileParser.parseFile(at: url)
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.fileData = data
                        self.onFileLoaded(data)
                        self.isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.errorMessage = "Failed to parse file: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
            }
        }
    }
}
