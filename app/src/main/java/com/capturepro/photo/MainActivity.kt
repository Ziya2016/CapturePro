package com.capturepro.photo

import android.Manifest
import android.app.AlertDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import android.view.ViewGroup
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
import com.capturepro.photo.databinding.ActivityMainBinding
import com.capturepro.photo.databinding.ActivityExpiredBinding
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

    // ── Optical measurement state ─────────────────────────────────────────────
    private var currentFocusDistance: Float? = null
    private var cameraFocalLength: Float = 4.5f
    private var cameraSensorWidth: Float = 6.4f
    private var cameraSensorHeight: Float = 4.8f

    // ── State ─────────────────────────────────────────────────────────────────
    private var saveFolderUri: Uri? = null
    private var torchOn: Boolean = false
    private var lastPreviewUri: Uri? = null  // URI of the last captured image for full-res preview

    // ── Fullscreen camera state ──────────────────────────────────────────────
    private var isFullscreenCamera = false
    private var cameraPreview: Preview? = null
    private var currentZoomRatio = 1.0f

    // ── AI Identify state ─────────────────────────────────────────────────────
    private var identifyHandler: android.os.Handler? = null
    private var identifyRunnable: Runnable? = null
    private var isSendingRequest = false

    // ── Login state ───────────────────────────────────────────────────────────
    private var loggedInUser: String = ""
    private var isAdmin: Boolean = false

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

    // ── Fallback barcode scanner result handler ────────────────────────────────
    private val fallbackScannerLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == android.app.Activity.RESULT_OK) {
            val value = result.data?.getStringExtra(BarcodeScannerActivity.EXTRA_BARCODE_VALUE)
            if (!value.isNullOrEmpty()) {
                binding.etTagNo.setText(value)
                binding.etTagNo.requestFocus()
            }
        }
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

        // ── Read login context from intent ───────────────────────────────────
        loggedInUser = intent.getStringExtra("logged_in_user") ?: "User"
        isAdmin = intent.getBooleanExtra("is_admin", false)

        prefs = PrefsManager(this)
        cameraExecutor = Executors.newSingleThreadExecutor()

        restoreSavedFolder()
        setupCameraSpinner()
        setupCompressionSpinner()
        setupClickListeners()
        setupTextWatchers()
        setupHeaderUserInfo()
        setupPreviewAspectRatio()
        setupSizeInputs()
        setupFullscreenCamera()

        onBackPressedDispatcher.addCallback(this, object : androidx.activity.OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (isFullscreenCamera) {
                    closeFullscreenCamera()
                } else {
                    finish()
                }
            }
        })

        if (allPermissionsGranted()) startCamera()
        else permissionLauncher.launch(requiredPermissions)
    }

    /** Sets the preview container height to a 4:3 ratio based on the actual container width.
     *  Called after setContentView so the view tree is ready for measurement. */
    private fun setupPreviewAspectRatio() {
        binding.previewContainer.viewTreeObserver.addOnGlobalLayoutListener(object :
            android.view.ViewTreeObserver.OnGlobalLayoutListener {
            override fun onGlobalLayout() {
                binding.previewContainer.viewTreeObserver.removeOnGlobalLayoutListener(this)
                val width = binding.previewContainer.width
                if (width > 0) {
                    // 4:3 ratio → height = width * 3 / 4
                    val height = width * 3 / 4
                    val params = binding.previewContainer.layoutParams
                    params.height = height
                    binding.previewContainer.layoutParams = params
                }
            }
        })
    }

    override fun onResume() {
        super.onResume()
        if (allPermissionsGranted()) {
            startCamera()
        }
    }

    override fun onPause() {
        super.onPause()
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

        // Tap thumbnail → full-screen viewer (load full-res from URI, not tiny thumbnail)
        binding.ivLastImagePreview.setOnClickListener {
            val uri = lastPreviewUri
            if (uri != null) {
                showFullScreenImageFromUri(uri)
            } else {
                showToast("No image captured yet.")
            }
        }

        binding.btnScan.setOnClickListener {
            // Try Google Code Scanner first (primary)
            scanner.startScan()
                .addOnSuccessListener { barcode ->
                    val rawValue = barcode.rawValue
                    if (!rawValue.isNullOrEmpty()) {
                        binding.etTagNo.setText(rawValue)
                        binding.etTagNo.requestFocus()
                    }
                }
                .addOnFailureListener {
                    // Google Code Scanner failed (e.g., Knox device, Play Services issue)
                    // Automatically fall back to the bundled ML Kit scanner
                    launchFallbackScanner()
                }
        }

        binding.btnReset.setOnClickListener {
            binding.etTagNo.setText("")
            binding.etTagNo.isEnabled = true
            binding.etMinQty.isEnabled = true
            binding.btnScan.isEnabled = true
            binding.etObjectSize.isEnabled = true
            binding.switchShowSize.isEnabled = true
            binding.switchIdentifyObject.isEnabled = true
            binding.etTagNo.requestFocus()
        }
    }

    // ── Full-screen image viewer ───────────────────────────────────────────────

    /** Launches the bundled ML Kit barcode scanner as a fallback when Google Code Scanner fails. */
    private fun launchFallbackScanner() {
        fallbackScannerLauncher.launch(
            Intent(this, BarcodeScannerActivity::class.java)
        )
    }

    private fun showFullScreenImage(bitmap: android.graphics.Bitmap) {
        val dialogView = android.view.LayoutInflater.from(this)
            .inflate(R.layout.dialog_fullscreen_image, null)
        val ivFull = dialogView.findViewById<android.widget.ImageView>(R.id.ivFullImage)
        val btnClose = dialogView.findViewById<android.widget.TextView>(R.id.btnCloseFullImage)

        ivFull.setImageBitmap(bitmap)

        val dialog = android.app.AlertDialog.Builder(this)
            .setView(dialogView)
            .setCancelable(true)
            .create()

        dialog.window?.apply {
            setLayout(
                android.view.WindowManager.LayoutParams.MATCH_PARENT,
                android.view.WindowManager.LayoutParams.MATCH_PARENT
            )
            setBackgroundDrawableResource(android.R.color.transparent)
            addFlags(android.view.WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
        }

        btnClose.setOnClickListener { dialog.dismiss() }
        dialog.show()
    }

    /** Loads the full-resolution image from [uri] on a background thread then shows it full-screen. */
    private fun showFullScreenImageFromUri(uri: Uri) {
        val dialogView = android.view.LayoutInflater.from(this)
            .inflate(R.layout.dialog_fullscreen_image, null)
        val ivFull = dialogView.findViewById<android.widget.ImageView>(R.id.ivFullImage)
        val btnClose = dialogView.findViewById<android.widget.TextView>(R.id.btnCloseFullImage)

        // Show a placeholder while loading
        ivFull.setImageResource(android.R.drawable.ic_menu_gallery)

        val dialog = android.app.AlertDialog.Builder(this)
            .setView(dialogView)
            .setCancelable(true)
            .create()

        dialog.window?.apply {
            setLayout(
                android.view.WindowManager.LayoutParams.MATCH_PARENT,
                android.view.WindowManager.LayoutParams.MATCH_PARENT
            )
            setBackgroundDrawableResource(android.R.color.transparent)
            addFlags(android.view.WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
        }

        btnClose.setOnClickListener { dialog.dismiss() }
        dialog.show()

        // Decode the full-resolution bitmap on a background thread
        cameraExecutor.execute {
            try {
                val displayMetrics = resources.displayMetrics
                val screenW = displayMetrics.widthPixels
                val screenH = displayMetrics.heightPixels

                // First pass: get image dimensions
                val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opts) }

                // Sample down only as needed to fit the screen (preserving quality)
                var sampleSize = 1
                while ((opts.outWidth / (sampleSize * 2)) >= screenW &&
                       (opts.outHeight / (sampleSize * 2)) >= screenH) {
                    sampleSize *= 2
                }

                val fullOpts = BitmapFactory.Options().apply { inSampleSize = sampleSize }
                val fullBmp = contentResolver.openInputStream(uri)?.use {
                    BitmapFactory.decodeStream(it, null, fullOpts)
                }

                runOnUiThread {
                    if (dialog.isShowing) {
                        if (fullBmp != null) {
                            ivFull.setImageBitmap(fullBmp)
                        } else {
                            showToast("Could not load image.")
                            dialog.dismiss()
                        }
                    }
                }
            } catch (ex: Exception) {
                runOnUiThread {
                    if (dialog.isShowing) {
                        showToast("Could not load image: ${ex.message}")
                        dialog.dismiss()
                    }
                }
            }
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
            private var lastTagNo: String = binding.etTagNo.text.toString()
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                val currentTag = s?.toString() ?: ""
                if (currentTag != lastTagNo) {
                    lastTagNo = currentTag
                    // Auto-reset "Text" field when Tag No changes
                    binding.etObjectSize.setText("")
                }
                asyncUpdateTagCountAndPreview()
            }
        })
    }

    private fun setupSizeInputs() {
        binding.etObjectSize.setText(prefs.objectSize)

        binding.etObjectSize.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                prefs.objectSize = s?.toString()?.trim() ?: ""
            }
        })

        binding.switchShowSize.isChecked = prefs.showSize
        updateMeasuredOverlay()

        binding.switchShowSize.setOnCheckedChangeListener { _, isChecked ->
            prefs.showSize = isChecked
            updateMeasuredOverlay()
        }

        binding.switchIdentifyObject.isChecked = prefs.identifyObject
        updateIdentifyOverlay()

        binding.switchIdentifyObject.setOnCheckedChangeListener { _, isChecked ->
            prefs.identifyObject = isChecked
            updateIdentifyOverlay()
            if (isChecked) {
                triggerIdentify()
            }
        }

        binding.btnReIdentify.setOnClickListener {
            binding.btnReIdentify.isEnabled = false
            binding.btnReIdentify.postDelayed({ binding.btnReIdentify.isEnabled = true }, 2000)
            triggerIdentify()
        }
        // Enable resizing of target box by touching and dragging the borders
        val targetView = binding.viewMeasurementTarget
        targetView.setOnTouchListener(object : android.view.View.OnTouchListener {
            private var activePointerId = -1
            private var lastRawX = 0f
            private var lastRawY = 0f
            private var nearLeft = false
            private var nearRight = false
            private var nearTop = false
            private var nearBottom = false
            private var isResizing = false

            @android.annotation.SuppressLint("ClickableViewAccessibility")
            override fun onTouch(v: android.view.View, event: android.view.MotionEvent): Boolean {
                val threshold = 36 * resources.displayMetrics.density

                if (v.layoutParams.width == android.widget.RelativeLayout.LayoutParams.MATCH_PARENT || v.layoutParams.width <= 0) {
                    if (v.width > 0) {
                        val params = v.layoutParams
                        params.width = v.width
                        params.height = v.height
                        v.layoutParams = params
                    }
                }

                when (event.actionMasked) {
                    android.view.MotionEvent.ACTION_DOWN -> {
                        val w = v.width.toFloat()
                        val h = v.height.toFloat()
                        val x = event.x
                        val y = event.y

                        nearLeft = Math.abs(x) < threshold
                        nearRight = Math.abs(x - w) < threshold
                        nearTop = Math.abs(y) < threshold
                        nearBottom = Math.abs(y - h) < threshold

                        if (nearLeft || nearRight || nearTop || nearBottom) {
                            isResizing = true
                            activePointerId = event.getPointerId(0)
                            lastRawX = event.rawX
                            lastRawY = event.rawY
                            v.parent?.requestDisallowInterceptTouchEvent(true)
                            return true
                        }
                    }
                    android.view.MotionEvent.ACTION_MOVE -> {
                        if (isResizing) {
                            val pointerIndex = event.findPointerIndex(activePointerId)
                            if (pointerIndex != -1) {
                                val currentRawX = event.getRawX(pointerIndex)
                                val currentRawY = event.getRawY(pointerIndex)

                                val dx = currentRawX - lastRawX
                                val dy = currentRawY - lastRawY

                                val params = v.layoutParams
                                val parent = v.parent as? android.view.View ?: return false
                                val parentW = parent.width
                                val parentH = parent.height

                                var deltaW = 0f
                                if (nearLeft) {
                                    deltaW = -dx * 2f
                                } else if (nearRight) {
                                    deltaW = dx * 2f
                                }

                                var deltaH = 0f
                                if (nearTop) {
                                    deltaH = -dy * 2f
                                } else if (nearBottom) {
                                    deltaH = dy * 2f
                                }

                                if (nearLeft || nearRight) {
                                    val currentW = v.width
                                    val minW = 100 * resources.displayMetrics.density
                                    val maxW = parentW - 20 * resources.displayMetrics.density
                                    params.width = (currentW + deltaW).coerceIn(minW, maxW).toInt()
                                }

                                if (nearTop || nearBottom) {
                                    val currentH = v.height
                                    val minH = 100 * resources.displayMetrics.density
                                    val maxH = parentH - 20 * resources.displayMetrics.density
                                    params.height = (currentH + deltaH).coerceIn(minH, maxH).toInt()
                                }

                                v.layoutParams = params
                                lastRawX = currentRawX
                                lastRawY = currentRawY

                                updateMeasuredOverlay()
                            }
                            return true
                        }
                    }
                    android.view.MotionEvent.ACTION_UP, android.view.MotionEvent.ACTION_CANCEL -> {
                        isResizing = false
                        activePointerId = -1
                        v.parent?.requestDisallowInterceptTouchEvent(false)
                    }
                }
                return false
            }
        })
    }

    private fun updateMeasuredOverlay() {
        if (!prefs.showSize) {
            binding.layoutSizeOverlay.visibility = View.GONE
            return
        }
        binding.layoutSizeOverlay.visibility = View.VISIBLE

        val focusDist = currentFocusDistance
        val distanceMeters = if (focusDist != null && focusDist > 0f) {
            1.0f / focusDist
        } else {
            2.0f // Fallback to 2.0 meters when device doesn't report focus distance
        }

        val viewWidth = binding.previewView.width.toFloat()
        val viewHeight = binding.previewView.height.toFloat()
        val targetW = binding.viewMeasurementTarget.width.toFloat()
        val targetH = binding.viewMeasurementTarget.height.toFloat()

        val fractionX = if (viewWidth > 0f && targetW > 0f) targetW / viewWidth else 0.7f
        val fractionY = if (viewHeight > 0f && targetH > 0f) targetH / viewHeight else 0.7f

        val frameWidthMeters = (distanceMeters * cameraSensorWidth) / cameraFocalLength
        val frameHeightMeters = (distanceMeters * cameraSensorHeight) / cameraFocalLength

        val objWidthMeters = frameWidthMeters * fractionX
        val objHeightMeters = frameHeightMeters * fractionY

        val widthInches = objWidthMeters * 39.3701f
        val heightInches = objHeightMeters * 39.3701f
        val widthCm = objWidthMeters * 100f
        val heightCm = objHeightMeters * 100f
        val maxSpanInches = maxOf(widthInches, heightInches)

        // Primary: W x H for any shape (rectangle, circle, irregular)
        binding.tvMeasuredDimensions.text =
            "${String.format("%.1f", widthInches)}\" W x ${String.format("%.1f", heightInches)}\" H" +
            "  (${String.format("%.0f", widthCm)} x ${String.format("%.0f", heightCm)} cm)"

        // Secondary: estimated span + focus state
        val focusInfo = if (focusDist != null && focusDist > 0f) {
            "~${String.format("%.2f", distanceMeters)}m"
        } else {
            "default dist"
        }
        binding.tvMeasuredDiag.text = "Estimated Span: ~${String.format("%.0f", maxSpanInches)}\"  [Focus: $focusInfo]"
    }

    private fun drawTextOverlay(original: Bitmap, text: String, isLeftAlign: Boolean, textColor: Int): Bitmap {
        return try {
            val result = original.copy(original.config, true)
            val canvas = android.graphics.Canvas(result)
            val paint = android.graphics.Paint().apply {
                color = textColor
                isAntiAlias = true
                style = android.graphics.Paint.Style.FILL
                textSize = (result.width * 0.035f).coerceIn(36f, 120f)
                typeface = android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.NORMAL)
            }

            val bounds = android.graphics.Rect()
            paint.getTextBounds(text, 0, text.length, bounds)

            val marginX = result.width * 0.04f
            val marginY = result.height * 0.04f
            val x = if (isLeftAlign) {
                marginX
            } else {
                result.width - bounds.width() - marginX
            }
            val y = result.height - marginY

            val bgPaint = android.graphics.Paint().apply {
                color = android.graphics.Color.parseColor("#99000000") // ~60% opacity black
                style = android.graphics.Paint.Style.FILL
            }

            val paddingX = paint.textSize * 0.4f
            val paddingY = paint.textSize * 0.3f
            val rectLeft = x - paddingX
            val rectTop = y - bounds.height() - paddingY
            val rectRight = x + bounds.width() + paddingX
            val rectBottom = y + paddingY

            canvas.drawRoundRect(
                rectLeft, rectTop, rectRight, rectBottom,
                paint.textSize * 0.2f, paint.textSize * 0.2f,
                bgPaint
            )

            // Draw an outline to enhance contrast and prevent color bleed
            val outlineColor = when (textColor) {
                android.graphics.Color.WHITE -> android.graphics.Color.BLACK
                android.graphics.Color.RED -> android.graphics.Color.WHITE
                else -> android.graphics.Color.BLACK
            }
            val strokePaint = android.graphics.Paint(paint).apply {
                color = outlineColor
                style = android.graphics.Paint.Style.STROKE
                strokeWidth = paint.textSize * 0.08f
            }
            canvas.drawText(text, x, y, strokePaint)

            canvas.drawText(text, x, y, paint)
            result
        } catch (e: Exception) {
            original
        }
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

    // ── Header user info + admin panel ────────────────────────────────────────

    private fun setupHeaderUserInfo() {
        // Show user name in header if the view exists
        binding.tvLoggedInUser?.let { tv ->
            tv.text = loggedInUser
            tv.visibility = View.VISIBLE
        }

        // Admin badge / manage users button
        binding.btnAdminPanel?.let { btn ->
            if (isAdmin) {
                btn.visibility = View.VISIBLE
                btn.setOnClickListener { showAdminPanel() }
            } else {
                btn.visibility = View.GONE
            }
        }

        // Logout button (visible to all)
        binding.btnLogout?.let { btn ->
            btn.visibility = View.VISIBLE
            btn.setOnClickListener { confirmLogout() }
        }
    }

    private fun showAdminPanel() {
        val dialogView = LayoutInflater.from(this).inflate(R.layout.dialog_admin_panel, null)
        val layoutUsersContainer = dialogView.findViewById<LinearLayout>(R.id.layoutUsersContainer)
        val btnAddUser = dialogView.findViewById<Button>(R.id.btnAddUserAdmin)
        val btnCancel  = dialogView.findViewById<Button>(R.id.btnCancelAdmin)

        val dialog = AlertDialog.Builder(this)
            .setView(dialogView)
            .setCancelable(true)
            .create()
        dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)

        val dp = resources.displayMetrics.density

        fun populateUsers() {
            layoutUsersContainer.removeAllViews()
            val accounts = UserManager.getAllUserAccounts(this)

            accounts.forEach { acc ->
                val rowView = LinearLayout(this).apply {
                    orientation = LinearLayout.VERTICAL
                    setBackgroundResource(R.drawable.bg_input)
                    setPadding((12 * dp).toInt(), (10 * dp).toInt(), (12 * dp).toInt(), (10 * dp).toInt())
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        bottomMargin = (10 * dp).toInt()
                    }
                }

                // Row header: Username + Status
                val headerRow = LinearLayout(this).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = android.view.Gravity.CENTER_VERTICAL
                }

                val tvName = TextView(this).apply {
                    text = acc.username + if (acc.isAdmin) " (Admin)" else ""
                    setTextColor(getColor(R.color.white))
                    setTypeface(null, android.graphics.Typeface.BOLD)
                    textSize = 14f
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                }

                val isExpired = acc.expiryDate != null && UserManager.isExpired(acc.expiryDate)
                val statusText = when {
                    acc.isAdmin || acc.expiryDate == null -> "No Expiry"
                    isExpired -> "Expired"
                    else -> "Active"
                }
                val statusColor = when {
                    acc.isAdmin || acc.expiryDate == null -> getColor(R.color.accent_orange)
                    isExpired -> getColor(android.R.color.holo_red_light)
                    else -> getColor(android.R.color.holo_green_light)
                }

                val tvStatus = TextView(this).apply {
                    text = statusText
                    setTextColor(statusColor)
                    setTypeface(null, android.graphics.Typeface.BOLD)
                    textSize = 12f
                }

                headerRow.addView(tvName)
                headerRow.addView(tvStatus)
                rowView.addView(headerRow)

                // If not admin, show expiry input + Save + Remove buttons
                if (!acc.isAdmin) {
                    val editRow = LinearLayout(this).apply {
                        orientation = LinearLayout.HORIZONTAL
                        gravity = android.view.Gravity.CENTER_VERTICAL
                        layoutParams = LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.MATCH_PARENT,
                            LinearLayout.LayoutParams.WRAP_CONTENT
                        ).apply {
                            topMargin = (8 * dp).toInt()
                        }
                    }

                    val etExp = EditText(this).apply {
                        setText(acc.expiryDate ?: UserManager.DEFAULT_USER_EXPIRY)
                        hint = "dd-MM-yyyy"
                        setHintTextColor(getColor(R.color.text_secondary))
                        setTextColor(getColor(R.color.white))
                        setBackgroundResource(R.drawable.bg_card)
                        setPadding((10 * dp).toInt(), (8 * dp).toInt(), (10 * dp).toInt(), (8 * dp).toInt())
                        textSize = 12f
                        inputType = android.text.InputType.TYPE_CLASS_TEXT
                        maxLines = 1
                        isSingleLine = true
                        layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                            marginEnd = (8 * dp).toInt()
                        }
                    }

                    val btnSaveAcc = androidx.appcompat.widget.AppCompatButton(this).apply {
                        text = "Save"
                        setTextColor(getColor(R.color.white))
                        textSize = 11f
                        isAllCaps = false
                        setBackgroundResource(R.drawable.bg_btn_capture)
                        layoutParams = LinearLayout.LayoutParams((65 * dp).toInt(), (40 * dp).toInt()).apply {
                            marginEnd = (6 * dp).toInt()
                        }
                        setOnClickListener {
                            val newExp = etExp.text.toString().trim()
                            if (newExp.isEmpty() || !newExp.matches(Regex("""\d{2}-\d{2}-\d{4}"""))) {
                                showToast("Enter date as dd-MM-yyyy")
                                return@setOnClickListener
                            }
                            UserManager.updateUserExpiry(this@MainActivity, acc.username, newExp)
                            showToast("Updated ${acc.username} expiry → $newExp")
                            populateUsers()
                        }
                    }

                    val btnRemoveAcc = androidx.appcompat.widget.AppCompatButton(this).apply {
                        text = "Remove"
                        setTextColor(getColor(android.R.color.white))
                        textSize = 11f
                        isAllCaps = false
                        setBackgroundResource(R.drawable.bg_btn_reset)
                        layoutParams = LinearLayout.LayoutParams((72 * dp).toInt(), (40 * dp).toInt())
                        setOnClickListener {
                            AlertDialog.Builder(this@MainActivity)
                                .setTitle("Remove Account")
                                .setMessage("Are you sure you want to remove '${acc.username}'?")
                                .setPositiveButton("Remove") { _, _ ->
                                    UserManager.removeUser(this@MainActivity, acc.username)
                                    showToast("Removed ${acc.username}")
                                    populateUsers()
                                }
                                .setNegativeButton("Cancel", null)
                                .show()
                        }
                    }

                    editRow.addView(etExp)
                    editRow.addView(btnSaveAcc)
                    editRow.addView(btnRemoveAcc)
                    rowView.addView(editRow)
                } else {
                    val tvPerm = TextView(this).apply {
                        text = "Full Access · Permanent Account"
                        setTextColor(getColor(R.color.text_secondary))
                        textSize = 10f
                        layoutParams = LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.MATCH_PARENT,
                            LinearLayout.LayoutParams.WRAP_CONTENT
                        ).apply {
                            topMargin = (4 * dp).toInt()
                        }
                    }
                    rowView.addView(tvPerm)
                }

                layoutUsersContainer.addView(rowView)
            }
        }

        populateUsers()

        btnAddUser.setOnClickListener {
            val dialogCreateView = layoutInflater.inflate(R.layout.dialog_create_account, null)
            val etNewUser = dialogCreateView.findViewById<EditText>(R.id.etNewUsername)
            val etNewPass = dialogCreateView.findViewById<EditText>(R.id.etNewPassword)
            val btnCancelC = dialogCreateView.findViewById<Button>(R.id.btnCancelCreate)
            val btnSubmitC = dialogCreateView.findViewById<Button>(R.id.btnSubmitCreate)

            val createDialog = AlertDialog.Builder(this)
                .setView(dialogCreateView)
                .setCancelable(true)
                .create()
            createDialog.window?.setBackgroundDrawableResource(android.R.color.transparent)

            btnCancelC.setOnClickListener { createDialog.dismiss() }
            btnSubmitC.setOnClickListener {
                val u = etNewUser.text.toString().trim()
                val p = etNewPass.text.toString().trim()
                when (UserManager.registerUser(this, u, p)) {
                    is UserManager.RegisterResult.EmptyFields -> showToast("Fields cannot be empty")
                    is UserManager.RegisterResult.UserAlreadyExists -> showToast("User '$u' already exists")
                    is UserManager.RegisterResult.Success -> {
                        createDialog.dismiss()
                        showToast("✅ Created user '$u'")
                        populateUsers()
                    }
                }
            }
            createDialog.show()
        }

        btnCancel.setOnClickListener { dialog.dismiss() }
        dialog.show()
    }

    private fun confirmLogout() {
        AlertDialog.Builder(this)
            .setTitle("Sign Out")
            .setMessage("Are you sure you want to sign out?")
            .setPositiveButton("Sign Out") { _, _ ->
                LoginActivity.logout(this)
                startActivity(Intent(this, LoginActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                })
                finish()
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CameraX
    // ─────────────────────────────────────────────────────────────────────────

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        cameraProviderFuture.addListener({
            val provider = cameraProviderFuture.get()

            val previewBuilder = Preview.Builder()
            val camera2Extender = androidx.camera.camera2.interop.Camera2Interop.Extender(previewBuilder)
            camera2Extender.setSessionCaptureCallback(object : android.hardware.camera2.CameraCaptureSession.CaptureCallback() {
                override fun onCaptureCompleted(
                    session: android.hardware.camera2.CameraCaptureSession,
                    request: android.hardware.camera2.CaptureRequest,
                    result: android.hardware.camera2.TotalCaptureResult
                ) {
                    super.onCaptureCompleted(session, request, result)
                    val focusDist = result.get(android.hardware.camera2.CaptureResult.LENS_FOCUS_DISTANCE)
                    runOnUiThread {
                        currentFocusDistance = focusDist
                        updateMeasuredOverlay()
                    }
                }
            })

            val preview = previewBuilder.build().also {
                cameraPreview = it
                if (isFullscreenCamera) {
                    it.setSurfaceProvider(binding.fullscreenPreviewView.surfaceProvider)
                } else {
                    it.setSurfaceProvider(binding.previewView.surfaceProvider)
                }
            }

            imageCapture = ImageCapture.Builder()
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                .build()

            try {
                provider.unbindAll()
                val boundCamera = provider.bindToLifecycle(this, cameraSelector, preview, imageCapture)
                camera = boundCamera
                
                // Extract camera characteristics for optical measurement
                try {
                    val characteristics = androidx.camera.camera2.interop.Camera2CameraInfo.extractCameraCharacteristics(boundCamera.cameraInfo)
                    val focalLengths = characteristics.get(android.hardware.camera2.CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                    if (focalLengths != null && focalLengths.isNotEmpty()) {
                        cameraFocalLength = focalLengths[0]
                    }
                    val sensorSize = characteristics.get(android.hardware.camera2.CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)
                    if (sensorSize != null) {
                        cameraSensorWidth = sensorSize.width
                        cameraSensorHeight = sensorSize.height
                    }
                } catch (characteristicsEx: Exception) {
                    // Ignore, fallback to default focal length and sensor size
                }

                // Apply current torch state to new camera
                boundCamera.cameraControl.enableTorch(torchOn)
                // Hide placeholder text once camera is active
                binding.tvLiveLabel.visibility = View.GONE
            } catch (ex: Exception) {
                showToast("Camera error: ${ex.message}")
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun setupFullscreenCamera() {
        binding.btnEnlargePreview.setOnClickListener {
            openFullscreenCamera()
        }
        binding.btnFullscreenClose.setOnClickListener {
            closeFullscreenCamera()
        }
        binding.btnFullscreenCapture.setOnClickListener {
            capturePhoto()
        }
        binding.btnZoomIn.setOnClickListener {
            changeZoom(0.5f)
        }
        binding.btnZoomOut.setOnClickListener {
            changeZoom(-0.5f)
        }
    }

    private fun openFullscreenCamera() {
        isFullscreenCamera = true
        binding.layoutFullscreenCameraOverlay.visibility = View.VISIBLE
        cameraPreview?.setSurfaceProvider(binding.fullscreenPreviewView.surfaceProvider)
    }

    private fun closeFullscreenCamera() {
        isFullscreenCamera = false
        binding.layoutFullscreenCameraOverlay.visibility = View.GONE
        cameraPreview?.setSurfaceProvider(binding.previewView.surfaceProvider)
    }

    private fun changeZoom(delta: Float) {
        val cam = camera ?: return
        val zoomState = cam.cameraInfo.zoomState.value ?: return
        val minZoom = zoomState.minZoomRatio
        val maxZoom = zoomState.maxZoomRatio.coerceAtMost(8.0f)
        currentZoomRatio = (currentZoomRatio + delta).coerceIn(minZoom, maxZoom)
        cam.cameraControl.setZoomRatio(currentZoomRatio)
        showToast("Zoom: ${String.format(java.util.Locale.US, "%.1fx", currentZoomRatio)}")
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Capture logic
    // ─────────────────────────────────────────────────────────────────────────

    private fun getOrCreateDateFolderUri(baseUri: Uri): Uri? {
        val baseFolder = DocumentFile.fromTreeUri(this, baseUri) ?: return null
        val dateStr = java.text.SimpleDateFormat("dd-MM-yyyy", java.util.Locale.US).format(java.util.Date())
        val userStr = if (loggedInUser.isNotBlank()) loggedInUser else "User"
        val folderName = "$dateStr & $userStr"
        var dateFolder = baseFolder.findFile(folderName)
        if (dateFolder == null || !dateFolder.isDirectory) {
            dateFolder = baseFolder.createDirectory(folderName)
        }
        return dateFolder?.uri
    }

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

        val objectSizeText = binding.etObjectSize.text.toString().trim()
        
        // Calculate measured size text on UI thread if Show Size option is enabled
        val measuredSizeText = if (prefs.showSize) {
            val focusDist = currentFocusDistance
            val distanceMeters = if (focusDist != null && focusDist > 0f) {
                1.0f / focusDist
            } else {
                2.0f
            }
            val viewWidth = binding.previewView.width.toFloat()
            val viewHeight = binding.previewView.height.toFloat()
            val targetW = binding.viewMeasurementTarget.width.toFloat()
            val targetH = binding.viewMeasurementTarget.height.toFloat()

            val fractionX = if (viewWidth > 0f && targetW > 0f) targetW / viewWidth else 0.7f
            val fractionY = if (viewHeight > 0f && targetH > 0f) targetH / viewHeight else 0.7f

            val frameWidthMeters = (distanceMeters * cameraSensorWidth) / cameraFocalLength
            val frameHeightMeters = (distanceMeters * cameraSensorHeight) / cameraFocalLength

            val objWidthMeters = frameWidthMeters * fractionX
            val objHeightMeters = frameHeightMeters * fractionY

            val widthInches = objWidthMeters * 39.3701f
            val heightInches = objHeightMeters * 39.3701f
            val widthCm = objWidthMeters * 100f
            val heightCm = objHeightMeters * 100f

            "${String.format("%.1f", widthInches)}\" W x ${String.format("%.1f", heightInches)}\" H (${String.format("%.0f", widthCm)} x ${String.format("%.0f", heightCm)} cm)"
        } else {
            ""
        }

        // Lock textboxes when photo capture sequence starts
        binding.etTagNo.isEnabled = false
        binding.etMinQty.isEnabled = false
        binding.btnScan.isEnabled = false
        binding.etObjectSize.isEnabled = false
        binding.switchShowSize.isEnabled = false
        binding.switchIdentifyObject.isEnabled = false

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
                            val originalBitmap = imageProxy.toBitmap()
                            imageProxy.close()

                            var bitmap = originalBitmap
                            
                            // 1. Stamp custom text annotation (in WHITE on bottom-right)
                            if (objectSizeText.isNotEmpty()) {
                                val watermarked = drawTextOverlay(bitmap, objectSizeText, isLeftAlign = false, textColor = android.graphics.Color.WHITE)
                                if (watermarked != bitmap) {
                                    bitmap = watermarked
                                }
                            }
                            
                            // 2. Stamp camera measurement (in WHITE on bottom-left)
                            if (measuredSizeText.isNotEmpty()) {
                                val watermarked = drawTextOverlay(bitmap, measuredSizeText, isLeftAlign = true, textColor = android.graphics.Color.WHITE)
                                if (watermarked != bitmap) {
                                    if (bitmap != originalBitmap) {
                                        bitmap.recycle()
                                    }
                                    bitmap = watermarked
                                }
                            }
                            
                            // Recycle originalBitmap if a watermarked copy was created
                            if (bitmap != originalBitmap) {
                                originalBitmap.recycle()
                            }

                            // Get user selected compression method
                            val compSetting = prefs.compression
                            val (mimeType, ext) = if (compSetting == "PNG") {
                                "image/png" to "png"
                            } else {
                                "image/jpeg" to "jpg"
                            }

                            // Determine unique filename inside current date folder
                            val dateFolderUri = getOrCreateDateFolderUri(folderUri)
                                ?: throw IOException("Could not create/access date folder")
                            val dateFolder = DocumentFile.fromTreeUri(this@MainActivity, dateFolderUri)
                                ?: throw IOException("Could not open date folder")

                            val fileName = TagNoResolver.resolveFileName(this@MainActivity, dateFolderUri, tagNo, ext)
                            val newFile = dateFolder.createFile(mimeType, fileName.removeSuffix(".$ext"))
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
                                lastPreviewUri = newFile.uri
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
            binding.etObjectSize.isEnabled = true
            binding.switchShowSize.isEnabled = true
            binding.switchIdentifyObject.isEnabled = true
            return
        }

        cameraExecutor.execute {
            val dateFolderUri = getOrCreateDateFolderUri(folderUri)
            if (dateFolderUri == null) {
                runOnUiThread {
                    binding.tvTotalCount.text = "Total images saved qty: 0"
                    binding.ivLastImagePreview.setImageBitmap(null)
                }
                return@execute
            }

            val count = TagNoResolver.getCountForTag(this@MainActivity, dateFolderUri, tagNo)
            val lastUri = TagNoResolver.getLastImageUriForTag(this@MainActivity, dateFolderUri, tagNo)
            val bmp = lastUri?.let { decodeThumbnail(it) }

            runOnUiThread {
                if (binding.etTagNo.text.toString().trim() == tagNo) {
                    binding.tvTotalCount.text = "Total images saved qty: $count"
                    binding.ivLastImagePreview.setImageBitmap(bmp)
                    lastPreviewUri = lastUri
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
                binding.etObjectSize.isEnabled = true
                binding.switchShowSize.isEnabled = true
                binding.switchIdentifyObject.isEnabled = true
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

    private fun updateIdentifyOverlay() {
        if (prefs.identifyObject) {
            binding.layoutIdentifyOverlay.visibility = View.VISIBLE
        } else {
            binding.layoutIdentifyOverlay.visibility = View.GONE
        }
    }

    private fun isNetworkAvailable(): Boolean {
        val cm = getSystemService(android.content.Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager
        val network = cm.activeNetwork ?: return false
        val caps = cm.getNetworkCapabilities(network) ?: return false
        return caps.hasCapability(android.net.NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }

    private fun triggerIdentify() {
        if (!prefs.identifyObject) return

        if (!isNetworkAvailable()) {
            binding.tvIdentifyResults.text = "No Internet Connection"
            return
        }

        val capturedUri = lastPreviewUri
        if (capturedUri == null) {
            binding.tvIdentifyResults.text = "📷 Capture a photo first,\nthen tap Search"
            binding.tvIdentifyImageSource.text = "No photo captured yet"
            return
        }

        binding.tvIdentifyImageSource.text = "Opening Google Lens..."
        binding.tvIdentifyResults.text = "Launching search..."

        // Open in-app WebView — image upload happens there using user's Google session
        val intent = android.content.Intent(this, LensPreviewActivity::class.java)
        intent.putExtra("EXTRA_IMAGE_URI", capturedUri.toString())
        startActivity(intent)

        // Update overlay text for when user returns
        binding.tvIdentifyResults.text = "Results shown in viewer"
        binding.tvIdentifyImageSource.text = "Tap Search to search again"
    }
}
