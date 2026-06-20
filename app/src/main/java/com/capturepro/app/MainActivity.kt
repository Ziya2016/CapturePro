package com.capturepro.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.documentfile.provider.DocumentFile
import android.graphics.Bitmap
import android.text.Editable
import android.text.TextWatcher
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import com.capturepro.app.databinding.ActivityMainBinding
import com.capturepro.app.databinding.ActivityExpiredBinding
import androidx.camera.core.ImageProxy
import java.io.IOException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : AppCompatActivity() {

    // ── View Binding ──────────────────────────────────────────────────────────
    private lateinit var binding: ActivityMainBinding

    // ── Core helpers ──────────────────────────────────────────────────────────
    private lateinit var cameraExecutor: ExecutorService
    private lateinit var prefs: PrefsManager
    private val scanner by lazy { GmsBarcodeScanning.getClient(this) }

    // ── CameraX ───────────────────────────────────────────────────────────────
    private var imageCapture: ImageCapture? = null
    private var cameraSelector: CameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
    private var camera: androidx.camera.core.Camera? = null

    // ── State ─────────────────────────────────────────────────────────────────
    private var saveFolderUri: Uri? = null
    private var torchOn: Boolean = false

    // ── Permissions ───────────────────────────────────────────────────────────
    private val requiredPermissions: Array<String>
        get() = buildList {
            add(Manifest.permission.CAMERA)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                add(Manifest.permission.READ_MEDIA_IMAGES)
            } else if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
                add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
            }
        }.toTypedArray()

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { results ->
        if (results.all { it.value }) startCamera()
        else showToast("Camera permission is required to use this app.")
    }

    // ── Folder picker (SAF) ───────────────────────────────────────────────────
    private val folderPickerLauncher = registerForActivityResult(
        ActivityResultContracts.OpenDocumentTree()
    ) { uri ->
        if (uri == null) return@registerForActivityResult
        // Persist permission so we can access the folder on next launch
        contentResolver.takePersistableUriPermission(
            uri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        )
        saveFolderUri = uri
        prefs.saveFolderUri = uri.toString()
        refreshLocationLabel(uri)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────────────────────────────────

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ── Expiry gate ──────────────────────────────────────────────────────
        if (ExpiryGuard.isExpired()) {
            val expiredBinding = ActivityExpiredBinding.inflate(layoutInflater)
            setContentView(expiredBinding.root)
            return   // Do NOT continue — all camera/UI code is skipped
        }

        // ── Normal startup ───────────────────────────────────────────────────
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        prefs = PrefsManager(this)
        cameraExecutor = Executors.newSingleThreadExecutor()

        restoreSavedFolder()
        setupCameraSpinner()
        setupCompressionSpinner()
        setupClickListeners()
        setupTextWatchers()

        if (allPermissionsGranted()) startCamera()
        else permissionLauncher.launch(requiredPermissions)
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::cameraExecutor.isInitialized) cameraExecutor.shutdown()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Setup helpers
    // ─────────────────────────────────────────────────────────────────────────

    private fun restoreSavedFolder() {
        val uriStr = prefs.saveFolderUri ?: return
        val uri = Uri.parse(uriStr)
        saveFolderUri = uri
        refreshLocationLabel(uri)
    }

    private fun setupCameraSpinner() {
        val cameraLabels = listOf("Camera 1  (Back)", "Camera 2  (Front)")
        val adapter = ArrayAdapter(this, R.layout.spinner_item, cameraLabels)
        adapter.setDropDownViewResource(R.layout.spinner_dropdown_item)
        binding.spinnerCamera.adapter = adapter

        binding.spinnerCamera.onItemSelectedListener =
            object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(
                    parent: AdapterView<*>, view: View?, pos: Int, id: Long
                ) {
                    cameraSelector =
                        if (pos == 0) CameraSelector.DEFAULT_BACK_CAMERA
                        else CameraSelector.DEFAULT_FRONT_CAMERA
                    // Reset torch when switching cameras
                    torchOn = false
                    updateFlashButtonUi()
                    startCamera()
                }
                override fun onNothingSelected(parent: AdapterView<*>) {}
            }
    }

    private fun setupCompressionSpinner() {
        val options = listOf(
            "Lossless (PNG)" to "PNG",
            "JPEG 100% (High Quality)" to "JPEG_100",
            "JPEG 90% (Good Quality)" to "JPEG_90",
            "JPEG 75% (Medium Quality)" to "JPEG_75"
        )
        val labels = options.map { it.first }
        val adapter = ArrayAdapter(this, R.layout.spinner_item, labels)
        adapter.setDropDownViewResource(R.layout.spinner_dropdown_item)
        binding.spinnerCompression.adapter = adapter

        val savedVal = prefs.compression
        val savedIndex = options.indexOfFirst { it.second == savedVal }.coerceAtLeast(0)
        binding.spinnerCompression.setSelection(savedIndex)

        binding.spinnerCompression.onItemSelectedListener =
            object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(
                    parent: AdapterView<*>, view: View?, pos: Int, id: Long
                ) {
                    val newVal = options[pos].second
                    prefs.compression = newVal
                    asyncUpdateTagCountAndPreview()
                }
                override fun onNothingSelected(parent: AdapterView<*>) {}
            }
    }

    private fun setupClickListeners() {
        binding.btnCapture.setOnClickListener { capturePhoto() }
        binding.btnChangeLocation.setOnClickListener { folderPickerLauncher.launch(null) }
        setupFlashButton()
        
        binding.btnScan.setOnClickListener {
            scanner.startScan()
                .addOnSuccessListener { barcode ->
                    val rawValue = barcode.rawValue
                    if (!rawValue.isNullOrEmpty()) {
                        binding.etTagNo.setText(rawValue)
                        binding.etTagNo.requestFocus()
                    }
                }
                .addOnFailureListener { e ->
                    showToast("Scan failed: ${e.localizedMessage ?: "Unknown error"}")
                }
        }

        binding.btnReset.setOnClickListener {
            binding.etTagNo.setText("")
            binding.etTagNo.isEnabled = true
            binding.etMinQty.isEnabled = true
            binding.btnScan.isEnabled = true
            binding.etTagNo.requestFocus()
        }
    }

    private fun setupTextWatchers() {
        binding.etMinQty.setText(prefs.minQty.toString())

        binding.etMinQty.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                val value = s?.toString()?.trim()?.toIntOrNull() ?: 1
                prefs.minQty = value
                asyncUpdateTagCountAndPreview()
            }
        })

        binding.etTagNo.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                asyncUpdateTagCountAndPreview()
            }
        })
    }

    private fun setupFlashButton() {
        updateFlashButtonUi()
        binding.btnFlash.setOnClickListener {
            val cam = camera ?: run {
                showToast("Camera not ready")
                return@setOnClickListener
            }
            // Front camera has no torch — guard against crash
            if (cam.cameraInfo.hasFlashUnit()) {
                torchOn = !torchOn
                cam.cameraControl.enableTorch(torchOn)
                updateFlashButtonUi()
            } else {
                showToast("Flash not available on this camera")
            }
        }
    }

    private fun updateFlashButtonUi() {
        if (torchOn) {
            binding.btnFlash.setBackgroundResource(R.drawable.bg_btn_flash_on)
            binding.tvFlashLabel.text = "ON"
        } else {
            binding.btnFlash.setBackgroundResource(R.drawable.bg_btn_flash_off)
            binding.tvFlashLabel.text = "OFF"
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CameraX
    // ─────────────────────────────────────────────────────────────────────────

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        cameraProviderFuture.addListener({
            val provider = cameraProviderFuture.get()

            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(binding.previewView.surfaceProvider)
            }

            imageCapture = ImageCapture.Builder()
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                .build()

            try {
                provider.unbindAll()
                camera = provider.bindToLifecycle(this, cameraSelector, preview, imageCapture)
                // Apply current torch state to new camera
                camera?.cameraControl?.enableTorch(torchOn)
                // Hide placeholder text once camera is active
                binding.tvLiveLabel.visibility = View.GONE
            } catch (ex: Exception) {
                showToast("Camera error: ${ex.message}")
            }
        }, ContextCompat.getMainExecutor(this))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Capture logic
    // ─────────────────────────────────────────────────────────────────────────

    private fun capturePhoto() {
        val tagNo = binding.etTagNo.text.toString().trim()
        if (tagNo.isEmpty()) {
            showToast("Please enter a Tag No before capturing.")
            binding.etTagNo.requestFocus()
            return
        }

        val folderUri = saveFolderUri ?: run {
            showToast("Please choose a save location first (tap Change Location).")
            return
        }

        val folder = DocumentFile.fromTreeUri(this, folderUri) ?: run {
            showToast("Save folder not accessible. Please choose again.")
            return
        }
        if (!folder.canWrite()) {
            showToast("Cannot write to folder. Please choose again.")
            return
        }

        val imgCapture = imageCapture ?: run {
            showToast("Camera not ready yet. Please wait.")
            return
        }

        // Lock textboxes when photo capture sequence starts
        binding.etTagNo.isEnabled = false
        binding.etMinQty.isEnabled = false
        binding.btnScan.isEnabled = false

        // ── Capture the image as an ImageProxy ───────────────────────────────
        binding.btnCapture.isEnabled = false
        binding.btnCapture.text = "Saving…"

        imgCapture.takePicture(
            ContextCompat.getMainExecutor(this),
            object : ImageCapture.OnImageCapturedCallback() {
                override fun onCaptureSuccess(imageProxy: ImageProxy) {
                    cameraExecutor.execute {
                        try {
                            // Extract bitmap (toBitmap() handles rotation automatically)
                            val bitmap = imageProxy.toBitmap()
                            imageProxy.close()

                            // Get user selected compression method
                            val compSetting = prefs.compression
                            val (mimeType, ext) = if (compSetting == "PNG") {
                                "image/png" to "png"
                            } else {
                                "image/jpeg" to "jpg"
                            }

                            // Determine unique filename
                            val fileName = TagNoResolver.resolveFileName(folder, tagNo, ext)
                            val newFile = folder.createFile(mimeType, fileName.removeSuffix(".$ext"))
                            if (newFile == null) {
                                runOnUiThread {
                                    showToast("Could not create file '$fileName' in chosen folder.")
                                    resetCaptureButton()
                                    asyncUpdateTagCountAndPreview()
                                }
                                return@execute
                            }

                            val outputStream = contentResolver.openOutputStream(newFile.uri)
                                ?: throw IOException("Null output stream")

                            outputStream.use { os ->
                                if (compSetting == "PNG") {
                                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, os)
                                } else {
                                    val quality = when (compSetting) {
                                        "JPEG_100" -> 100
                                        "JPEG_75"  -> 75
                                        else       -> 90
                                    }
                                    bitmap.compress(Bitmap.CompressFormat.JPEG, quality, os)
                                }
                            }

                            prefs.totalCount++
                            val bmp = decodeThumbnail(newFile.uri)
                            runOnUiThread {
                                if (bmp != null) {
                                    binding.ivLastImagePreview.setImageBitmap(bmp)
                                }
                                showToast("✓ Saved  →  $fileName")
                                resetCaptureButton()
                                asyncUpdateTagCountAndPreview()
                            }
                        } catch (ex: Exception) {
                            runOnUiThread {
                                showToast("Save failed: ${ex.localizedMessage ?: "Unknown error"}")
                                resetCaptureButton()
                                asyncUpdateTagCountAndPreview()
                            }
                        }
                    }
                }

                override fun onError(ex: ImageCaptureException) {
                    runOnUiThread {
                        showToast("Capture failed: ${ex.message}")
                        resetCaptureButton()
                        asyncUpdateTagCountAndPreview()
                    }
                }
            }
        )
    }

    private fun resetCaptureButton() {
        binding.btnCapture.isEnabled = true
        binding.btnCapture.text = getString(R.string.capture_btn_label)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // UI helpers
    // ─────────────────────────────────────────────────────────────────────────

    private fun asyncUpdateTagCountAndPreview() {
        val tagNo = binding.etTagNo.text.toString().trim()
        val folderUri = saveFolderUri

        if (tagNo.isEmpty() || folderUri == null) {
            binding.tvTotalCount.text = "Total images saved qty: 0"
            binding.ivLastImagePreview.setImageBitmap(null)
            binding.etTagNo.isEnabled = true
            binding.etMinQty.isEnabled = true
            binding.btnScan.isEnabled = true
            return
        }

        cameraExecutor.execute {
            val folder = DocumentFile.fromTreeUri(this@MainActivity, folderUri)
            if (folder == null || !folder.exists()) {
                runOnUiThread {
                    binding.tvTotalCount.text = "Total images saved qty: 0"
                    binding.ivLastImagePreview.setImageBitmap(null)
                }
                return@execute
            }

            val count = TagNoResolver.getCountForTag(folder, tagNo)
            val lastFile = TagNoResolver.getLastImageForTag(folder, tagNo)
            val bmp = lastFile?.let { decodeThumbnail(it.uri) }

            runOnUiThread {
                if (binding.etTagNo.text.toString().trim() == tagNo) {
                    binding.tvTotalCount.text = "Total images saved qty: $count"
                    binding.ivLastImagePreview.setImageBitmap(bmp)
                    checkLockState(count)
                }
            }
        }
    }

    private fun checkLockState(count: Int) {
        val minQty = binding.etMinQty.text.toString().trim().toIntOrNull() ?: 1
        if (!binding.etTagNo.isEnabled) {
            if (count >= minQty) {
                binding.etTagNo.isEnabled = true
                binding.etMinQty.isEnabled = true
                binding.btnScan.isEnabled = true
            }
        }
    }

    private fun decodeThumbnail(uri: Uri): Bitmap? {
        return try {
            contentResolver.openInputStream(uri)?.use { stream ->
                val options = BitmapFactory.Options().apply {
                    inJustDecodeBounds = true
                }
                BitmapFactory.decodeStream(stream, null, options)

                val targetSize = 150
                var sampleSize = 1
                if (options.outHeight > targetSize || options.outWidth > targetSize) {
                    val halfHeight = options.outHeight / 2
                    val halfWidth = options.outWidth / 2
                    while ((halfHeight / sampleSize) >= targetSize && (halfWidth / sampleSize) >= targetSize) {
                        sampleSize *= 2
                    }
                }

                contentResolver.openInputStream(uri)?.use { finalStream ->
                    val finalOptions = BitmapFactory.Options().apply {
                        inSampleSize = sampleSize
                    }
                    BitmapFactory.decodeStream(finalStream, null, finalOptions)
                }
            }
        } catch (ex: Exception) {
            null
        }
    }

    private fun refreshLocationLabel(uri: Uri) {
        val folder = DocumentFile.fromTreeUri(this, uri)
        val name = folder?.name ?: uri.lastPathSegment ?: uri.toString()
        binding.tvSaveLocation.text = ".../$name"
    }

    private fun showToast(msg: String) =
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()

    private fun allPermissionsGranted() = requiredPermissions.all {
        ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
    }
}
