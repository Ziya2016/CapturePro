import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    
    // State variables
    @State private var tagNo: String = ""
    @State private var minQty: String = "1"
    @State private var selectedFolderUrl: URL? = nil
    @State private var folderName: String = "No location set"
    @State private var totalCount: Int = 0
    @State private var lastImage: UIImage? = nil
    @State private var isScanning: Bool = false
    @State private var isLocked: Bool = false
    @State private var isSaving: Bool = false
    @State private var saveMessage: String = ""
    @State private var showToast: Bool = false
    @State private var selectedCameraIndex = 0
    
    // Sheet presentation
    @State private var showFolderPicker = false
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 13/255, green: 17/255, blue: 23/255)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    // Logo Badge
                    Text("C")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 255/255, green: 109/255, blue: 0), Color(red: 255/255, green: 145/255, blue: 0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 0) {
                            Text("Capture")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(red: 255/255, green: 109/255, blue: 0))
                            Text(" Pro")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("developed by Anees Ariyakkal")
                            .font(.system(size: 9))
                            .foregroundColor(Color(red: 136/255, green: 153/255, blue: 170/255))
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(height: 56)
                .background(Color(red: 10/255, green: 10/255, blue: 24/255))
                .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
                
                // Scrollable content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        
                        // Save Location Card
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Image Save Loc")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(folderName)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(red: 136/255, green: 153/255, blue: 170/255))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                
                                Button(action: {
                                    showFolderPicker = true
                                }) {
                                    Text("Change Location")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color(red: 21/255, green: 101/255, blue: 192/255))
                                        .cornerRadius(6)
                                }
                                .padding(.top, 4)
                            }
                            
                            Spacer()
                            
                            // Image Preview Thumbnail
                            VStack(spacing: 4) {
                                Text("Preview")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white)
                                
                                if let img = lastImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 70, height: 70)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white, lineWidth: 2))
                                } else {
                                    Color(red: 28/255, green: 37/255, blue: 53/255)
                                        .frame(width: 70, height: 70)
                                        .cornerRadius(6)
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.3), lineWidth: 2))
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(red: 22/255, green: 27/255, blue: 38/255))
                        .cornerRadius(10)
                        
                        Divider()
                            .background(Color(red: 30/255, green: 42/255, blue: 56/255))
                            .padding(.vertical, 4)
                        
                        // Tag No Row
                        HStack(spacing: 8) {
                            Text("Tag No")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 62, alignment: .leading)
                            
                            TextField("Enter Tag No...", text: $tagNo)
                                .font(.system(size: 14))
                                .padding(.horizontal, 12)
                                .frame(height: 46)
                                .background(Color(red: 28/255, green: 37/255, blue: 53/255))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 46/255, green: 64/255, blue: 96/255), lineWidth: 1))
                                .disabled(isLocked)
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                                .onChange(of: tagNo) { _ in
                                    updateTagCountAndPreview()
                                }
                            
                            // Scan Button
                            Button(action: {
                                isScanning = true
                            }) {
                                Image(systemName: "barcode.viewfinder")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 46, height: 46)
                                    .background(Color(red: 123/255, green: 31/255, blue: 162/255))
                                    .cornerRadius(6)
                            }
                            .disabled(isLocked)
                            
                            // Reset Button
                            Button(action: {
                                tagNo = ""
                                isLocked = false
                                updateTagCountAndPreview()
                            }) {
                                Text("Reset")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 72, height: 46)
                                    .background(Color(red: 229/255, green: 57/255, blue: 53/255))
                                    .cornerRadius(6)
                            }
                        }
                        
                        // Total Count & Min Qty
                        HStack {
                            Text("Total images saved qty: \(totalCount)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(red: 229/255, green: 57/255, blue: 53/255))
                            
                            Spacer()
                            
                            TextField("1", text: $minQty)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .frame(width: 50, height: 40)
                                .background(Color(red: 46/255, green: 125/255, blue: 50/255))
                                .cornerRadius(6)
                                .keyboardType(.numberPad)
                                .disabled(isLocked)
                                .onChange(of: minQty) { newValue in
                                    UserDefaults.standard.set(newValue, forKey: "minQty")
                                    updateTagCountAndPreview()
                                }
                        }
                        .padding(.top, 4)
                        
                        // Camera Preview Frame
                        ZStack {
                            if cameraManager.isCameraReady {
                                CameraPreview(cameraManager: cameraManager)
                                    .cornerRadius(8)
                            } else {
                                Rectangle()
                                    .fill(Color.black)
                                    .cornerRadius(8)
                                Text("Live Preview")
                                    .font(.system(size: 17))
                                    .foregroundColor(Color(red: 136/255, green: 153/255, blue: 170/255))
                            }
                            
                            // Torch Overlay (Top-Left)
                            VStack(alignment: .center, spacing: 2) {
                                Button(action: {
                                    cameraManager.toggleTorch()
                                }) {
                                    Image(systemName: cameraManager.torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(cameraManager.torchOn ? .orange : .white)
                                        .frame(width: 40, height: 40)
                                        .background(cameraManager.torchOn ? Color.white.opacity(0.8) : Color.black.opacity(0.5))
                                        .clipShape(Circle())
                                }
                                
                                Text(cameraManager.torchOn ? "ON" : "OFF")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                        .frame(height: 230)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 255/255, green: 109/255, blue: 0), lineWidth: 3))
                        .padding(.top, 4)
                        
                        // Capture Button
                        Button(action: {
                            capturePhoto()
                        }) {
                            Text(isSaving ? "SAVING..." : "CAPTURE PHOTO")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .tracking(2)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        colors: [Color(red: 255/255, green: 109/255, blue: 0), Color(red: 255/255, green: 145/255, blue: 0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .disabled(isSaving)
                        .padding(.top, 4)
                        
                        // Camera Source Segmented Control
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Camera Source")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            
                            Picker("Camera Source", selection: $selectedCameraIndex) {
                                Text("Camera 1 (Back)").tag(0)
                                Text("Camera 2 (Front)").tag(1)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .background(Color(red: 28/255, green: 37/255, blue: 53/255))
                            .cornerRadius(6)
                            .onChange(of: selectedCameraIndex) { _ in
                                cameraManager.switchCamera()
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                    .padding(12)
                }
            }
            
            // Custom Toast Message
            if showToast {
                VStack {
                    Spacer()
                    Text(saveMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(20)
                        .padding(.bottom, 40)
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPicker(selectedURL: $selectedFolderUrl)
        }
        .sheet(isPresented: $isScanning) {
            BarcodeScannerView(onScanSuccess: { barcode in
                self.tagNo = barcode
                triggerToast("Scanned: \(barcode)")
            }, onScanFailure: { error in
                triggerToast("Scan failed: \(error.localizedDescription)")
            })
        }
        .onAppear {
            cameraManager.setupCamera()
            loadSavedFolder()
            if let savedMin = UserDefaults.standard.string(forKey: "minQty") {
                minQty = savedMin
            }
        }
    }
    
    // Helper Methods
    private func loadSavedFolder() {
        if let savedBookmarkData = UserDefaults.standard.data(forKey: "folderBookmark") {
            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: savedBookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                if url.startAccessingSecurityScopedResource() {
                    selectedFolderUrl = url
                    folderName = url.lastPathComponent
                    updateTagCountAndPreview()
                } else {
                    folderName = "Access denied to saved folder"
                }
            } catch {
                print("Failed to resolve bookmark: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateTagCountAndPreview() {
        guard let folder = selectedFolderUrl, !tagNo.isEmpty else {
            totalCount = 0
            lastImage = nil
            return
        }
        
        let count = TagNoResolver.getCountForTag(directory: folder, tag: tagNo)
        self.totalCount = count
        
        if let lastImgUrl = TagNoResolver.getLastImageForTag(directory: folder, tag: tagNo) {
            if let data = try? Data(contentsOf: lastImgUrl) {
                self.lastImage = UIImage(data: data)
            }
        } else {
            self.lastImage = nil
        }
        
        let minVal = Int(minQty) ?? 1
        if isLocked && count >= minVal {
            isLocked = false
        }
    }
    
    private func capturePhoto() {
        let tag = tagNo.trimmingCharacters(in: .whitespacesAndNewlines)
        if tag.isEmpty {
            triggerToast("Please enter a Tag No before capturing.")
            return
        }
        
        guard let folder = selectedFolderUrl else {
            triggerToast("Please choose a save location first.")
            return
        }
        
        isSaving = true
        isLocked = true
        
        cameraManager.capturePhoto { result in
            switch result {
            case .success(let data):
                let fileName = TagNoResolver.resolveFileName(directory: folder, tag: tag)
                let destinationUrl = folder.appendingPathComponent(fileName)
                
                do {
                    try data.write(to: destinationUrl)
                    triggerToast("✓ Saved → \(fileName)")
                    updateTagCountAndPreview()
                } catch {
                    triggerToast("Failed to save image: \(error.localizedDescription)")
                }
                isSaving = false
                
            case .failure(let error):
                triggerToast("Capture failed: \(error.localizedDescription)")
                isSaving = false
            }
        }
    }
    
    private func triggerToast(_ msg: String) {
        saveMessage = msg
        withAnimation {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
