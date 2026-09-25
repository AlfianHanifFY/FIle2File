import Foundation
import AppKit
import AVFoundation
import Vision
import CoreImage
import AudioToolbox
import Combine

public struct DetectedQuad: Equatable {
    public let topLeft: CGPoint
    public let topRight: CGPoint
    public let bottomLeft: CGPoint
    public let bottomRight: CGPoint
    public let confidence: Float
    
    public init(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint, confidence: Float) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
        self.confidence = confidence
    }
    
    public static func == (lhs: DetectedQuad, rhs: DetectedQuad) -> Bool {
        abs(lhs.topLeft.x - rhs.topLeft.x) < 0.03 &&
        abs(lhs.topLeft.y - rhs.topLeft.y) < 0.03 &&
        abs(lhs.topRight.x - rhs.topRight.x) < 0.03 &&
        abs(lhs.topRight.y - rhs.topRight.y) < 0.03 &&
        abs(lhs.bottomLeft.x - rhs.bottomLeft.x) < 0.03 &&
        abs(lhs.bottomLeft.y - rhs.bottomLeft.y) < 0.03 &&
        abs(lhs.bottomRight.x - rhs.bottomRight.x) < 0.03 &&
        abs(lhs.bottomRight.y - rhs.bottomRight.y) < 0.03
    }
}

public class CameraScanManager: NSObject, ObservableObject {
    @Published public var isRunning: Bool = false
    @Published public var detectedQuad: DetectedQuad? = nil
    @Published public var isAutoCaptureEnabled: Bool = true
    @Published public var availableDevices: [AVCaptureDevice] = []
    @Published public var selectedDeviceID: String = ""
    @Published public var cameraPermissionGranted: Bool = false
    @Published public var autoCaptureProgress: Double = 0.0 // 0.0 to 1.0
    
    public let captureSession = AVCaptureSession()
    
    private let sessionQueue = DispatchQueue(label: "com.file2file.camera.sessionQueue")
    private let visionQueue = DispatchQueue(label: "com.file2file.camera.visionQueue", qos: .userInitiated)
    private var videoOutput: AVCaptureVideoDataOutput?
    private var currentInput: AVCaptureDeviceInput?
    
    private var lastFrameCIImage: CIImage?
    private var lastObservation: VNRectangleObservation?
    private var stableQuadCounter: Int = 0
    private let requiredStableFrames: Int = 18 // ~0.8 to 1.0 sec at 20-30 fps
    private var isCapturingLocked: Bool = false
    
    public var onPageCaptured: ((NSImage) -> Void)?
    
    public override init() {
        super.init()
        refreshAvailableDevices()
    }
    
    // MARK: - Device & Permission Setup
    
    public func requestPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.cameraPermissionGranted = true
            }
            self.setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.cameraPermissionGranted = granted
                }
                if granted {
                    self.setupSession()
                }
            }
        default:
            DispatchQueue.main.async {
                self.cameraPermissionGranted = false
            }
        }
    }
    
    public func refreshAvailableDevices() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        let devices = discoverySession.devices
        DispatchQueue.main.async {
            self.availableDevices = devices
            if self.selectedDeviceID.isEmpty, let first = devices.first {
                self.selectedDeviceID = first.uniqueID
            }
        }
    }
    
    private func setupSession() {
        sessionQueue.async {
            guard !self.captureSession.isRunning else { return }
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .high
            
            // Input Device Selection
            let deviceID = self.selectedDeviceID
            var targetDevice: AVCaptureDevice? = nil
            if !deviceID.isEmpty {
                targetDevice = self.availableDevices.first(where: { $0.uniqueID == deviceID })
            }
            if targetDevice == nil {
                targetDevice = AVCaptureDevice.default(for: .video)
            }
            
            if let device = targetDevice, let input = try? AVCaptureDeviceInput(device: device) {
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                    self.currentInput = input
                }
            }
            
            // Video Output
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: self.visionQueue)
            if self.captureSession.canAddOutput(output) {
                self.captureSession.addOutput(output)
                self.videoOutput = output
            }
            
            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()
            
            DispatchQueue.main.async {
                self.isRunning = true
            }
        }
    }
    
    public func switchCamera(to deviceID: String) {
        sessionQueue.async {
            guard self.selectedDeviceID != deviceID else { return }
            self.captureSession.beginConfiguration()
            
            if let existingInput = self.currentInput {
                self.captureSession.removeInput(existingInput)
            }
            
            if let newDevice = self.availableDevices.first(where: { $0.uniqueID == deviceID }),
               let newInput = try? AVCaptureDeviceInput(device: newDevice),
               self.captureSession.canAddInput(newInput) {
                self.captureSession.addInput(newInput)
                self.currentInput = newInput
                DispatchQueue.main.async {
                    self.selectedDeviceID = deviceID
                }
            }
            
            self.captureSession.commitConfiguration()
        }
    }
    
    public func stopSession() {
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }
    
    // MARK: - Manual Snap Trigger
    
    public func triggerManualSnap() {
        visionQueue.async {
            self.performCapture()
        }
    }
    
    private func performCapture() {
        guard !self.isCapturingLocked, let ciImage = self.lastFrameCIImage else { return }
        self.isCapturingLocked = true
        
        let croppedNSImage: NSImage
        if let observation = self.lastObservation {
            croppedNSImage = self.applyPerspectiveCorrection(ciImage: ciImage, observation: observation) ?? self.ciImageToNSImage(ciImage)
        } else {
            croppedNSImage = self.ciImageToNSImage(ciImage)
        }
        
        // Play system camera shutter sound
        AudioServicesPlaySystemSound(1108)
        
        DispatchQueue.main.async {
            self.autoCaptureProgress = 0.0
            self.stableQuadCounter = 0
            self.onPageCaptured?(croppedNSImage)
            
            // Unlock after brief pause
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.isCapturingLocked = false
            }
        }
    }
    
    // MARK: - Core Image & Vision Processing
    
    private func applyPerspectiveCorrection(ciImage: CIImage, observation: VNRectangleObservation) -> NSImage? {
        let size = ciImage.extent.size
        
        let topLeft = CGPoint(x: observation.topLeft.x * size.width, y: observation.topLeft.y * size.height)
        let topRight = CGPoint(x: observation.topRight.x * size.width, y: observation.topRight.y * size.height)
        let bottomLeft = CGPoint(x: observation.bottomLeft.x * size.width, y: observation.bottomLeft.y * size.height)
        let bottomRight = CGPoint(x: observation.bottomRight.x * size.width, y: observation.bottomRight.y * size.height)
        
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
        
        guard let outputCI = filter.outputImage else { return nil }
        return ciImageToNSImage(outputCI)
    }
    
    private func ciImageToNSImage(_ ciImage: CIImage) -> NSImage {
        let context = CIContext(options: [.useSoftwareRenderer: false])
        let extent = ciImage.extent
        guard !extent.isEmpty && !extent.isInfinite,
              let cgImage = context.createCGImage(ciImage, from: extent) else {
            return NSImage()
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraScanManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        self.lastFrameCIImage = ciImage
        
        let request = VNDetectRectanglesRequest { [weak self] request, error in
            guard let self = self else { return }
            guard error == nil, let results = request.results as? [VNRectangleObservation], let observation = results.first else {
                DispatchQueue.main.async {
                    self.detectedQuad = nil
                    self.lastObservation = nil
                    self.stableQuadCounter = 0
                    self.autoCaptureProgress = 0.0
                }
                return
            }
            
            let currentQuad = DetectedQuad(
                topLeft: observation.topLeft,
                topRight: observation.topRight,
                bottomLeft: observation.bottomLeft,
                bottomRight: observation.bottomRight,
                confidence: observation.confidence
            )
            
            DispatchQueue.main.async {
                if let existingQuad = self.detectedQuad, existingQuad == currentQuad {
                    self.stableQuadCounter += 1
                } else {
                    self.stableQuadCounter = 1
                }
                
                self.detectedQuad = currentQuad
                self.lastObservation = observation
                
                let progress = min(1.0, Double(self.stableQuadCounter) / Double(self.requiredStableFrames))
                self.autoCaptureProgress = progress
                
                if self.isAutoCaptureEnabled && self.stableQuadCounter >= self.requiredStableFrames && !self.isCapturingLocked {
                    self.performCapture()
                }
            }
        }
        
        request.minimumConfidence = 0.6
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 1.0
        request.maximumObservations = 1
        
        let handler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, options: [:])
        try? handler.perform([request])
    }
}
