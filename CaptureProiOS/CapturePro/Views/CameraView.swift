import SwiftUI
import AVFoundation
import UIKit

struct CameraPreviewHolder: UIViewRepresentable {
    @ObservedObject var cameraController: CameraController

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect.zero)
        cameraController.previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(cameraController.previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            cameraController.previewLayer.frame = uiView.bounds
        }
    }
}

final class CameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var capturedImage: UIImage?
    @Published var zoomFactor: CGFloat = 1.0

    let session = AVCaptureSession()
    let previewLayer: AVCaptureVideoPreviewLayer
    private let photoOutput = AVCapturePhotoOutput()
    private var videoDevice: AVCaptureDevice?

    override init() {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init()
        setupSession()
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }

        self.videoDevice = device

        if session.canAddInput(input) {
            session.addInput(input)
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()
    }

    func startSession() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    func stopSession() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
        }
    }

    func setZoom(_ factor: CGFloat) {
        guard let device = videoDevice else { return }
        do {
            try device.lockForConfiguration()
            let clamped = min(max(factor, 1.0), device.activeFormat.videoMaxZoomFactor)
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
            DispatchQueue.main.async {
                self.zoomFactor = clamped
            }
        } catch {
            print("Zoom error: \(error)")
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            return
        }

        DispatchQueue.main.async {
            self.capturedImage = image
        }
    }
}
