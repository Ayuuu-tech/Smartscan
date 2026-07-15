package com.scanmate.scanmate

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import android.view.autofill.AutofillManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) — required by local_auth's
// BiometricPrompt integration.
class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Card vault: block screenshots and hide content in the app switcher.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smartscan/autofill")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Flutter mirrors payment cards (without CVV) here so the
                    // autofill service can serve them to other apps.
                    "syncCards" -> {
                        val json = call.argument<String>("cards") ?: "[]"
                        AutofillCardStore.write(applicationContext, json)
                        result.success(true)
                    }
                    "isAutofillEnabled" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val afm = getSystemService(AutofillManager::class.java)
                            result.success(afm?.hasEnabledAutofillServices() == true)
                        } else {
                            result.success(false)
                        }
                    }
                    "requestEnableAutofill" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            try {
                                val intent =
                                    Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE)
                                intent.data = Uri.parse("package:$packageName")
                                startActivity(intent)
                            } catch (_: Exception) {
                                // Some OEM builds don't expose this screen.
                            }
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
