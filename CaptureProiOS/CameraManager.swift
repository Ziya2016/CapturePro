import AVFoundation
import UIKit

class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isCameraReady = false
    @Published var hasFlash = false
    @Published var torchOn = false
    
    private let output = AVCapturePhotoOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var cameraPosition: AVCaptureDevice.Position = .back
    private var photoCaptureCompletion: ((Result<Data, Error>) -> Void)?
    
    func setupCamera() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            
            // Remove existing inputs
            if let videoInput = self.videoInput {
                self.session.removeInput(videoInput)
            }
            
            // Get camera device
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.cameraPosition) else {
                print("No camera found")
                self.session.commitConfiguration()
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.videoInput = input
                }
                
                // Add output if not already added
                if !self.session.outputs.contains(self.output) {
                    if self.session.canAddOutput(self.output) {
                        self.session.addOutput(self.output)
                    }
                }
                
                self.session.commitConfiguration()
                
                DispatchQueue.main.async {
                    self.isCameraReady = true
                    self.hasFlash = camera.hasFlash
                    self.updateTorchState()
                }
                
                self.session.startRunning()
            } catch {
                print("Error setting up camera: \(error.localizedDescription)")
                self.session.commitConfiguration()
            }
        }
    }
    
    func switchCamera() {
        cameraPosition = (cameraPosition == .back) ? .front : .back
        torchOn = false
        setupCamera()
    }
    
    func toggleTorch() {
        guard let device = videoInput?.device, device.hasFlash else { return }
        do {
            try device.lockForConfiguration()
            if torchOn {
                device.torchMode = .off
                torchOn = false
            } else {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                torchOn = true
            }
            device.unlockForConfiguration()
        } catch {
            print("Error toggling torch: \(error.localizedDescription)")
        }
    }
    
    private func updateTorchState() {
        guard let device = videoInput?.device, device.hasFlash else {
            torchOn = false
            return
        }
        torchOn = device.torchMode == .on
    }
    
    func capturePhoto(completion: @escaping (Result<Data, Error>) -> Void) {
        self.photoCaptureCompletion = completion
        let settings = AVCapturePhotoSettings()
        if videoInput?.device.hasFlash == true {
            settings.flashMode = torchOn ? .on : .off
        }
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            photoCaptureCompletion?(.failure(error))
            return
        }
        guard let imageData = photo.fileDataRepresentation() else {
            photoCaptureCompletion?(.failure(NSError(domain: "CameraManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get photo data"])))
            return
        }
        photoCaptureCompletion?(.success(imageData))
    }
}
