package com.example.money_tracker_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class SmallWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val widgetId = intent.getIntExtra(
            WidgetRenderUtils.EXTRA_WIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        )
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return

        when (intent.action) {
            WidgetRenderUtils.ACTION_TOGGLE_PRIVACY -> {
                WidgetRenderUtils.togglePrivacy(context, widgetId)
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val prefs = WidgetRenderUtils.getPrefs(context)
                updateSingleWidget(context, appWidgetManager, widgetId, prefs)
            }
            WidgetRenderUtils.ACTION_AUTO_HIDE -> {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val prefs = WidgetRenderUtils.getPrefs(context)
                updateSingleWidget(context, appWidgetManager, widgetId, prefs)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            updateSingleWidget(context, appWidgetManager, widgetId, widgetData)
        }
    }

    private fun updateSingleWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_small).apply {
            val isHidden = WidgetRenderUtils.isPrivacyHidden(context, widgetId)
            val snapshotDate = widgetData.getString("widget_snapshot_date", "")
            val isToday = WidgetRenderUtils.isDateCurrent(snapshotDate)

            val chosenWalletId = widgetData.getString("widget_${widgetId}_wallet_id", "") ?: ""
            var displayTitle = "Mono"
            var displayBalance = widgetData.getString("widget_total_balance", "0đ") ?: "0đ"

            if (chosenWalletId.isNotEmpty()) {
                val walletsJson = widgetData.getString("widget_wallets_json", "[]") ?: "[]"
                try {
                    val array = JSONArray(walletsJson)
                    for (i in 0 until array.length()) {
                        val obj = array.getJSONObject(i)
                        if (obj.optString("id") == chosenWalletId) {
                            displayTitle = obj.optString("name", "Ví")
                            displayBalance = obj.optString("balance", "0đ")
                            break
                        }
                    }
                } catch (_: Exception) {}
            }

            setTextViewText(R.id.widget_title, displayTitle)
            setTextViewText(R.id.widget_total_balance, WidgetRenderUtils.maskIfHidden(displayBalance, isHidden))

            val rawTodayExpense = if (isToday) {
                widgetData.getString("widget_today_expense", "0đ") ?: "0đ"
            } else {
                "0đ"
            }
            val safeSpend = widgetData.getString("widget_safe_daily_spend", "") ?: ""
            val subText = if (safeSpend.isNotEmpty() && safeSpend != "Không giới hạn" && safeSpend != "Đã vượt hạn mức") {
                "Hôm nay còn " + WidgetRenderUtils.maskIfHidden(safeSpend, isHidden)
            } else {
                "Chi hôm nay: " + WidgetRenderUtils.maskIfHidden(rawTodayExpense, isHidden)
            }
            setTextViewText(R.id.widget_today_label, subText)

            // Icon con mắt vector
            setImageViewResource(
                R.id.widget_btn_eye,
                if (isHidden) R.drawable.ic_eye_hidden else R.drawable.ic_eye_visible
            )
            val eyePendingIntent = WidgetRenderUtils.getTogglePrivacyPendingIntent(
                context,
                SmallWidgetProvider::class.java,
                widgetId
            )
            setOnClickPendingIntent(R.id.widget_btn_eye, eyePendingIntent)

            // Nút Thêm Chi
            val expensePendingIntent = WidgetRenderUtils.getDeepLinkPendingIntent(
                context,
                "moneytracker://add?type=expense",
                widgetId * 10 + 1
            )
            setOnClickPendingIntent(R.id.widget_btn_expense, expensePendingIntent)

            // Nút Thêm Thu
            val incomePendingIntent = WidgetRenderUtils.getDeepLinkPendingIntent(
                context,
                "moneytracker://add?type=income",
                widgetId * 10 + 2
            )
            setOnClickPendingIntent(R.id.widget_btn_income, incomePendingIntent)

            // Chạm nền mở Ví
            val walletDeepLink = if (chosenWalletId.isNotEmpty()) {
                "moneytracker://wallet?id=$chosenWalletId"
            } else {
                "moneytracker://wallet"
            }
            val openWalletPendingIntent = WidgetRenderUtils.getDeepLinkPendingIntent(
                context,
                walletDeepLink,
                widgetId * 10 + 3
            )
            setOnClickPendingIntent(R.id.widget_container, openWalletPendingIntent)
        }

        appWidgetManager.updateAppWidget(widgetId, views)
    }
}
