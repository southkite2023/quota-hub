package com.example.quota_hub

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.widget.RemoteViews
import org.json.JSONObject

class QuotaWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, widgetIds: IntArray) {
        widgetIds.forEach { update(context, manager, it) }
    }
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, widgetId: Int, options: Bundle) {
        update(context, manager, widgetId)
    }
    companion object {
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, QuotaWidgetProvider::class.java))
            ids.forEach { update(context, manager, it) }
            if (Build.VERSION.SDK_INT < 31) manager.notifyAppWidgetViewDataChanged(ids, R.id.quota_widget_list)
        }
        private fun update(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val rows = WidgetBalances.read(context)
            val views = RemoteViews(context.packageName, R.layout.quota_widget)
            views.setTextViewText(R.id.quota_widget_title, "账户余额 · ${rows.size} 项")
            views.setTextViewText(R.id.quota_widget_empty, "打开应用添加账户并勾选\n要显示的小组件余额")
            views.setEmptyView(R.id.quota_widget_list, R.id.quota_widget_empty)
            val open = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val header = PendingIntent.getActivity(context, widgetId, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.quota_widget_title, header)
            views.setOnClickPendingIntent(R.id.quota_widget_empty, header)
            val mutable = if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0
            val template = PendingIntent.getActivity(context, widgetId + 100000, open, PendingIntent.FLAG_UPDATE_CURRENT or mutable)
            views.setPendingIntentTemplate(R.id.quota_widget_list, template)
            if (Build.VERSION.SDK_INT >= 31) {
                val collection = RemoteViews.RemoteCollectionItems.Builder().setHasStableIds(false).setViewTypeCount(1)
                rows.forEachIndexed { index, row -> collection.addItem(index.toLong(), WidgetBalances.view(context, row)) }
                views.setRemoteAdapter(R.id.quota_widget_list, collection.build())
            } else {
                val adapter = Intent(context, QuotaWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                    data = Uri.parse("quota-hub://widget/$widgetId")
                }
                views.setRemoteAdapter(R.id.quota_widget_list, adapter)
            }
            manager.updateAppWidget(widgetId, views)
        }
    }
}

data class WidgetBalance(val id: String, val title: String, val value: String, val status: String)
object WidgetBalances {
    fun read(context: Context): List<WidgetBalance> {
        val prefs = context.getSharedPreferences("quota_widget", Context.MODE_PRIVATE)
        val source = prefs.getString("widget_snapshot", null) ?: prefs.getString("snapshot", null) ?: return emptyList()
        return parse(source, prefs.getBoolean("hideMoney", false))
    }
    fun parse(source: String, hideMoney: Boolean): List<WidgetBalance> = try {
        val json = JSONObject(source)
        require(json.getInt("schemaVersion") == 1)
        val accounts = json.getJSONArray("accounts")
        (0 until accounts.length()).map { index ->
            val account = accounts.getJSONObject(index)
            val metrics = account.getJSONArray("metrics")
            val metric = (0 until metrics.length()).map { metrics.getJSONObject(it) }
                .firstOrNull { it.optString("key") in setOf("available", "available_credit") }
            val state = metric?.optString("state") ?: "unknown"
            val value = when (state) {
                "ok", "stale" -> if (hideMoney) "•••• ${metric!!.optString("unit")}" else "${metric!!.getString("value")} ${metric.getString("unit")}"
                "error" -> "暂不可用"
                else -> "未知"
            }
            val status = when (state) {
                "stale" -> "缓存已过期"
                "error" -> "查询失败"
                "unknown" -> "尚无余额"
                else -> if (metric?.optString("key") == "available_credit") "可用额度" else "可用余额"
            }
            WidgetBalance(account.getString("id"), account.optString("label", "余额账户"), value, status)
        }
    } catch (_: Exception) { listOf(WidgetBalance("", "数据不可用", "请打开应用刷新", "读取失败")) }
    fun view(context: Context, row: WidgetBalance) = RemoteViews(context.packageName, R.layout.quota_widget_row).apply {
        setTextViewText(R.id.quota_row_title, row.title)
        setTextViewText(R.id.quota_row_value, row.value)
        setTextViewText(R.id.quota_row_status, row.status)
        setOnClickFillInIntent(R.id.quota_row_root, Intent().putExtra("accountId", row.id))
    }
}
