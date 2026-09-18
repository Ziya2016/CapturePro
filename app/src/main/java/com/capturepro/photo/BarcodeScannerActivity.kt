package com.capturepro.photo

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Size
import android.view.View
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Standalone barcode/QR scanner activity using the bundled ML Kit library.
 * Works fully offline — no Google Play Services dependency.
 * Used as fallback when GmsBarcodeScanning fails (e.g., Samsung Knox devices).
 */
class BarcodeScannerActivity : AppCompatActivity() {

    private lateinit var previewView: PreviewView
    private lateinit var tvScanHint: TextView
    private lateinit var btnCancel: TextView

    private lateinit var cameraExecutor: ExecutorService
    private val resultDelivered = AtomicBoolean(false)
    private val barcodeScanner by lazy {
        BarcodeScanning.getClient()
    }

    companion object {
        const val EXTRA_BARCODE_VALUE = "barcode_value"
    }

    @androidx.camera.core.ExperimentalGetImage
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_barcode_scanner)

        previewView = findViewById(R.id.barcodePreviewView)
        tvScanHint  = findViewById(R.id.tvScanHint)
        btnCancel   = findViewById(R.id.btnScannerCancel)

        cameraExecutor = Executors.newSingleThreadExecutor()

        btnCancel.setOnClickListener {
            setResult(Activity.RESULT_CANCELED)
            finish()
        }

        startCamera()
    }

    @androidx.camera.core.ExperimentalGetImage
    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        cameraProviderFuture.addListener({
            val provider = cameraProviderFuture.get()

            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }

            val imageAnalysis = ImageAnalysis.Builder()
                .setTargetResolution(Size(1280, 720))
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()

            imageAnalysis.setAnalyzer(cameraExecutor) { imageProxy ->
                analyzeFrame(imageProxy)
            }

            try {
                provider.unbindAll()
                provider.bindToLifecycle(
                    this,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    preview,
                    imageAnalysis
                )
            } catch (ex: Exception) {
                Toast.makeText(this, "Camera error: ${ex.message}", Toast.LENGTH_SHORT).show()
                setResult(Activity.RESULT_CANCELED)
                finish()
            }
        }, ContextCompat.getMainExecutor(this))
    }

    @androidx.camera.core.ExperimentalGetImage
    private fun analyzeFrame(imageProxy: ImageProxy) {
        if (resultDelivered.get()) {
            imageProxy.close()
            return
        }

        val mediaImage = imageProxy.image
        if (mediaImage == null) {
            imageProxy.close()
            return
        }

        val inputImage = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)

        barcodeScanner.process(inputImage)
            .addOnSuccessListener { barcodes ->
                val barcode = barcodes.firstOrNull { !it.rawValue.isNullOrEmpty() }
                if (barcode != null && resultDelivered.compareAndSet(false, true)) {
                    val value = barcode.rawValue ?: ""
                    runOnUiThread {
                        val data = Intent().putExtra(EXTRA_BARCODE_VALUE, value)
                        setResult(Activity.RESULT_OK, data)
                        finish()
                    }
                }
            }
            .addOnFailureListener {
                // Ignore per-frame failures; keep scanning
            }
            .addOnCompleteListener {
                imageProxy.close()
            }
    }

    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor.shutdown()
        barcodeScanner.close()
    }

    override fun onBackPressed() {
        super.onBackPressed()
        setResult(Activity.RESULT_CANCELED)
    }
}
