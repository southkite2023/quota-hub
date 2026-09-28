package com.example.quota_hub

import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService

/** Collection fallback for Android versions before RemoteCollectionItems (API 31). */
class QuotaWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = object : RemoteViewsFactory {
        private var rows = emptyList<WidgetBalance>()
        override fun onCreate() { onDataSetChanged() }
        override fun onDataSetChanged() { rows = WidgetBalances.read(applicationContext) }
        override fun onDestroy() { rows = emptyList() }
        override fun getCount() = rows.size
        override fun getViewAt(position: Int): RemoteViews? = rows.getOrNull(position)?.let { WidgetBalances.view(applicationContext, it) }
        override fun getLoadingView(): RemoteViews? = null
        override fun getViewTypeCount() = 1
        override fun getItemId(position: Int) = position.toLong()
        override fun hasStableIds() = false
    }
}
