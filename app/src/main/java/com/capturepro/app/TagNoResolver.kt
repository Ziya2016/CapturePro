package com.capturepro.app

import androidx.documentfile.provider.DocumentFile

/**
 * Determines the next available filename for a given Tag No inside a DocumentFile folder.
 *
 * Convention:
 *   First capture  → "ABC123.jpg"
 *   Second capture → "ABC123_2.jpg"
 *   Third capture  → "ABC123_3.jpg"  … and so on.
 */
object TagNoResolver {

    /**
     * Scans [folder] for existing files whose name starts with [tagNo] and
     * returns the next available filename (with .jpg extension).
     */
    fun resolveFileName(folder: DocumentFile, tagNo: String): String {
        val baseName = sanitize(tagNo)

        // Collect all existing jpg names inside the folder
        val existing: Set<String> = folder.listFiles()
            .mapNotNull { it.name?.lowercase() }
            .filter { it.endsWith(".jpg") }
            .toHashSet()

        // Try base name first
        if ("${baseName.lowercase()}.jpg" !in existing) {
            return "$baseName.jpg"
        }

        // Increment suffix until a free slot is found
        var index = 2
        while ("${baseName.lowercase()}_$index.jpg" in existing) {
            index++
        }
        return "${baseName}_$index.jpg"
    }

    /** Strip filesystem-unsafe characters from the tag string. */
    fun sanitize(name: String): String =
        name.trim().replace(Regex("""[/\\:*?"<>|]"""), "_")

    /**
     * Counts the number of existing files matching the tag prefix inside [folder].
     */
    fun getCountForTag(folder: DocumentFile, tagNo: String): Int {
        val baseName = sanitize(tagNo).lowercase()
        if (baseName.isEmpty()) return 0
        return try {
            val files = folder.listFiles()
            files.count { file ->
                val name = file.name?.lowercase() ?: ""
                if (!name.endsWith(".jpg") && !name.endsWith(".jpeg")) return@count false
                val baseWithoutExt = name.substringBeforeLast(".")
                baseWithoutExt == baseName || (baseWithoutExt.startsWith("${baseName}_") &&
                        baseWithoutExt.substring(baseName.length + 1).all { it.isDigit() })
            }
        } catch (ex: Exception) {
            0
        }
    }

    /**
     * Finds the last saved image matching the tag prefix inside [folder] (resolving the highest suffix index).
     */
    fun getLastImageForTag(folder: DocumentFile, tagNo: String): DocumentFile? {
        val baseName = sanitize(tagNo).lowercase()
        if (baseName.isEmpty()) return null
        return try {
            val files = folder.listFiles()
            val matchingFiles = files.filter { file ->
                val name = file.name?.lowercase() ?: ""
                if (!name.endsWith(".jpg") && !name.endsWith(".jpeg")) return@filter false
                val baseWithoutExt = name.substringBeforeLast(".")
                baseWithoutExt == baseName || (baseWithoutExt.startsWith("${baseName}_") &&
                        baseWithoutExt.substring(baseName.length + 1).all { it.isDigit() })
            }
            if (matchingFiles.isEmpty()) return null
            matchingFiles.maxByOrNull { file ->
                val nameWithoutExt = (file.name ?: "").substringBeforeLast(".").lowercase()
                if (nameWithoutExt == baseName) {
                    1
                } else {
                    val suffix = nameWithoutExt.substring(baseName.length + 1)
                    suffix.toIntOrNull() ?: 1
                }
            }
        } catch (ex: Exception) {
            null
        }
    }
}
