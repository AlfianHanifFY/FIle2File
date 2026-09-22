import SwiftUI
import AppKit

public struct ImagePreviewComparisonView: View {
    public let item: ImageItem
    
    @State private var viewMode: PreviewViewMode = .split
    @State private var splitRatio: CGFloat = 0.5
    
    public enum PreviewViewMode: String, CaseIterable, Identifiable {
        case split = "Split Slider"
        case sideBySide = "Side by Side"
        case compressedOnly = "Compressed"
        case originalOnly = "Original"
        
        public var id: String { rawValue }
        
        public var iconName: String {
            switch self {
            case .split: return "arrow.left.and.right.square"
            case .sideBySide: return "square.split.2x1"
            case .compressedOnly: return "photo"
            case .originalOnly: return "photo.fill"
            }
        }
    }
    
    public init(item: ImageItem) {
        self.item = item
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            statsHeaderCard
            
            comparisonContainerView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Stats Header
    
    private var statsHeaderCard: some View {
        HStack(spacing: 14) {
            // Left: Original & Compressed Comparison Metrics
            HStack(spacing: 10) {
                // Original Metadata
                VStack(alignment: .leading, spacing: 2) {
                    Text("Original")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(item.formattedOriginalSize)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("\(item.originalWidth) × \(item.originalHeight)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.secondary.opacity(0.12)))
                    }
                }
                
                Image(systemName: "arrow.right")
                    .font(.caption.bold())
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.horizontal, 2)
                
                // Compressed Metadata
                VStack(alignment: .leading, spacing: 2) {
                    Text("Compressed")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    if item.isCompressing {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Compressing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if let _ = item.compressedData {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(item.formattedCompressedSize)
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            if let w = item.compressedWidth, let h = item.compressedHeight {
                                Text("\(w) × \(h)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
                            }
                        }
                    } else {
                        Text("Ready to compress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer(minLength: 16)
            
            // Right: Savings Badge & Dropdown View Mode Selector
            HStack(spacing: 12) {
                // Savings Badge
                if !item.isCompressing, item.compressedData != nil {
                    HStack(spacing: 6) {
                        Text(item.savingsPercentageString)
                            .font(.subheadline.bold())
                            .foregroundColor(item.savingsBytes >= 0 ? .green : .red)
                        
                        Text("\(ByteCountFormatter.string(fromByteCount: max(0, item.savingsBytes), countStyle: .file)) saved")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(item.savingsBytes >= 0 ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                    )
                }
                
                // Dropdown View Mode Selector
                Picker("View", selection: $viewMode) {
                    ForEach(PreviewViewMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.iconName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }
    
    // MARK: - Image Preview Body
    
    @ViewBuilder
    private var comparisonContainerView: some View {
        let origImage = NSImage(data: item.originalData)
        let compImage = item.compressedData.flatMap { NSImage(data: $0) } ?? origImage
        
        GeometryReader { geo in
            ZStack {
                switch viewMode {
                case .split:
                    if let orig = origImage, let comp = compImage {
                        splitImageView(original: orig, compressed: comp, size: geo.size)
                    }
                case .sideBySide:
                    HStack(spacing: 2) {
                        VStack {
                            Text("Original")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                            if let orig = origImage {
                                Image(nsImage: orig)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(8)
                            }
                        }
                        Divider()
                        VStack {
                            Text("Compressed")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                            if let comp = compImage {
                                Image(nsImage: comp)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(8)
                            }
                        }
                    }
                case .compressedOnly:
                    if let comp = compImage {
                        Image(nsImage: comp)
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                    }
                case .originalOnly:
                    if let orig = origImage {
                        Image(nsImage: orig)
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                    }
                }
            }
        }
    }
    
    private func splitImageView(original: NSImage, compressed: NSImage, size: CGSize) -> some View {
        ZStack {
            // Compressed Image (Base)
            Image(nsImage: compressed)
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
            
            // Original Image (Clipped overlay)
            Image(nsImage: original)
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
                .clipShape(
                    SplitClipShape(ratio: splitRatio)
                )
            
            // Divider Handle Line
            GeometryReader { _ in
                let handleX = size.width * splitRatio
                
                Path { path in
                    path.move(to: CGPoint(x: handleX, y: 0))
                    path.addLine(to: CGPoint(x: handleX, y: size.height))
                }
                .stroke(Color.white, lineWidth: 2)
                .shadow(radius: 2)
                
                // Circle Handle
                Circle()
                    .fill(Color.white)
                    .shadow(radius: 3)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "line.3.horizontal")
                            .rotationEffect(.degrees(90))
                            .font(.caption2.bold())
                            .foregroundColor(.black)
                    )
                    .position(x: handleX, y: size.height / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                let newRatio = max(0.02, min(0.98, gesture.location.x / size.width))
                                splitRatio = newRatio
                            }
                    )
            }
            
            // Labels
            VStack {
                HStack {
                    Text("ORIGINAL")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.6)))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("COMPRESSED")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.6)))
                        .foregroundColor(.white)
                }
                .padding(12)
                
                Spacer()
            }
        }
    }
}

private struct SplitClipShape: Shape {
    var ratio: CGFloat
    
    var animatableData: CGFloat {
        get { ratio }
        set { ratio = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let clipWidth = rect.width * ratio
        path.addRect(CGRect(x: 0, y: 0, width: clipWidth, height: rect.height))
        return path
    }
}
