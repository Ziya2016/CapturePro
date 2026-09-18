package com.capturepro.photo

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract

/**
 * Determines filenames and queries images efficiently using direct ContentResolver queries,
 * avoiding the slow DocumentFile.listFiles() wrapper overhead.
 */
object TagNoResolver {

    /** Strip filesystem-unsafe characters from the tag string. */
    fun sanitize(name: String): String =
        name.trim().replace(Regex("""[/\\:*?"<>|]"""), "_")

    private fun getDocIdForUri(uri: Uri): String {
        return try {
            DocumentsContract.getDocumentId(uri)
        } catch (e: Exception) {
            DocumentsContract.getTreeDocumentId(uri)
        }
    }

    /**
     * Queries the folder directly via ContentResolver for existing files with the target extension
     * and returns the next available filename.
     */
    fun resolveFileName(context: Context, folderUri: Uri, tagNo: String, ext: String): String {
        val baseName = sanitize(tagNo)
        val suffix = ".$ext"
        val existing = HashSet<String>()

        try {
            val docId = getDocIdForUri(folderUri)
            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(folderUri, docId)
            val projection = arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            
            context.contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
                val nameCol = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                while (cursor.moveToNext()) {
                    val name = cursor.getString(nameCol)
                    if (name != null) {
                        existing.add(name.lowercase())
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // Try base name first
        if ("${baseName.lowercase()}$suffix" !in existing) {
            return "$baseName$suffix"
        }

        // Increment suffix until a free slot is found
        var index = 2
        while ("${baseName.lowercase()}_$index$suffix" in existing) {
            index++
        }
        return "${baseName}_$index$suffix"
    }

    /**
     * Counts the number of existing files matching the tag prefix inside [folderUri].
     */
    fun getCountForTag(context: Context, folderUri: Uri, tagNo: String): Int {
        val baseName = sanitize(tagNo).lowercase()
        if (baseName.isEmpty()) return 0
        var count = 0

        try {
            val docId = getDocIdForUri(folderUri)
            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(folderUri, docId)
            val projection = arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME)

            context.contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
                val nameCol = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                while (cursor.moveToNext()) {
                    val name = cursor.getString(nameCol)?.lowercase() ?: continue
                    if (!name.endsWith(".jpg") && !name.endsWith(".jpeg") && !name.endsWith(".png")) continue
                    val baseWithoutExt = name.substringBeforeLast(".")
                    if (baseWithoutExt == baseName || (baseWithoutExt.startsWith("${baseName}_") &&
                                baseWithoutExt.substring(baseName.length + 1).all { it.isDigit() })) {
                        count++
                    }
                }
            }
        } catch (ex: Exception) {
            ex.printStackTrace()
        }
        return count
    }

    /**
     * Finds the last saved image matching the tag prefix inside [folderUri] (resolving the highest suffix index).
     */
    fun getLastImageUriForTag(context: Context, folderUri: Uri, tagNo: String): Uri? {
        val baseName = sanitize(tagNo).lowercase()
        if (baseName.isEmpty()) return null

        var lastUri: Uri? = null
        var maxIndex = -1

        try {
            val docId = getDocIdForUri(folderUri)
            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(folderUri, docId)
            val projection = arrayOf(
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_DOCUMENT_ID
            )

            context.contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
                val nameCol = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                val idCol = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                while (cursor.moveToNext()) {
                    val name = cursor.getString(nameCol) ?: continue
                    val nameLower = name.lowercase()
                    if (!nameLower.endsWith(".jpg") && !nameLower.endsWith(".jpeg") && !nameLower.endsWith(".png")) continue
                    val baseWithoutExt = nameLower.substringBeforeLast(".")
                    val isMatch = baseWithoutExt == baseName || (baseWithoutExt.startsWith("${baseName}_") &&
                            baseWithoutExt.substring(baseName.length + 1).all { it.isDigit() })
                    if (isMatch) {
                        val index = if (baseWithoutExt == baseName) {
                            1
                        } else {
                            baseWithoutExt.substring(baseName.length + 1).toIntOrNull() ?: 1
                        }
                        if (index > maxIndex) {
                            maxIndex = index
                            val id = cursor.getString(idCol)
                            lastUri = DocumentsContract.buildDocumentUriUsingTree(folderUri, id)
                        }
                    }
                }
            }
        } catch (ex: Exception) {
            ex.printStackTrace()
        }
        return lastUri
    }
}
