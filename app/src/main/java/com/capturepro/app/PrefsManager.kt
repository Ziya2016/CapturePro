package com.capturepro.app

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

    companion object {
        private const val PREFS_NAME    = "capture_pro_prefs"
        private const val KEY_FOLDER_URI  = "folder_uri"
        private const val KEY_TOTAL_COUNT = "total_count"
        private const val KEY_MIN_QTY     = "min_qty"
        private const val KEY_COMPRESSION = "compression"
    }
}
