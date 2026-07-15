package com.scanmate.scanmate

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Keystore-encrypted store shared between MainActivity (writer, fed from
 * Flutter) and CardAutofillService (reader). Holds a JSON array of
 * { title, name, number, expiryMonth, expiryYear } — never the CVV.
 */
object AutofillCardStore {
    private const val PREFS_FILE = "smartscan_autofill_store"
    private const val KEY_CARDS = "cards_json"

    private fun prefs(context: Context): SharedPreferences? = try {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context,
            PREFS_FILE,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    } catch (_: Exception) {
        null
    }

    fun write(context: Context, json: String) {
        prefs(context)?.edit()?.putString(KEY_CARDS, json)?.apply()
    }

    fun read(context: Context): String =
        prefs(context)?.getString(KEY_CARDS, "[]") ?: "[]"
}
