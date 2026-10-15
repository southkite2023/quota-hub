package com.example.quota_hub

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

object AppUpdater {
    @Suppress("DEPRECATION")
    fun prepare(activity: Activity, path: String, expectedHash: String): Intent {
        val file = File(path).canonicalFile
        val directory = File(activity.cacheDir, "astracct-updates").canonicalFile
        require(file.parentFile == directory && file.isFile && file.extension == "apk")
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(65536)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        require(digest.digest().joinToString("") { "%02x".format(it) } == expectedHash)
        val flags = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
        val installed = activity.packageManager.getPackageInfo(activity.packageName, flags)
        val candidate = activity.packageManager.getPackageArchiveInfo(file.path, flags) ?: error("Invalid APK")
        require(candidate.packageName == activity.packageName)
        val currentCode = if (Build.VERSION.SDK_INT >= 28) installed.longVersionCode else installed.versionCode.toLong()
        val nextCode = if (Build.VERSION.SDK_INT >= 28) candidate.longVersionCode else candidate.versionCode.toLong()
        require(nextCode > currentCode)
        val currentSignatures = if (Build.VERSION.SDK_INT >= 28) installed.signingInfo!!.apkContentsSigners else installed.signatures!!
        val newSignatures = if (Build.VERSION.SDK_INT >= 28) candidate.signingInfo!!.apkContentsSigners else candidate.signatures!!
        require(currentSignatures.map { it.toCharsString() }.toSet() == newSignatures.map { it.toCharsString() }.toSet())
        if (Build.VERSION.SDK_INT >= 26 && !activity.packageManager.canRequestPackageInstalls()) {
            return Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}"))
        }
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", file)
        return Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }

    fun register(activity: Activity, channel: MethodChannel) {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "install") { result.notImplemented(); return@setMethodCallHandler }
            // Hashing and APK parsing must not block the UI thread.
            Thread {
                try {
                    val path = call.argument<String>("path") ?: error("Missing path")
                    val hash = call.argument<String>("sha256") ?: error("Missing hash")
                    val intent = prepare(activity, path, hash)
                    activity.runOnUiThread {
                        try { activity.startActivity(intent); result.success(null) }
                        catch (_: Exception) { result.error("INSTALL_FAILED", "Unable to verify or install update", null) }
                    }
                } catch (_: Exception) {
                    activity.runOnUiThread { result.error("INSTALL_FAILED", "Invalid update request", null) }
                }
            }.start()
        }
    }
}
