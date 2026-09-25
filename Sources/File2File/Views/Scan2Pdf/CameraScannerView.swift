import SwiftUI
import AppKit
import AVFoundation

public struct CameraScannerView: View {
    @ObservedObject var manager: CameraScanManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var capturedPages: [NSImage] = []
    
    public var onComplete: ([NSImage]) -> Void
    
    public init(manager: CameraScanManager, onComplete: @escaping ([NSImage]) -> Void) {
        self.manager = manager
        self.onComplete = onComplete
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            topControlBar
            Divider()
            
            ZStack {
                if manager.cameraPermissionGranted {
                    CameraPreviewContainer(session: manager.captureSession, detectedQuad: manager.detectedQuad)
                        .background(Color.black)
                    
                    if let progress = Optional(manager.autoCaptureProgress), progress > 0 {
                        VStack {
                            Spacer()
                            HStack(spacing: 8) {
                                ProgressView(value: progress, total: 1.0)
                                    .progressViewStyle(.linear)
                                    .frame(width: 180)
                                    .accentColor(progress >= 1.0 ? .green : .accentColor)
                                
                                Text(progress >= 1.0 ? "Hold Steady..." : "Hold Still to Snap")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.black.opacity(0.75)))
                            .padding(.bottom, 24)
                        }
                    }
                } else {
                    cameraPermissionStateView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            bottomActionBar
        }
        .frame(minWidth: 720, minHeight: 560)
        .onAppear {
            manager.onPageCaptured = { newImage in
                capturedPages.append(newImage)
            }
            manager.requestPermissionAndStart()
        }
        .onDisappear {
            manager.stopSession()
        }
    }
    
    // MARK: - Top Control Bar
    
    private var topControlBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "camera.viewfinder")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                Text("Live Document Scanner")
                    .font(.headline)
            }
            
            Spacer()
            
            // Camera Device Picker
            if !manager.availableDevices.isEmpty {
                Picker("Camera", selection: Binding(
                    get: { manager.selectedDeviceID },
                    set: { manager.switchCamera(to: $0) }
                )) {
                    ForEach(manager.availableDevices, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(device.uniqueID)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 220)
            }
            
            Button(action: { manager.refreshAvailableDevices() }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh connected cameras (including Continuity Camera)")
            
            Toggle(isOn: $manager.isAutoCaptureEnabled) {
                Text("Hands-free Auto Capture")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)
            
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        HStack(spacing: 16) {
            // Captured Thumbnails Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(capturedPages.enumerated()), id: \.offset) { index, img in
                        ZStack(alignment: .topTrailing) {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 65)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.accentColor, lineWidth: 1.5)
                                )
                            
                            Button(action: { capturedPages.remove(at: index) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.red))
                            }
                            .buttonStyle(.plain)
                            .offset(x: 4, y: -4)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: 70)
            
            Spacer()
            
            // Manual Shutter Button
            Button(action: { manager.triggerManualSnap() }) {
                HStack(spacing: 6) {
                    Image(systemName: "camera.circle.fill")
                        .font(.title2)
                    Text("Snap Photo (Spacebar)")
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut(.space, modifiers: [])
            .disabled(!manager.cameraPermissionGranted)
            
            // Done Button
            Button(action: {
                onComplete(capturedPages)
                dismiss()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Done (\(capturedPages.count) \(capturedPages.count == 1 ? "page" : "pages"))")
                        .fontWeight(.bold)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(capturedPages.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Permission Denied View
    
    private var cameraPermissionStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("Camera Access Required")
                .font(.headline)
            Text("Please grant camera permission in macOS System Settings -> Privacy & Security -> Camera to use your laptop or Continuity Camera.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Button("Grant") {
                manager.requestPermissionAndStart()
            }
            .buttonStyle(.borderedProminent)
            .help("Grant camera access in macOS System Settings")
        }
    }
}

// MARK: - Camera Preview Layer NSViewRepresentable

struct CameraPreviewContainer: NSViewRepresentable {
    let session: AVCaptureSession
    let detectedQuad: DetectedQuad?
    
    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.session = session
        return view
    }
    
    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        nsView.detectedQuad = detectedQuad
        nsView.setNeedsDisplay(nsView.bounds)
    }
}

class CameraPreviewNSView: NSView {
    var session: AVCaptureSession? {
        didSet {
            guard let session = session else { return }
            previewLayer.session = session
        }
    }
    
    var detectedQuad: DetectedQuad? {
        didSet {
            needsDisplay = true
        }
    }
    
    private let previewLayer = AVCaptureVideoPreviewLayer()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let quad = detectedQuad else { return }
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let w = bounds.width
        let h = bounds.height
        
        // Vision coordinates (0..1, Y is bottom-up) to NSView coordinates
        let p1 = CGPoint(x: quad.topLeft.x * w, y: quad.topLeft.y * h)
        let p2 = CGPoint(x: quad.topRight.x * w, y: quad.topRight.y * h)
        let p3 = CGPoint(x: quad.bottomRight.x * w, y: quad.bottomRight.y * h)
        let p4 = CGPoint(x: quad.bottomLeft.x * w, y: quad.bottomLeft.y * h)
        
        context.saveGState()
        context.beginPath()
        context.move(to: p1)
        context.addLine(to: p2)
        context.addLine(to: p3)
        context.addLine(to: p4)
        context.closePath()
        
        let strokeColor = NSColor.systemGreen.withAlphaComponent(0.95).cgColor
        let fillColor = NSColor.systemGreen.withAlphaComponent(0.20).cgColor
        
        context.setFillColor(fillColor)
        context.setStrokeColor(strokeColor)
        context.setLineWidth(3.5)
        context.setLineJoin(.round)
        
        context.drawPath(using: .fillStroke)
        
        // Draw corner handles
        let points = [p1, p2, p3, p4]
        context.setFillColor(NSColor.white.cgColor)
        for pt in points {
            context.fillEllipse(in: CGRect(x: pt.x - 5, y: pt.y - 5, width: 10, height: 10))
            context.strokeEllipse(in: CGRect(x: pt.x - 5, y: pt.y - 5, width: 10, height: 10))
        }
        
        context.restoreGState()
    }
}
