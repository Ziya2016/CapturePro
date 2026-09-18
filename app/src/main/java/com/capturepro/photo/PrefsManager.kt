package com.capturepro.photo

import android.content.Context
import android.content.SharedPreferences

/**
 * Thin wrapper over SharedPreferences for persisting app state.
 */
class PrefsManager(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** URI string of the user-chosen save folder (SAF tree URI). */
    var saveFolderUri: String?
        get() = prefs.getString(KEY_FOLDER_URI, null)
        set(value) = prefs.edit().putString(KEY_FOLDER_URI, value).apply()

    /** Running total of all images saved across sessions. */
    var totalCount: Int
        get() = prefs.getInt(KEY_TOTAL_COUNT, 0)
        set(value) = prefs.edit().putInt(KEY_TOTAL_COUNT, value).apply()

    /** Minimum quantity of images required for current tag. Default to 1. */
    var minQty: Int
        get() = prefs.getInt(KEY_MIN_QTY, 1)
        set(value) = prefs.edit().putInt(KEY_MIN_QTY, value).apply()

    /** Selected image quality / format configuration. Default is "JPEG_90". */
    var compression: String
        get() = prefs.getString(KEY_COMPRESSION, "JPEG_90") ?: "JPEG_90"
        set(value) = prefs.edit().putString(KEY_COMPRESSION, value).apply()

    /** Entered object size dimension. Default to "". */
    var objectSize: String
        get() = prefs.getString(KEY_OBJECT_SIZE, "") ?: ""
        set(value) = prefs.edit().putString(KEY_OBJECT_SIZE, value).apply()

    /** Selected object size unit. Default to "inch". */
    var sizeUnit: String
        get() = prefs.getString(KEY_SIZE_UNIT, "inch") ?: "inch"
        set(value) = prefs.edit().putString(KEY_SIZE_UNIT, value).apply()

    /** Toggle to show size overlay on camera. Default to false. */
    var showSize: Boolean
        get() = prefs.getBoolean(KEY_SHOW_SIZE, false)
        set(value) = prefs.edit().putBoolean(KEY_SHOW_SIZE, value).apply()

    /** Toggle to enable AI object identification. Default to false. */
    var identifyObject: Boolean
        get() = prefs.getBoolean(KEY_IDENTIFY_OBJECT, false)
        set(value) = prefs.edit().putBoolean(KEY_IDENTIFY_OBJECT, value).apply()

    /** Gemini API Key for AI Object Identification. */
    var geminiApiKey: String
        get() = prefs.getString(KEY_GEMINI_API_KEY, "") ?: ""
        set(value) = prefs.edit().putString(KEY_GEMINI_API_KEY, value).apply()

    companion object {
        private const val PREFS_NAME    = "capture_pro_prefs"
        private const val KEY_FOLDER_URI  = "folder_uri"
        private const val KEY_TOTAL_COUNT = "total_count"
        private const val KEY_MIN_QTY     = "min_qty"
        private const val KEY_COMPRESSION = "compression"
        private const val KEY_OBJECT_SIZE = "object_size"
        private const val KEY_SIZE_UNIT   = "size_unit"
        private const val KEY_SHOW_SIZE   = "show_size"
        private const val KEY_IDENTIFY_OBJECT = "identify_object"
        private const val KEY_GEMINI_API_KEY = "gemini_api_key"
    }
}
