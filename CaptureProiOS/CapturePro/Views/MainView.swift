import SwiftUI

struct MainView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("loggedInUser") private var loggedInUser: String = ""
    @AppStorage("isAdmin") private var isAdmin: Bool = false

    @StateObject private var prefs = PrefsManager.shared
    @StateObject private var cameraController = CameraController()

    @State private var tagNo: String = ""
    @State private var lastTagNo: String = ""
    @State private var totalSavedQty: Int = 0
    @State private var lastImageURL: URL? = nil
    @State private var lastCapturedImage: UIImage? = nil

    @State private var isTagFieldDisabled: Bool = false
    @State private var showAdminPanel: Bool = false
    @State private var showBarcodeScanner: Bool = false
    @State private var showFullScreenImage: Bool = false
    @State private var showLensPreview: Bool = false
    @State private var isEnlargedPreview: Bool = false
    @State private var showLogoutAlert: Bool = false

    let compressions = ["JPEG_100", "JPEG_90", "JPEG_80", "JPEG_70"]
    let sizeUnits = ["inch", "cm", "mm"]

    var body: some View {
        ZStack {
            Color(red: 13/255, green: 17/255, blue: 23/255)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── HEADER ──
                HStack(spacing: 10) {
                    Text("C")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color(red: 123/255, green: 31/255, blue: 162/255))
                        .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 0) {
                            Text("Capture")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(red: 255/255, green: 109/255, blue: 0/255))
                            Text(" Pro")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("developed by Anees Ariyakkal")
                            .font(.system(size: 8))
                            .foregroundColor(Color(red: 136/255, green: 153/255, blue: 170/255))
                    }

                    Spacer()

                    Text(loggedInUser)
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 136/255, green: 153/255, blue: 170/255))

                    if isAdmin {
                        Button(action: { showAdminPanel = true }) {
                            Text("⚙ Admin")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 255/255, green: 109/255, blue: 0/255))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(red: 28/255, green: 37/255, blue: 53/255))
                                .cornerRadius(6)
                        }
                    }

                    Button(action: { showLogoutAlert = true }) {
                        Text("⏻")
                            .font(.system(size: 16))
                            .foregroundColor(Color(red: 255/255, green: 82/255, blue: 82/255))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color(red: 28/255, green: 37/255, blue: 53/255))
                            .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 54)
                .background(Color(red: 10/255, green: 10/255, blue: 24/255))

                // ── MAIN BODY ──
                ScrollView {
                    VStack(spacing: 12) {

                        // Save Location & Preview Card
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Image Save Loc")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)

                                Text("Documents/CapturePro/\(TagNoResolver.shared.getDateFolderName(username: loggedInUser))")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(red: 136/255, green: 153/255, blue: 170/255))
                                    .lineLimit(1)

                                Text("Format: dd-mm-yyyy & Username")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(red: 255/255, green: 109/255, blue: 0/255))
                            }

                            Spacer()

                            VStack(spacing: 2) {
                                Text("Preview")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)

                                if let img = lastCapturedImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 70, height: 70)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white, lineWidth: 1.5))
                                        .onTapGesture { showFullScreenImage = true }
                                } else {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 70, height: 70)
                                        .cornerRadius(6)
                                        .overlay(Image(systemName: "photo").foregroundColor(.gray))
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(red: 22/255, green: 27/255, blue: 38/255))
                        .cornerRadius(12)

                        // Compression Row
                        HStack {
                            Text("Quality")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 60, alignment: .leading)

                            Picker("Quality", selection: $prefs.compression) {
                                ForEach(compressions, id: \.self) { c in
                                    Text(c).tag(c)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color(red: 28/255, green: 37/255, blue: 53/255))
                            .cornerRadius(8)
                        }

                        // Tag No Row
                        HStack(spacing: 8) {
                            Text("Tag No")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 60, alignment: .leading)

                            TextField("Enter Tag No...", text: $tagNo)
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                                .disabled(isTagFieldDisabled)
                                .padding(.horizontal, 10)
                                .frame(height: 44)
                                .background(Color(red: 28/255, green: 37/255, blue: 53/255))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .onChange(of: tagNo) { newValue in
                                    if newValue != lastTagNo {
                                        lastTagNo = newValue
                                        prefs.objectSize = "" // Text field auto-reset when tag no changes
                                    }
                                    updateCountAndPreview()
                                }

                            Button(action: { showBarcodeScanner = true }) {
                                Image(systemName: "barcode.viewfinder")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color(red: 21/255, green: 101/255, blue: 192/255))
                                    .cornerRadius(8)
                            }

                            Button(action: resetFields) {
                                Text("Reset")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 44)
                                    .background(Color(red: 198/255, green: 40/255, blue: 40/255))
                                    .cornerRadius(8)
                            }
                        }

                        // Total Count & Min Qty Row
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Total images saved qty: \(totalSavedQty)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color(red: 255/255, green: 109/255, blue: 0/255))
                            }

                            Spacer()

                            HStack(spacing: 4) {
                                Text("Min Qty:")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(red: 136/255, green: 153/255, blue: 170/255))

                                TextField("1", value: $prefs.minQty, formatter: NumberFormatter())
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 44, height: 36)
                                    .background(Color(red: 28/255, green: 37/255, blue: 53/255))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                        }

                        // Camera Live View Frame + Controls
                        VStack(spacing: 8) {
                            HStack {
                                Text("Camera Preview")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)

                                Spacer()

                                Button(action: { isEnlargedPreview.toggle() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: isEnlargedPreview ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                        Text(isEnlargedPreview ? "Normal" : "Enlarge Preview")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(red: 123/255, green: 31/255, blue: 162/255))
                                    .cornerRadius(6)
                                }
                            }

                            // Camera View Box
                            ZStack {
                                CameraPreviewHolder(cameraController: cameraController)
                                    .frame(height: isEnlargedPreview ? 420 : 250)
                                    .cornerRadius(12)
                                    .clipped()

                                // Dynamic Measurement Overlay
                                if prefs.showSize {
                                    VStack {
                                        Spacer()
                                        Rectangle()
                                            .stroke(Color(red: 255/255, green: 109/255, blue: 0/255), lineWidth: 2)
                                            .frame(width: 180, height: 120)
                                            .overlay(
                                                Text(prefs.objectSize.isEmpty ? "Size Overlay" : "\(prefs.objectSize) \(prefs.sizeUnit)")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .padding(4)
                                                    .background(Color.black.opacity(0.7))
                                                    .cornerRadius(4),
                                                alignment: .top
                                            )
                                        Spacer()
                                    }
                                }
                            }

                            // Zoom In/Out Buttons
                            HStack(spacing: 10) {
                                Text("Zoom:")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white)

                                ForEach([1.0, 2.0, 3.0, 5.0], id: \.self) { z in
                                    Button(action: { cameraController.setZoom(CGFloat(z)) }) {
                                        Text("\(Int(z))x")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(cameraController.zoomFactor == CGFloat(z) ? .black : .white)
                                            .frame(width: 36, height: 28)
                                            .background(cameraController.zoomFactor == CGFloat(z) ? Color(red: 255/255, green: 109/255, blue: 0/255) : Color(red: 28/255, green: 37/255, blue: 53/255))
                                            .cornerRadius(6)
                                    }
                                }
                            }

                            // Big Capture Photo Button
                            Button(action: capturePhoto) {
                                HStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                    Text("CAPTURE PHOTO")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 123/255, green: 31/255, blue: 162/255),
                                            Color(red: 171/255, green: 71/255, blue: 188/255)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(10)
                            }
                        }

                        // Object Size Dimension Inputs
                        VStack(spacing: 8) {
                            HStack {
                                Text("Text / Size")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)

                                TextField("Enter dimension...", text: $prefs.objectSize)
                                    .padding(.horizontal, 8)
                                    .frame(height: 38)
                                    .background(Color(red: 28/255, green: 37/255, blue: 53/255))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)

                                Picker("Unit", selection: $prefs.sizeUnit) {
                                    ForEach(sizeUnits, id: \.self) { u in Text(u).tag(u) }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(width: 70, height: 38)
                                .background(Color(red: 28/255, green: 37/255, blue: 53/255))
                                .cornerRadius(6)
                            }

                            HStack {
                                Toggle(isOn: $prefs.showSize) {
                                    Text("Show size overlay")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                }

                                Toggle(isOn: $prefs.identifyObject) {
                                    Text("Google Lens")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                }
                            }

                            if prefs.identifyObject {
                                Button(action: { showLensPreview = true }) {
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                        Text("Search Object via Google Lens")
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(Color(red: 21/255, green: 101/255, blue: 192/255))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(red: 22/255, green: 27/255, blue: 38/255))
                        .cornerRadius(12)

                    }
                    .padding(12)
                }
            }
        }
        .onAppear {
            cameraController.startSession()
            updateCountAndPreview()
        }
        .onDisappear {
            cameraController.stopSession()
        }
        .onReceive(cameraController.$capturedImage) { image in
            if let img = image {
                saveCapturedPhoto(img)
            }
        }
        .sheet(isPresented: $showAdminPanel) { AdminPanelView() }
        .sheet(isPresented: $showBarcodeScanner) {
            BarcodeScannerView { code in
                tagNo = code
                updateCountAndPreview()
            }
        }
        .sheet(isPresented: $showFullScreenImage) {
            if let img = lastCapturedImage {
                FullScreenImageView(image: img)
            }
        }
        .sheet(isPresented: $showLensPreview) {
            LensPreviewView(targetURL: URL(string: "https://lens.google.com")!)
        }
        .alert(isPresented: $showLogoutAlert) {
            Alert(
                title: Text("Logout"),
                message: Text("Are you sure you want to log out?"),
                primaryButton: .destructive(Text("Logout")) {
                    isLoggedIn = false
                    loggedInUser = ""
                    isAdmin = false
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func updateCountAndPreview() {
        totalSavedQty = TagNoResolver.shared.getCountForTag(username: loggedInUser, tagNo: tagNo)
        if let url = TagNoResolver.shared.getLastImageURLForTag(username: loggedInUser, tagNo: tagNo),
           let data = try? Data(contentsOf: url),
           let img = UIImage(data: data) {
            lastCapturedImage = img
            lastImageURL = url
        }

        if isTagFieldDisabled && totalSavedQty >= prefs.minQty {
            isTagFieldDisabled = false
        }
    }

    private func resetFields() {
        tagNo = ""
        prefs.objectSize = ""
        isTagFieldDisabled = false
        updateCountAndPreview()
    }

    private func capturePhoto() {
        cameraController.capturePhoto()
    }

    private func saveCapturedPhoto(_ image: UIImage) {
        if let url = TagNoResolver.shared.saveCapturedImage(image, username: loggedInUser, tagNo: tagNo, compression: prefs.compression) {
            lastCapturedImage = image
            lastImageURL = url
            totalSavedQty = TagNoResolver.shared.getCountForTag(username: loggedInUser, tagNo: tagNo)
            if totalSavedQty < prefs.minQty {
                isTagFieldDisabled = true
            }
        }
    }
}
