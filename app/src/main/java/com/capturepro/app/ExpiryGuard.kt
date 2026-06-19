package com.capturepro.app

import java.time.LocalDate

/**
 * Guards the app against usage past the expiry date.
 * Expiry: 31 December 2026
 */
object ExpiryGuard {

    private val EXPIRY_DATE: LocalDate = LocalDate.of(2026, 12, 31)

    /** Returns true if today is AFTER 31-Dec-2026 */
    fun isExpired(): Boolean = LocalDate.now().isAfter(EXPIRY_DATE)

    /** Human-readable expiry date for display */
    val expiryDisplayDate: String = "31 December 2026"
}
