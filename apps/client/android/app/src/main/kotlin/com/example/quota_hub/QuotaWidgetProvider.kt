package com.example.quota_hub

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONObject

class QuotaWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, widgetIds: IntArray) {
        widgetIds.forEach { update(context, manager, it) }
    }

    companion object {
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, QuotaWidgetProvider::class.java)
            manager.getAppWidgetIds(component).forEach { update(context, manager, it) }
        }

        private fun update(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val prefs = context.getSharedPreferences("quota_widget", Context.MODE_PRIVATE)
            val snapshot = prefs.getString("snapshot", null)
            val card = readCard(snapshot, prefs.getBoolean("hideMoney", false))
            val views = RemoteViews(context.packageName, R.layout.quota_widget)
            views.setTextViewText(R.id.quota_widget_title, card.title)
            views.setTextViewText(R.id.quota_widget_value, card.value)
            views.setTextViewText(R.id.quota_widget_status, card.status)
            val intent = Intent(context, MainActivity::class.java).apply {
                putExtra("accountId", card.accountId)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val pending = PendingIntent.getActivity(
                context, widgetId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.quota_widget_root, pending)
            manager.updateAppWidget(widgetId, views)
        }

        private fun readCard(source: String?, hideMoney: Boolean): Card {
            if (source == null) return Card("Quota Hub", "打开应用添加 余额账户", "尚未取得余额", "")
            return try {
                val json = JSONObject(source)
                if (json.getInt("schemaVersion") != 1) throw IllegalArgumentException("protocol")
                val accounts = json.getJSONArray("accounts")
                if (accounts.length() == 0) return Card("Quota Hub", "添加 余额账户", "尚未连接账户", "")
                val account = accounts.getJSONObject(0)
                val metrics = account.getJSONArray("metrics")
                val metric = (0 until metrics.length()).map { metrics.getJSONObject(it) }
                    .firstOrNull { it.optString("key") in setOf("available", "available_credit") }
                    ?: throw IllegalArgumentException("missing balance")
                val state = metric.getString("state")
                val amountLabel = if (metric.optString("key") == "available_credit") "可用额度" else "可用余额"
                val sourceLabel = if (account.getString("id").endsWith("_demo") || account.getString("id") == "deepseek_cached") "演示数据" else account.optString("label", "余额账户")
                val value = when (state) {
                    "ok", "stale" -> if (hideMoney && metric.getString("kind") == "money") {
                        "•••• ${metric.getString("unit")}"
                    } else {
                        "${metric.getString("value")} ${metric.getString("unit")}"
                    }
                    "unknown" -> "未知"
                    "error" -> "暂不可用"
                    else -> throw IllegalArgumentException("unknown state")
                }
                val status = when (state) {
                    "ok" -> "$sourceLabel · $amountLabel"
                    "stale" -> "$sourceLabel · 缓存已过期"
                    "unknown" -> "$sourceLabel · 未知"
                    else -> "$sourceLabel · 查询失败"
                }
                Card(account.optString("label", "API 余额"), value, status, account.getString("id"))
            } catch (_: Exception) {
                Card("Quota Hub", "数据不可用", "打开应用重新加载", "")
            }
        }
    }
}

private data class Card(val title: String, val value: String, val status: String, val accountId: String)
