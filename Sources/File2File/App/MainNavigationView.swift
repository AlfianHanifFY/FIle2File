import SwiftUI

public struct MainNavigationView: View {
    @State private var selectedTool: AppTool? = AppTool.allTools.first
    @ObservedObject private var settings = AppSettings.shared

    public init() {}

    public var body: some View {
        NavigationSplitView {
            sidebarContent
                .listStyle(.sidebar)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            detailContent
        }
        .preferredColorScheme(settings.appearance.colorScheme)
    }

    private var sidebarContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sidebarHeader
                .padding(.horizontal, 12)
                .padding(.top, 12)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(AppToolCategory.allCases) { category in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.rawValue.uppercased())
                                .font(.caption2.bold())
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.top, 4)
                            
                            ForEach(AppTool.allTools.filter { $0.category == category }) { tool in
                                SidebarToolRowView(
                                    tool: tool,
                                    isSelected: selectedTool == tool,
                                    onSelect: {
                                        withAnimation(.easeInOut(duration: 0.22)) {
                                            selectedTool = tool
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
               let nsImage = NSImage(contentsOf: iconURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .cornerRadius(6)
            } else {
                Image(systemName: "folder.badge.gearshape")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("File2File")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("Data Conversion Utility")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SidebarToolRowView: View {
    let tool: AppTool
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: {
            if tool.isAvailable {
                onSelect()
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: tool.icon)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(
                        isSelected
                        ? .white
                        : (isHovered
                           ? .accentColor
                           : (tool.isAvailable ? .accentColor.opacity(0.85) : .secondary))
                    )
                    .scaleEffect(isHovered && !isSelected ? 1.1 : 1.0)
                    .frame(width: 20)

                Text(tool.name)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(
                        isSelected
                        ? .white
                        : (isHovered
                           ? .primary
                           : (tool.isAvailable ? .primary.opacity(0.9) : .secondary))
                    )

                Spacer()

                if !tool.isAvailable {
                    Text("Soon")
                        .font(.caption2.bold())
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(
                                isSelected
                                ? Color.white.opacity(0.2)
                                : Color.secondary.opacity(0.15)
                            )
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected
                        ? Color.accentColor
                        : (isHovered && tool.isAvailable ? Color.accentColor.opacity(0.12) : Color.clear)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!tool.isAvailable)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) {
                isHovered = hovering
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isSelected)
        .animation(.easeInOut(duration: 0.18), value: isHovered)
    }
}

extension MainNavigationView {

    @ViewBuilder
    private var detailContent: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            if let tool = selectedTool {
                switch tool.id {
                case "xlsx2sql":
                    Xlsx2SQLToolView()
                case "imageCompressor":
                    ImageCompressorToolView()
                case "removeBackground":
                    if #available(macOS 14.0, *) {
                        BackgroundRemoverToolView()
                    } else {
                        Text("Background Remover requires macOS 14.0 Sonoma or later.")
                            .foregroundColor(.secondary)
                    }
                case "video2gif":
                    if #available(macOS 14.0, *) {
                        VideoToGifToolView()
                    } else {
                        Text("Video to GIF requires macOS 14.0 Sonoma or later.")
                            .foregroundColor(.secondary)
                    }
                case "imageToPdf":
                    PdfConverterToolView(initialMode: .imageToPdf)
                case "pdfToImage":
                    PdfConverterToolView(initialMode: .pdfToImage)
                case "mergePdf":
                    PdfConverterToolView(initialMode: .mergePdf)
                case "splitPdf":
                    PdfConverterToolView(initialMode: .splitPdf)
                case "signPdf":
                    PdfConverterToolView(initialMode: .signPdf)
                case "csv2json":
                    Csv2JsonToolView()
                case "excel2csv":
                    Excel2CsvToolView()
                case "settings":
                    SettingsView()
                default:
                    placeholderToolView(tool)
                }
            } else {
                emptySelectionView
            }
        }
    }

    private func placeholderToolView(_ tool: AppTool) -> some View {
        VStack(spacing: 16) {
            Image(systemName: tool.icon)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            
            Text(tool.name)
                .font(.title)
                .fontWeight(.bold)
            
            Text(tool.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Coming soon in a future File2File release.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.secondary.opacity(0.12)))
        }
        .padding()
    }

    private var emptySelectionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Tool Selected")
                .font(.headline)
            
            Text("Select a tool from the sidebar to start processing files.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
