package com.capturepro.photo

import android.content.Intent
import android.os.Bundle
import android.text.InputType
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.*
import androidx.appcompat.app.AppCompatActivity

class LoginActivity : AppCompatActivity() {

    private lateinit var etUsername: EditText
    private lateinit var etPassword: EditText
    private lateinit var tvTogglePassword: TextView
    private lateinit var cbRememberMe: CheckBox
    private lateinit var btnLogin: Button
    private lateinit var tvLoginError: TextView

    private var passwordVisible = false

    companion object {
        const val PREFS_LOGIN = "login_prefs"
        const val KEY_REMEMBERED_USER = "remembered_user"
        const val KEY_IS_REMEMBERED = "is_remembered"
        const val KEY_LOGGED_IN_USER = "logged_in_user"
        const val KEY_IS_ADMIN = "is_admin"

        fun logout(context: android.content.Context) {
            val prefs = context.getSharedPreferences(PREFS_LOGIN, MODE_PRIVATE)
            prefs.edit()
                .putBoolean(KEY_IS_REMEMBERED, false)
                .remove(KEY_REMEMBERED_USER)
                .remove(KEY_LOGGED_IN_USER)
                .apply()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ── If already logged in (remembered), go straight to main ────────────
        val loginPrefs = getSharedPreferences(PREFS_LOGIN, MODE_PRIVATE)
        if (loginPrefs.getBoolean(KEY_IS_REMEMBERED, false)) {
            val savedUser = loginPrefs.getString(KEY_REMEMBERED_USER, null)
            if (savedUser != null) {
                launchMain(savedUser, savedUser.equals("Admin", ignoreCase = true))
                return
            }
        }

        setContentView(R.layout.activity_login)

        etUsername = findViewById(R.id.etUsername)
        etPassword = findViewById(R.id.etPassword)
        tvTogglePassword = findViewById(R.id.tvTogglePassword)
        cbRememberMe = findViewById(R.id.cbRememberMe)
        btnLogin = findViewById(R.id.btnLogin)
        tvLoginError = findViewById(R.id.tvLoginError)

        // ── Pre-fill username if previously entered ────────────────────────────
        val savedUsername = loginPrefs.getString(KEY_REMEMBERED_USER, null)
        if (savedUsername != null) {
            etUsername.setText(savedUsername)
            cbRememberMe.isChecked = true
            etPassword.requestFocus()
        }

        // ── Password visibility toggle ─────────────────────────────────────────
        tvTogglePassword.setOnClickListener {
            passwordVisible = !passwordVisible
            etPassword.inputType = if (passwordVisible) {
                InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD
            } else {
                InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
            }
            etPassword.setSelection(etPassword.text.length)
            tvTogglePassword.text = if (passwordVisible) "🙈" else "👁"
        }

        // ── Allow IME Done on password to trigger login ───────────────────────
        etPassword.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_DONE) {
                attemptLogin()
                true
            } else false
        }

        // ── Login button ──────────────────────────────────────────────────────
        btnLogin.setOnClickListener { attemptLogin() }

        // ── Create Account button ──────────────────────────────────────────────
        val btnCreateAccount = findViewById<Button>(R.id.btnCreateAccount)
        btnCreateAccount.setOnClickListener { showCreateAccountDialog() }
    }

    private fun showCreateAccountDialog() {
        val dialogView = layoutInflater.inflate(R.layout.dialog_create_account, null)
        val etNewUser    = dialogView.findViewById<EditText>(R.id.etNewUsername)
        val etNewPass    = dialogView.findViewById<EditText>(R.id.etNewPassword)
        val btnCancel    = dialogView.findViewById<Button>(R.id.btnCancelCreate)
        val btnSubmit    = dialogView.findViewById<Button>(R.id.btnSubmitCreate)

        val dialog = androidx.appcompat.app.AlertDialog.Builder(this)
            .setView(dialogView)
            .setCancelable(true)
            .create()

        dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)

        btnCancel.setOnClickListener { dialog.dismiss() }

        btnSubmit.setOnClickListener {
            val newUsername = etNewUser.text.toString().trim()
            val newPassword = etNewPass.text.toString().trim()

            when (UserManager.registerUser(this, newUsername, newPassword)) {
                is UserManager.RegisterResult.EmptyFields -> {
                    Toast.makeText(this, "Username and password cannot be empty", Toast.LENGTH_SHORT).show()
                }
                is UserManager.RegisterResult.UserAlreadyExists -> {
                    Toast.makeText(this, "Username '$newUsername' already exists", Toast.LENGTH_LONG).show()
                }
                is UserManager.RegisterResult.Success -> {
                    dialog.dismiss()
                    Toast.makeText(this, "✅ Account created successfully!", Toast.LENGTH_SHORT).show()
                    etUsername.setText(newUsername)
                    etPassword.setText(newPassword)
                    attemptLogin()
                }
            }
        }

        dialog.show()
    }

    private fun attemptLogin() {
        val username = etUsername.text.toString().trim()
        val password = etPassword.text.toString().trim()

        if (username.isEmpty()) {
            showError("Please enter your username.")
            return
        }
        if (password.isEmpty()) {
            showError("Please enter your password.")
            return
        }

        btnLogin.isEnabled = false
        btnLogin.text = "Signing in…"
        tvLoginError.visibility = View.GONE

        when (val result = UserManager.authenticate(this, username, password)) {
            is UserManager.LoginResult.InvalidCredentials -> {
                showError("Invalid username or password.")
                resetLoginButton()
            }

            is UserManager.LoginResult.Expired -> {
                showError("Account for '${result.username}' has expired.\nPlease contact Admin.")
                resetLoginButton()
            }

            is UserManager.LoginResult.Success -> {
                val loginPrefs = getSharedPreferences(PREFS_LOGIN, MODE_PRIVATE)
                val editor = loginPrefs.edit()
                if (cbRememberMe.isChecked) {
                    editor.putBoolean(KEY_IS_REMEMBERED, true)
                    editor.putString(KEY_REMEMBERED_USER, result.user.username)
                } else {
                    editor.putBoolean(KEY_IS_REMEMBERED, false)
                    editor.remove(KEY_REMEMBERED_USER)
                }
                editor.putString(KEY_LOGGED_IN_USER, result.user.username)
                editor.putBoolean(KEY_IS_ADMIN, result.user.isAdmin)
                editor.apply()

                launchMain(result.user.username, result.user.isAdmin)
            }
        }
    }

    private fun launchMain(username: String, isAdmin: Boolean) {
        val intent = Intent(this, MainActivity::class.java).apply {
            putExtra("logged_in_user", username)
            putExtra("is_admin", isAdmin)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        startActivity(intent)
        finish()
    }

    private fun showError(msg: String) {
        tvLoginError.text = msg
        tvLoginError.visibility = View.VISIBLE
        resetLoginButton()
    }

    private fun resetLoginButton() {
        btnLogin.isEnabled = true
        btnLogin.text = "SIGN IN"
    }

}
