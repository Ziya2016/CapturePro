package com.capturepro.photo

import android.annotation.SuppressLint
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.util.Base64
import android.view.View
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import java.io.ByteArrayOutputStream

class LensPreviewActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    private lateinit var progressBar: ProgressBar
    private var lastKnownUrl: String? = null

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_lens_preview)

        webView         = findViewById(R.id.webView)
        progressBar     = findViewById(R.id.progressBar)
        val btnBack         = findViewById<TextView>(R.id.btnBack)
        val btnCopySelected = findViewById<TextView>(R.id.btnCopySelected)

        // ── Close button: always closes activity, no matter what WebView shows ──
        btnBack.setOnClickListener {
            webView.stopLoading()
            finish()
        }

        // ── Android back press: navigate within WebView, or close ──────────────
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (webView.canGoBack()) {
                    webView.goBack()
                } else {
                    finish()
                }
            }
        })

        // ── WebView settings ────────────────────────────────────────────────────
        webView.settings.apply {
            javaScriptEnabled       = true
            domStorageEnabled       = true
            useWideViewPort         = true
            loadWithOverviewMode    = true
            setSupportZoom(true)
            builtInZoomControls     = true
            displayZoomControls     = false
            // English-locale Chrome UA so Google returns English results
            userAgentString         =
                "Mozilla/5.0 (Linux; Android 11; Pixel 5) " +
                "AppleWebKit/537.36 (KHTML, like Gecko) " +
                "Chrome/120.0.0.0 Mobile Safari/537.36"
        }

        webView.webViewClient = object : WebViewClient() {

            /** Force English on every Google URL by injecting hl=en */
            override fun shouldOverrideUrlLoading(
                view: WebView?, request: WebResourceRequest?
            ): Boolean {
                val rawUrl = request?.url?.toString() ?: return false
                lastKnownUrl = rawUrl

                val url = forceEnglish(rawUrl)
                if (url != rawUrl) {
                    view?.loadUrl(url)
                    return true
                }
                return false   // let the WebView load normally
            }

            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                super.onPageStarted(view, url, favicon)
                if (url != null) lastKnownUrl = url
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                if (url != null) lastKnownUrl = url
                progressBar.visibility = View.GONE
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                progressBar.visibility = if (newProgress < 100) View.VISIBLE else View.GONE
            }
        }

        // ── Clipboard copy ───────────────────────────────────────────────────────
        btnCopySelected.setOnClickListener {
            webView.evaluateJavascript(
                "(function(){ return window.getSelection().toString(); })()"
            ) { raw ->
                val selected = raw
                    ?.takeIf { it != "null" && it.length > 2 }
                    ?.removeSurrounding("\"")
                    ?.replace("\\n", "\n")
                    ?.replace("\\\"", "\"")
                    ?.trim()
                    ?: ""

                val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                if (selected.isNotEmpty()) {
                    clipboard.setPrimaryClip(
                        ClipData.newPlainText("Google Lens Result", selected)
                    )
                    Toast.makeText(this, "✅ Selected text copied!", Toast.LENGTH_SHORT).show()
                } else {
                    val url = lastKnownUrl ?: webView.url ?: ""
                    if (url.isNotEmpty()) {
                        clipboard.setPrimaryClip(ClipData.newPlainText("Lens Page URL", url))
                        Toast.makeText(this,
                            "No text selected — page URL copied.\n(Long-press text to select it first)",
                            Toast.LENGTH_LONG).show()
                    } else {
                        Toast.makeText(this,
                            "Long-press any text on the page to select it, then tap Copy Text",
                            Toast.LENGTH_LONG).show()
                    }
                }
            }
        }

        // ── Decide what to load ──────────────────────────────────────────────────
        val imageUriStr = intent.getStringExtra("EXTRA_IMAGE_URI")
        val directUrl   = intent.getStringExtra("EXTRA_URL")

        when {
            imageUriStr != null -> prepareAndUpload(Uri.parse(imageUriStr))
            directUrl   != null -> webView.loadUrl(forceEnglish(directUrl))
            else -> { Toast.makeText(this, "Nothing to show", Toast.LENGTH_SHORT).show(); finish() }
        }
    }

    /** Append hl=en (and lr=lang_en) to any google.com URL that lacks it */
    private fun forceEnglish(url: String): String {
        if (!url.contains("google.com")) return url
        var result = url
        if (!result.contains("hl=")) {
            result += if (result.contains("?")) "&hl=en" else "?hl=en"
        } else {
            // Replace existing hl= with en
            result = result.replace(Regex("hl=[^&]+"), "hl=en")
        }
        if (!result.contains("lr=")) {
            result += "&lr=lang_en"
        }
        return result
    }

    // ── Step 1: resize + encode image on background thread ──────────────────────
    private fun prepareAndUpload(imageUri: Uri) {
        progressBar.visibility = View.VISIBLE

        Thread {
            try {
                val rawBytes = contentResolver.openInputStream(imageUri)
                    ?.use { it.readBytes() }
                    ?: throw Exception("Cannot read image from URI")

                val src = BitmapFactory.decodeByteArray(rawBytes, 0, rawBytes.size)
                    ?: throw Exception("Cannot decode bitmap")

                val uploadBytes: ByteArray = if (src.width > 800) {
                    val scale  = 800f / src.width
                    val scaled = Bitmap.createScaledBitmap(
                        src, 800, (src.height * scale).toInt(), true
                    )
                    src.recycle()
                    ByteArrayOutputStream().also { baos ->
                        scaled.compress(Bitmap.CompressFormat.JPEG, 82, baos)
                        scaled.recycle()
                    }.toByteArray()
                } else {
                    src.recycle()
                    ByteArrayOutputStream().also { baos ->
                        val orig = BitmapFactory.decodeByteArray(rawBytes, 0, rawBytes.size)!!
                        orig.compress(Bitmap.CompressFormat.JPEG, 82, baos)
                        orig.recycle()
                    }.toByteArray()
                }

                val base64 = Base64.encodeToString(uploadBytes, Base64.NO_WRAP)
                runOnUiThread { showGoogleLensUploadPage(base64) }

            } catch (e: Exception) {
                runOnUiThread {
                    progressBar.visibility = View.GONE
                    Toast.makeText(this, "Image error: ${e.message}", Toast.LENGTH_LONG).show()
                    finish()
                }
            }
        }.start()
    }

    // ── Step 2: HTML page that POSTs via WebView cookies + forces English ────────
    private fun showGoogleLensUploadPage(base64Image: String) {
        val html = """
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#1C2535;display:flex;align-items:center;
     justify-content:center;height:100vh;font-family:sans-serif;color:#fff}
.wrap{text-align:center;padding:24px}
.spinner{width:52px;height:52px;border:4px solid rgba(66,133,244,.25);
         border-top:4px solid #4285F4;border-radius:50%;
         animation:spin .9s linear infinite;margin:0 auto 20px}
@keyframes spin{to{transform:rotate(360deg)}}
p{font-size:15px;opacity:.9;margin-bottom:6px}
small{font-size:11px;opacity:.45}
.err{color:#FF7043;font-size:13px;margin-top:12px;display:none}
</style>
</head>
<body>
<div class="wrap">
  <div class="spinner"></div>
  <p>🔍 Uploading to Google Lens...</p>
  <small>Using your Google account session</small>
  <div class="err" id="errMsg"></div>
</div>
<script>
(function(){
  var b64='$base64Image';
  try{
    var bin=atob(b64);
    var arr=new Uint8Array(bin.length);
    for(var i=0;i<bin.length;i++) arr[i]=bin.charCodeAt(i);
    var blob=new Blob([arr],{type:'image/jpeg'});
    var file=new File([blob],'capture.jpg',{type:'image/jpeg'});
    var fd=new FormData();
    fd.append('encoded_image',file,'capture.jpg');
    fd.append('image_content','');
    fetch('https://www.google.com/searchbyimage/upload',{
      method:'POST',
      body:fd,
      credentials:'include'
    }).then(function(r){
      // Force English language on the result URL
      var url = r.url;
      if(url.indexOf('hl=') === -1){
        url += (url.indexOf('?') !== -1 ? '&' : '?') + 'hl=en&lr=lang_en';
      } else {
        url = url.replace(/hl=[^&]+/,'hl=en');
        if(url.indexOf('lr=') === -1) url += '&lr=lang_en';
      }
      window.location.href = url;
    }).catch(function(e){
      var el=document.getElementById('errMsg');
      el.style.display='block';
      el.textContent='Upload failed: '+e.message;
      document.querySelector('.spinner').style.display='none';
    });
  }catch(e){
    var el=document.getElementById('errMsg');
    el.style.display='block';
    el.textContent='Error: '+e.message;
    document.querySelector('.spinner').style.display='none';
  }
})();
</script>
</body>
</html>
""".trimIndent()

        // CRITICAL: base URL = https://www.google.com/ so Google session cookies
        // are sent with the fetch → image accepted by the user's account
        webView.loadDataWithBaseURL(
            "https://www.google.com/",
            html,
            "text/html",
            "UTF-8",
            null
        )
    }
}
