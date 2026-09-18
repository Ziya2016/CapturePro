package com.capturepro.photo

import android.content.Context
import android.content.SharedPreferences
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Manages user accounts, authentication, registration, and expiry.
 * Default user expiry is 31-12-2027.
 * Admin account is permanent with no expiry and full administrative rights.
 */
object UserManager {

    private const val PREFS_NAME = "capture_pro_users"
    private const val KEY_TEST_USER_EXPIRY = "test_user_expiry"
    private const val KEY_CUSTOM_USERS = "custom_users_data"

    // Default expiry for users (31 Dec 2027)
    const val DEFAULT_USER_EXPIRY = "31-12-2027"

    data class User(
        val username: String,
        val displayName: String,
        val isAdmin: Boolean
    )

    data class UserAccount(
        val username: String,
        val password: String,
        val expiryDate: String?, // null means No Expiry (like Admin)
        val isAdmin: Boolean
    )

    sealed class LoginResult {
        data class Success(val user: User) : LoginResult()
        object InvalidCredentials : LoginResult()
        data class Expired(val username: String) : LoginResult()
    }

    sealed class RegisterResult {
        object Success : RegisterResult()
        object EmptyFields : RegisterResult()
        object UserAlreadyExists : RegisterResult()
    }

    // ── Get all user accounts ──────────────────────────────────────────────────

    fun getAllUserAccounts(context: Context): List<UserAccount> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val testExpiry = prefs.getString(KEY_TEST_USER_EXPIRY, DEFAULT_USER_EXPIRY) ?: DEFAULT_USER_EXPIRY

        val list = mutableListOf(
            UserAccount("Admin", "Adminziya@2016", null, isAdmin = true),
            UserAccount("Test User", "Test@123", testExpiry, isAdmin = false)
        )

        val customStr = prefs.getString(KEY_CUSTOM_USERS, "") ?: ""
        if (customStr.isNotEmpty()) {
            customStr.split(";").forEach { entry ->
                val parts = entry.split(":::")
                if (parts.size >= 2) {
                    val uname = parts[0]
                    val pass = parts[1]
                    val exp = if (parts.size >= 3 && parts[2].isNotBlank()) parts[2] else DEFAULT_USER_EXPIRY
                    list.add(UserAccount(uname, pass, exp, isAdmin = false))
                }
            }
        }

        return list
    }

    // ── Registration ─────────────────────────────────────────────────────────

    fun registerUser(
        context: Context,
        username: String,
        password: String,
        expiryDate: String = DEFAULT_USER_EXPIRY
    ): RegisterResult {
        val cleanUser = username.trim()
        val cleanPass = password.trim()
        if (cleanUser.isEmpty() || cleanPass.isEmpty()) return RegisterResult.EmptyFields

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val allUsers = getAllUserAccounts(context)

        // Check if username already exists (case-insensitive)
        if (allUsers.any { it.username.equals(cleanUser, ignoreCase = true) }) {
            return RegisterResult.UserAlreadyExists
        }

        val customStr = prefs.getString(KEY_CUSTOM_USERS, "") ?: ""
        val existingEntries = if (customStr.isNotEmpty()) customStr.split(";") else emptyList()
        val newEntries = existingEntries + "${cleanUser}:::${cleanPass}:::${expiryDate}"
        val updatedStr = newEntries.joinToString(";")

        prefs.edit().putString(KEY_CUSTOM_USERS, updatedStr).apply()
        return RegisterResult.Success
    }

    // ── Update Expiry ─────────────────────────────────────────────────────────

    fun updateUserExpiry(context: Context, username: String, newExpiry: String): Boolean {
        if (username.equals("Admin", ignoreCase = true)) return false // Admin has no expiry

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        if (username.equals("Test User", ignoreCase = true)) {
            prefs.edit().putString(KEY_TEST_USER_EXPIRY, newExpiry).apply()
            return true
        }

        val customStr = prefs.getString(KEY_CUSTOM_USERS, "") ?: ""
        if (customStr.isEmpty()) return false

        val updatedEntries = customStr.split(";").map { entry ->
            val parts = entry.split(":::")
            if (parts.isNotEmpty() && parts[0].equals(username, ignoreCase = true)) {
                val pass = if (parts.size >= 2) parts[1] else ""
                "${parts[0]}:::${pass}:::${newExpiry}"
            } else {
                entry
            }
        }

        prefs.edit().putString(KEY_CUSTOM_USERS, updatedEntries.joinToString(";")).apply()
        return true
    }

    // ── Remove User ───────────────────────────────────────────────────────────

    fun removeUser(context: Context, username: String): Boolean {
        if (username.equals("Admin", ignoreCase = true)) return false // Admin cannot be removed

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        val customStr = prefs.getString(KEY_CUSTOM_USERS, "") ?: ""
        if (customStr.isNotEmpty()) {
            val entries = customStr.split(";")
            val filtered = entries.filterNot {
                val parts = it.split(":::")
                parts.isNotEmpty() && parts[0].equals(username, ignoreCase = true)
            }
            if (filtered.size != entries.size) {
                prefs.edit().putString(KEY_CUSTOM_USERS, filtered.joinToString(";")).apply()
                return true
            }
        }

        return false
    }

    // ── Authentication ────────────────────────────────────────────────────────

    fun authenticate(context: Context, username: String, password: String): LoginResult {
        val users = getAllUserAccounts(context)

        val match = users.firstOrNull {
            it.username.equals(username.trim(), ignoreCase = true) && it.password == password.trim()
        } ?: return LoginResult.InvalidCredentials

        val expiryStr = match.expiryDate
        if (expiryStr != null && isExpired(expiryStr)) {
            return LoginResult.Expired(match.username)
        }

        return LoginResult.Success(User(match.username, match.username, match.isAdmin))
    }

    fun isExpired(expiryDateStr: String): Boolean {
        return try {
            val sdf = SimpleDateFormat("dd-MM-yyyy", Locale.US)
            val expiry = sdf.parse(expiryDateStr) ?: return false
            val today = Calendar.getInstance().time
            today.after(expiry)
        } catch (e: Exception) {
            false
        }
    }

    // ── Legacy helper ─────────────────────────────────────────────────────────

    fun getTestUserExpiry(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString(KEY_TEST_USER_EXPIRY, DEFAULT_USER_EXPIRY) ?: DEFAULT_USER_EXPIRY
    }

    fun setTestUserExpiry(context: Context, expiryDate: String) {
        updateUserExpiry(context, "Test User", expiryDate)
    }

    fun formatExpiryForDisplay(expiryStr: String): String {
        return try {
            val sdf = SimpleDateFormat("dd-MM-yyyy", Locale.US)
            val date = sdf.parse(expiryStr) ?: return expiryStr
            val displaySdf = SimpleDateFormat("dd MMM yyyy", Locale.US)
            displaySdf.format(date)
        } catch (e: Exception) {
            expiryStr
        }
    }
}
