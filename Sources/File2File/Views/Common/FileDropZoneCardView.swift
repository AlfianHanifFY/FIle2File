import SwiftUI
import UniformTypeIdentifiers

public struct FileDropZoneCardView: View {
    let title: String
    let subtitle: String
    let iconName: String
    let buttonTitle: String
    let onBrowse: () -> Void
    let onDropFiles: ([URL]) -> Void
    
    @State private var isTargeted: Bool = false
    
    public init(
        title: String = "Drag & Drop your file here",
        subtitle: String = "Choose or drop a file to get started",
        iconName: String = "arrow.down.doc.fill",
        buttonTitle: String = "Browse",
        onBrowse: @escaping () -> Void,
        onDropFiles: @escaping ([URL]) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.buttonTitle = buttonTitle
        self.onBrowse = onBrowse
        self.onDropFiles = onDropFiles
    }
    
    public var body: some View {
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

            VStack(spacing: 14) {
                Image(systemName: iconName)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 44))
                    .foregroundColor(isTargeted ? .accentColor : .secondary)

                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button(action: onBrowse) {
                    Label(buttonTitle, systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .help("Browse files on disk")
            }
        }
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            let group = DispatchGroup()
            var collected: [URL] = []
            let lock = NSLock()
            
            for provider in providers {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    defer { group.leave() }
                    if let url = url {
                        lock.lock()
                        collected.append(url)
                        lock.unlock()
                    }
                }
            }
            
            group.notify(queue: .main) {
                if !collected.isEmpty {
                    onDropFiles(collected)
                }
            }
            return true
        }
    }
}
