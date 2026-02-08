import AVFoundation
import Combine
import UIKit

class CameraManager: NSObject, ObservableObject {
    @Published var currentExercise: ExerciseType = .unknown
    @Published var confidence: Double = 0.0
    @Published var isRunning: Bool = false
    @Published var fps: Int = 0
    @Published var cameraPermissionGranted: Bool = false
    @Published var currentPosition: AVCaptureDevice.Position = .front

    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let wrapper = EdgeImpulseWrapper()

    private let processingQueue = DispatchQueue(label: "camera.processing", qos: .userInitiated)
    private var isProcessing = false

    private var frameCount = 0
    private var lastFPSUpdate = Date()

    override init() {
        super.init()
        checkCameraPermission()
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.cameraPermissionGranted = granted
                }
            }
        default:
            cameraPermissionGranted = false
        }
    }

    func setupCamera(position: AVCaptureDevice.Position = .front) {
        guard cameraPermissionGranted else {
            print("Camera permission not granted")
            return
        }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .vga640x480

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position
        ) else {
            print("Failed to get camera")
            captureSession.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            captureSession.inputs.forEach { captureSession.removeInput($0) }
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            try camera.lockForConfiguration()
            camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
            camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
            camera.unlockForConfiguration()
        } catch {
            print("Camera setup error: \(error)")
        }

        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        captureSession.outputs.forEach { captureSession.removeOutput($0) }
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        if let connection = videoOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
            if position == .front {
                connection.isVideoMirrored = true
            }
        }

        captureSession.commitConfiguration()

        DispatchQueue.main.async {
            self.currentPosition = position
        }
        print("Camera setup complete - Input size: \(wrapper.getInputWidth())x\(wrapper.getInputHeight())")
    }

    /// Switch between front and back cameras
    func flipCamera() {
        let newPosition: AVCaptureDevice.Position = (currentPosition == .front) ? .back : .front
        setupCamera(position: newPosition)
    }

    func start() {
        guard cameraPermissionGranted else { return }
        processingQueue.async { [weak self] in
            self?.captureSession.startRunning()
            DispatchQueue.main.async { self?.isRunning = true }
        }
    }

    func stop() {
        processingQueue.async { [weak self] in
            self?.captureSession.stopRunning()
            DispatchQueue.main.async { self?.isRunning = false }
        }
    }

    func getCaptureSession() -> AVCaptureSession {
        return captureSession
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !isProcessing else { return }
        isProcessing = true

        frameCount += 1
        let now = Date()
        if now.timeIntervalSince(lastFPSUpdate) >= 1.0 {
            DispatchQueue.main.async { [weak self] in
                self?.fps = self?.frameCount ?? 0
            }
            frameCount = 0
            lastFPSUpdate = now
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            isProcessing = false
            return
        }

        let predictions = wrapper.classifyImage(pixelBuffer)

        var topExercise: ExerciseType = .unknown
        var topConfidence: Double = 0.0

        for (label, value) in predictions {
            let conf = value.doubleValue
            if conf > topConfidence, let exercise = ExerciseType.fromModelLabel(label) {
                topConfidence = conf
                topExercise = exercise
            }
        }
        // If no recognized label above threshold, treat as standing (rest/neutral)
        if topExercise == .unknown && topConfidence < 0.5 {
            topExercise = .standing
        }

        DispatchQueue.main.async { [weak self] in
            self?.currentExercise = topExercise
            self?.confidence = topConfidence
        }

        isProcessing = false
    }
}
