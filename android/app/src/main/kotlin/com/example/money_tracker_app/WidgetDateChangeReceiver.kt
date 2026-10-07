package com.example.money_tracker_app

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

class WidgetDateChangeReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == Intent.ACTION_DATE_CHANGED || action == Intent.ACTION_TIMEZONE_CHANGED) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val prefs = WidgetRenderUtils.getPrefs(context)

            // Cập nhật MoneyTrackerWidgetProvider
            val balanceIds = appWidgetManager.getAppWidgetIds(
                ComponentName(context, MoneyTrackerWidgetProvider::class.java)
            )
            if (balanceIds.isNotEmpty()) {
                MoneyTrackerWidgetProvider().onUpdate(context, appWidgetManager, balanceIds, prefs)
            }

            // Cập nhật OverviewWidgetProvider
            val overviewIds = appWidgetManager.getAppWidgetIds(
                ComponentName(context, OverviewWidgetProvider::class.java)
            )
            if (overviewIds.isNotEmpty()) {
                OverviewWidgetProvider().onUpdate(context, appWidgetManager, overviewIds, prefs)
            }
        }
    }
}
