package com.example.quota_hub

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var widgetChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val keyStore = DeepSeekKeyStore(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quota_hub/deepseek")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "readKey" -> result.success(keyStore.read())
                        "saveKey", "removeKey" -> {
                            if (call.method == "saveKey") keyStore.save(call.arguments as String)
                            else keyStore.remove()
                            getSharedPreferences("quota_widget", MODE_PRIVATE).edit().remove("snapshot").commit()
                            QuotaWidgetProvider.refreshAll(this)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    result.error("KEY_STORAGE_FAILED", "Unable to access device credential storage", null)
                }
            }
        widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quota_hub/widget")
        widgetChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "saveSnapshot" -> {
                    val snapshot = call.argument<String>("snapshot")
                    if (snapshot == null || snapshot.length > 65536 || !validSnapshot(snapshot)) {
                        result.error("INVALID_SNAPSHOT", "Expected a version 1 demo snapshot", null)
                    } else {
                        getSharedPreferences("quota_widget", MODE_PRIVATE).edit()
                            .putString("snapshot", snapshot)
                            .putBoolean("hideMoney", call.argument<Boolean>("hideMoney") ?: false)
                            .apply()
                        QuotaWidgetProvider.refreshAll(this)
                        result.success(null)
                    }
                }
                "getWidgetAccount" -> result.success(intent?.getStringExtra("accountId"))
                "getHideMoney" -> result.success(
                    getSharedPreferences("quota_widget", MODE_PRIVATE).getBoolean("hideMoney", false)
                )
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.getStringExtra("accountId")?.let { widgetChannel?.invokeMethod("openAccount", it) }
    }

    private fun validSnapshot(source: String): Boolean = try {
        val json = JSONObject(source)
        val accounts = json.getJSONArray("accounts")
        json.getInt("schemaVersion") == 1 && accounts.length() > 0 &&
            json.keys().asSequence().all { it in setOf("schemaVersion", "generatedAt", "accounts") } &&
            (0 until accounts.length()).all { index ->
                val account = accounts.getJSONObject(index)
                account.has("id") && account.has("provider") && account.has("metrics") &&
                    account.getJSONArray("metrics").length() > 0 &&
                    account.keys().asSequence().all { it in setOf("id", "provider", "label", "lastSuccessAt", "metrics") }
            }
    } catch (_: Exception) {
        false
    }
}
