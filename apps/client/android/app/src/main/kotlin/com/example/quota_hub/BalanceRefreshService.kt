package com.example.quota_hub

import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.*
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/** One process-wide lease prevents UI and headless engines refreshing simultaneously. */
object RefreshRuntime {
    var visible = false
    var running = false
    private var owner: String? = null
    fun acquire(id: String): Boolean { if (owner != null) return false; owner = id; return true }
    fun release(id: String) { if (owner == id) owner = null }
    fun config(context: Context): JSONObject? = DeepSeekKeyStore(context, "accounts").read()?.let { JSONObject(it) }
    fun allowed(context: Context): Boolean = try {
        val data = config(context)
        data != null && data.optBoolean("backgroundRefresh", false) && data.optInt("refreshMinutes", 5) > 0 &&
            data.getJSONArray("accounts").length() > 0
    } catch (_: Exception) { false }
    fun notificationAllowed(context: Context) = Build.VERSION.SDK_INT < 33 ||
        context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    fun start(context: Context) {
        if (!allowed(context)) { context.stopService(Intent(context, BalanceRefreshService::class.java)); return }
        val prefs = context.getSharedPreferences("refresh_status", Context.MODE_PRIVATE)
        if (prefs.getBoolean("stopped", false)) return
        if (!notificationAllowed(context)) { prefs.edit().putString("message", "请允许通知后开启后台刷新").apply(); return }
        try {
            val intent = Intent(context, BalanceRefreshService::class.java)
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
        } catch (_: Exception) { prefs.edit().putString("message", "系统未允许后台刷新，请回到应用重新开启").apply() }
    }
}

class BalanceRefreshService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var ready = false
    private var working = false
    private var revision: String? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val tick = Runnable { refresh() }
    private val watchdog = Runnable { stopWithReason("后台查询未能完成，请回到应用重新开启") }
    private val prefs get() = getSharedPreferences("refresh_status", MODE_PRIVATE)

    override fun onBind(intent: Intent?) = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "stop") { stopWithReason("后台刷新已停止，可在设置中重新开启"); return START_NOT_STICKY }
        if (!RefreshRuntime.allowed(this)) { stopSelf(); return START_NOT_STICKY }
        try {
            val notification = notification()
            if (Build.VERSION.SDK_INT >= 29) startForeground(430, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            else startForeground(430, notification)
            RefreshRuntime.running = true
            prefs.edit().putString("message", "后台刷新已开启").apply()
            if (engine == null) startEngine()
            else if (ready && !working) schedule()
        } catch (_: Exception) { stopWithReason("后台刷新启动失败，请回到应用重试") }
        return START_NOT_STICKY
    }
    private fun notification(): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
            NotificationChannel("balance_refresh", "余额自动刷新", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getService(this, 1, Intent(this, BalanceRefreshService::class.java).setAction("stop"), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "balance_refresh") else Notification.Builder(this)
        val minutes = RefreshRuntime.config(this)?.optInt("refreshMinutes", 5) ?: 5
        return builder.setSmallIcon(android.R.drawable.stat_notify_sync).setContentTitle("Quota Hub 自动刷新")
            .setContentText("每 $minutes 分钟尝试更新余额 · 点击打开应用")
            .setOngoing(true).setContentIntent(open).addAction(android.R.drawable.ic_media_pause, "停止后台刷新", stop).build()
    }
    private fun startEngine() {
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)
        val newEngine = FlutterEngine(applicationContext)
        engine = newEngine
        channel = MethodChannel(newEngine.dartExecutor.binaryMessenger, "quota_hub/background")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "ready" -> { ready = true; handler.removeCallbacks(watchdog); schedule(); result.success(null) }
                else -> result.notImplemented()
            }
        }
        handler.postDelayed(watchdog, 90000)
        newEngine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "balanceServiceMain"))
    }
    private fun schedule() {
        handler.removeCallbacks(tick)
        if (!RefreshRuntime.allowed(this)) { stopSelf(); return }
        val minutes = RefreshRuntime.config(this)?.optInt("refreshMinutes", 5) ?: 5
        val last = prefs.getLong("lastAttempt", System.currentTimeMillis())
        val delay = (last + minutes * 60000L - System.currentTimeMillis()).coerceAtLeast(1000L)
        handler.postDelayed(tick, delay)
    }
    private fun refresh() {
        if (!RefreshRuntime.allowed(this)) { stopSelf(); return }
        if (RefreshRuntime.visible || !RefreshRuntime.acquire("service")) { handler.postDelayed(tick, 5000); return }
        try {
            working = true
            revision = DeepSeekKeyStore(this, "accounts").read()
            val cache = getSharedPreferences("quota_widget", MODE_PRIVATE).getString("snapshot", null)
            wakeLock = (getSystemService(POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "QuotaHub:refresh").apply { acquire(90000) }
            handler.postDelayed(watchdog, 90000)
            channel!!.invokeMethod("refresh", mapOf("configuration" to revision, "snapshot" to cache), object : MethodChannel.Result {
                override fun success(value: Any?) {
                    // Discard data from removed accounts or changed credentials/settings.
                    try { if (revision == DeepSeekKeyStore(this@BalanceRefreshService, "accounts").read() && value is String && value.length <= 150000) {
                        val data = JSONObject(value)
                        val snapshot = data.getString("snapshot")
                        val widgetSnapshot = data.getString("widgetSnapshot")
                        require(snapshot.length <= 65536 && widgetSnapshot.length <= 65536)
                        getSharedPreferences("quota_widget", MODE_PRIVATE).edit().putString("snapshot", snapshot)
                            .putString("widget_snapshot", widgetSnapshot).apply()
                        QuotaWidgetProvider.refreshAll(this@BalanceRefreshService)
                    }
                    } catch (_: Exception) { /* Never expose credential or response contents. */ }
                    finally { finished() }
                }
                override fun error(code: String, message: String?, details: Any?) { finished() }
                override fun notImplemented() { stopWithReason("后台刷新不可用，请重新打开应用") }
            })
        } catch (_: Exception) { finished() }
    }
    private fun finished() {
        handler.removeCallbacks(watchdog)
        if (wakeLock?.isHeld == true) wakeLock?.release()
        wakeLock = null
        working = false
        revision = null
        RefreshRuntime.release("service")
        prefs.edit().putLong("lastAttempt", System.currentTimeMillis()).apply()
        if (engine != null) schedule()
    }
    private fun stopWithReason(message: String) {
        prefs.edit().putBoolean("stopped", true).putString("message", message).apply()
        stopSelf()
    }
    override fun onTimeout(startId: Int, fgsType: Int) { stopWithReason("系统后台运行时限已到，请打开应用重新开启") }
    override fun onDestroy() {
        RefreshRuntime.running = false
        handler.removeCallbacksAndMessages(null)
        if (wakeLock?.isHeld == true) wakeLock?.release()
        RefreshRuntime.release("service")
        engine?.destroy(); engine = null
        super.onDestroy()
    }
}
