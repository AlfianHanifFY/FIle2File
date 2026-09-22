import SwiftUI
import AppKit
import AVKit
import AVFoundation
import UniformTypeIdentifiers

@available(macOS 14.0, *)
public struct VideoToGifToolView: View {
    @State private var item: VideoToGifItem? = nil
    @State private var player: AVPlayer? = nil
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0.0
    @State private var activeTab: PreviewTab = .video
    @State private var playerObserver: Any? = nil
    
    private enum PreviewTab: String, CaseIterable, Identifiable {
        case video = "Video Preview"
        case gif = "Converted GIF"
        
        var id: String { rawValue }
    }
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            
            Divider()
            
            if let activeItem = item {
                mainWorkspaceView(item: activeItem)
            } else {
                emptyDropZoneView
                    .padding(24)
            }
        }
        .onDisappear {
            cleanupPlayer()
        }
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "video.badge.plus")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    Text("Video to GIF")
                        .font(.title2.bold())
                }
                
                Text("Convert MP4, MOV, and video clips into high-quality animated GIFs.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if item != nil {
                HStack(spacing: 10) {
                    Button(action: openFilePicker) {
                        Label("Change Video", systemImage: "arrow.triangle.2.circlepath")
                    }
                    
                    Button(action: clearVideo) {
                        Label("Clear", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Empty Drop Zone
    
    private var emptyDropZoneView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Select Video File")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Choose or drag & drop a video file to convert to animated GIF.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            FileDropZoneCardView(
                title: "Drag & Drop Video File Here",
                subtitle: "Supports MP4, MOV, M4V, and AVI video formats",
                iconName: "video.badge.plus",
                buttonTitle: "Browse Video File...",
                onBrowse: openFilePicker,
                onDropFiles: { urls in
                    if let first = urls.first {
                        self.loadVideo(from: first)
                    }
                }
            )

            Spacer()
        }
    }
    
    // MARK: - Main Workspace View
    
    private func mainWorkspaceView(item: VideoToGifItem) -> some View {
        VStack(spacing: 0) {
            controlsCard(item: item)
                .padding(16)
            
            Divider()
            
            previewArea(item: item)
                .padding(16)
            
            Divider()
            
            bottomActionBar(item: item)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
        }
    }
    
    // MARK: - Controls Panel Card
    
    private func controlsCard(item: VideoToGifItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Trim Range Controls
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("TIMELINE TRIM RANGE")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    let trimmedDuration = max(0, (item.options.endTime - item.options.startTime) / max(0.1, item.options.speedMultiplier))
                    Text(String(format: "Trimmed: %.2fs (Original: %.2fs)", trimmedDuration, item.totalDuration))
                        .font(.caption.bold())
                        .foregroundColor(.accentColor)
                }
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start: \(formatTimestamp(item.options.startTime))")
                            .font(.caption)
                            .monospacedDigit()
                        Slider(
                            value: Binding(
                                get: { item.options.startTime },
                                set: { newValue in
                                    guard var updated = self.item else { return }
                                    let currentEnd = updated.options.endTime
                                    updated.options.startTime = min(newValue, currentEnd - 0.2)
                                    self.item = updated
                                    seekPlayer(to: updated.options.startTime)
                                }
                            ),
                            in: 0...max(0.1, item.totalDuration - 0.2)
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("End: \(formatTimestamp(item.options.endTime))")
                            .font(.caption)
                            .monospacedDigit()
                        Slider(
                            value: Binding(
                                get: { item.options.endTime },
                                set: { newValue in
                                    guard var updated = self.item else { return }
                                    let currentStart = updated.options.startTime
                                    updated.options.endTime = max(newValue, currentStart + 0.2)
                                    self.item = updated
                                    seekPlayer(to: updated.options.endTime)
                                }
                            ),
                            in: 0.2...max(0.2, item.totalDuration)
                        )
                    }
                }
            }
            
            Divider()
            
            // Format options row: FPS, Resolution, Speed
            HStack(spacing: 20) {
                // FPS Picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("FRAME RATE (FPS)")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                    
                    Picker("FPS", selection: Binding(
                        get: { item.options.fps },
                        set: { self.item?.options.fps = $0 }
                    )) {
                        Text("5 FPS (Tiny file)").tag(5)
                        Text("10 FPS").tag(10)
                        Text("15 FPS (Default)").tag(15)
                        Text("20 FPS").tag(20)
                        Text("24 FPS (Smooth)").tag(24)
                        Text("30 FPS (High)").tag(30)
                    }
                    .frame(width: 160)
                }
                
                // Resolution Scale
                VStack(alignment: .leading, spacing: 4) {
                    Text("RESOLUTION SCALE")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                    
                    Picker("Resolution", selection: Binding(
                        get: { item.options.resolution },
                        set: { self.item?.options.resolution = $0 }
                    )) {
                        ForEach(VideoToGifResolution.allCases) { res in
                            Text(res.rawValue).tag(res)
                        }
                    }
                    .frame(width: 150)
                }
                
                // Speed Multiplier
                VStack(alignment: .leading, spacing: 4) {
                    Text("PLAYBACK SPEED")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                    
                    Picker("Speed", selection: Binding(
                        get: { item.options.speedMultiplier },
                        set: { self.item?.options.speedMultiplier = $0 }
                    )) {
                        Text("0.5x (Slow)").tag(0.5)
                        Text("0.75x").tag(0.75)
                        Text("1.0x (Normal)").tag(1.0)
                        Text("1.25x").tag(1.25)
                        Text("1.5x").tag(1.5)
                        Text("2.0x (Fast)").tag(2.0)
                        Text("3.0x (Hyper)").tag(3.0)
                    }
                    .frame(width: 140)
                }
                
                Spacer()
                
                // Convert Button
                Button(action: convertToGif) {
                    Label(
                        item.isConverting ? "Converting..." : "Convert to GIF",
                        systemImage: "sparkles"
                    )
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(item.isConverting)
            }
            
            if item.isConverting {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)
                    
                    Text("Encoding GIF frames... \(Int(item.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }
    
    // MARK: - Preview Area
    
    private func previewArea(item: VideoToGifItem) -> some View {
        VStack(spacing: 12) {
            Picker("Preview Mode", selection: $activeTab) {
                ForEach(PreviewTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
            
            ZStack {
                switch activeTab {
                case .video:
                    if let player = player {
                        VStack(spacing: 8) {
                            MacVideoPlayerView(player: player)
                                .cornerRadius(8)
                            
                            HStack(spacing: 12) {
                                Button(action: togglePlayPause) {
                                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                                
                                Text(formatTimestamp(currentTime))
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                                
                                Slider(
                                    value: $currentTime,
                                    in: 0...max(0.1, item.totalDuration),
                                    onEditingChanged: { editing in
                                        if !editing {
                                            seekPlayer(to: currentTime)
                                        }
                                    }
                                )
                                
                                Text(formatTimestamp(item.totalDuration))
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                        }
                    } else {
                        ProgressView("Loading Video Player...")
                    }
                    
                case .gif:
                    ZStack {
                        checkerboardBackground
                            .cornerRadius(8)
                        
                        if let gifData = item.gifData, let nsImg = NSImage(data: gifData) {
                            Image(nsImage: nsImg)
                                .resizable()
                                .scaledToFit()
                                .padding(12)
                        } else if let errorMsg = item.errorMessage {
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.red)
                                Text(errorMsg)
                                    .foregroundColor(.primary)
                            }
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.stack")
                                    .font(.system(size: 36))
                                    .foregroundColor(.secondary)
                                Text("Click 'Convert to GIF' to create animated GIF preview.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        }
    }
    
    private var checkerboardBackground: some View {
        Canvas { context, size in
            let squareSize: CGFloat = 16
            let rows = Int(ceil(size.height / squareSize))
            let cols = Int(ceil(size.width / squareSize))
            
            for row in 0..<rows {
                for col in 0..<cols {
                    let isEven = (row + col) % 2 == 0
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(Path(rect), with: .color(isEven ? Color(white: 0.92) : Color(white: 0.82)))
                }
            }
        }
    }
    
    // MARK: - Bottom Action Bar
    
    private func bottomActionBar(item: VideoToGifItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.caption.bold())
                
                HStack(spacing: 8) {
                    Text("Original Video: \(item.formattedOriginalFileSize) (\(Int(item.originalSize.width))x\(Int(item.originalSize.height)))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let gifSizeStr = item.formattedGifFileSize {
                        Text("→ GIF: \(gifSizeStr)")
                            .font(.caption2.bold())
                            .foregroundColor(.accentColor)
                    }
                }
            }
            
            Spacer()
            
            if item.gifData != nil {
                Button(action: saveGifFile) {
                    Label("Save GIF As...", systemImage: "square.and.arrow.down")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    // MARK: - Video Player Controls & Helpers
    
    private func setupPlayer(url: URL) {
        cleanupPlayer()
        
        let newPlayer = AVPlayer(url: url)
        self.player = newPlayer
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        self.playerObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            self.currentTime = time.seconds
        }
    }
    
    private func togglePlayPause() {
        guard let p = player else { return }
        if isPlaying {
            p.pause()
            isPlaying = false
        } else {
            p.play()
            isPlaying = true
        }
    }
    
    private func seekPlayer(to seconds: Double) {
        guard let p = player else { return }
        let targetTime = CMTime(seconds: seconds, preferredTimescale: 600)
        p.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    private func cleanupPlayer() {
        if let observer = playerObserver, let p = player {
            p.removeTimeObserver(observer)
            playerObserver = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
    }
    
    private func formatTimestamp(_ seconds: Double) -> String {
        let secs = max(0, seconds)
        let mins = Int(secs) / 60
        let remainderSecs = secs.truncatingRemainder(dividingBy: 60)
        return String(format: "%02d:%05.2f", mins, remainderSecs)
    }
    
    // MARK: - Actions & Logic
    
    private func convertToGif() {
        guard var activeItem = item else { return }
        
        activeItem.isConverting = true
        activeItem.progress = 0.0
        activeItem.errorMessage = nil
        self.item = activeItem
        
        Task {
            do {
                let gifData = try await VideoToGifEngine.convertToGif(
                    url: activeItem.url,
                    options: activeItem.options,
                    progressHandler: { prog in
                        Task { @MainActor in
                            self.item?.progress = prog
                        }
                    }
                )
                
                await MainActor.run {
                    self.item?.gifData = gifData
                    self.item?.isConverting = false
                    self.item?.progress = 1.0
                    self.activeTab = .gif
                }
            } catch {
                await MainActor.run {
                    self.item?.errorMessage = error.localizedDescription
                    self.item?.isConverting = false
                }
            }
        }
    }
    
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        
        if panel.runModal() == .OK, let url = panel.url {
            loadVideo(from: url)
        }
    }
    
    private func loadVideo(from url: URL) {
        Task {
            do {
                let metadata = try await VideoToGifEngine.loadMetadata(from: url)
                let defaultOptions = VideoToGifOptions(
                    startTime: 0,
                    endTime: metadata.duration,
                    fps: 15,
                    resolution: .p480,
                    speedMultiplier: 1.0
                )
                
                let newItem = VideoToGifItem(
                    url: url,
                    name: url.lastPathComponent,
                    totalDuration: metadata.duration,
                    originalSize: metadata.size,
                    fileSizeByteCount: metadata.fileSize,
                    options: defaultOptions
                )
                
                await MainActor.run {
                    self.item = newItem
                    self.setupPlayer(url: url)
                }
            } catch {
                print("Failed to load video metadata: \(error)")
            }
        }
    }
    
    private func handleDroppedProviders(_ providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            if let url = url {
                DispatchQueue.main.async {
                    self.loadVideo(from: url)
                }
            }
        }
    }
    
    private func clearVideo() {
        cleanupPlayer()
        item = nil
    }
    
    private func saveGifFile() {
        guard let activeItem = item, let data = activeItem.gifData else { return }
        
        let defaultName = (activeItem.name as NSString).deletingPathExtension + ".gif"
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = [.gif]
        
        if panel.runModal() == .OK, let saveURL = panel.url {
            try? data.write(to: saveURL)
        }
    }
}

// MARK: - NSViewRepresentable Wrapper for AVPlayerView

private struct MacVideoPlayerView: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.player = player
        playerView.controlsStyle = .inline
        playerView.showsFrameSteppingButtons = true
        return playerView
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}
