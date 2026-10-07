package com.example.money_tracker_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class OverviewWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val widgetId = intent.getIntExtra(
            WidgetRenderUtils.EXTRA_WIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        )
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return

        when (intent.action) {
            WidgetRenderUtils.ACTION_TOGGLE_PRIVACY -> {
                WidgetRenderUtils.togglePrivacyWithTimeout(context, OverviewWidgetProvider::class.java, widgetId)
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
        val views = RemoteViews(context.packageName, R.layout.widget_overview).apply {
            val isHidden = WidgetRenderUtils.isPrivacyHidden(context, widgetId)
            val isLoggedIn = widgetData.getBoolean("widget_is_logged_in", true)

            // Nút mắt ẩn/hiện
            setTextViewText(R.id.widget_overview_btn_eye, if (isHidden) "🔒" else "👁")
            val eyePendingIntent = WidgetRenderUtils.getTogglePrivacyPendingIntent(
                context,
                OverviewWidgetProvider::class.java,
                widgetId
            )
            setOnClickPendingIntent(R.id.widget_overview_btn_eye, eyePendingIntent)

            // Kiểm tra cấu hình ví
            val chosenWalletId = widgetData.getString("widget_${widgetId}_wallet_id", "") ?: ""
            var balanceText = widgetData.getString("widget_total_balance", "0đ") ?: "0đ"

            if (chosenWalletId.isNotEmpty()) {
                val walletsJson = widgetData.getString("widget_wallets_json", "[]") ?: "[]"
                try {
                    val array = JSONArray(walletsJson)
                    for (i in 0 until array.length()) {
                        val obj = array.getJSONObject(i)
                        if (obj.optString("id") == chosenWalletId) {
                            balanceText = obj.optString("balance", "0đ")
                            break
                        }
                    }
                } catch (_: Exception) {}
            }

            if (!isLoggedIn) {
                setTextViewText(R.id.widget_overview_balance, "Chưa đăng nhập")
                setTextViewText(R.id.widget_overview_diff, "")
                setTextViewText(R.id.widget_overview_income, "Thu: ••••••")
                setTextViewText(R.id.widget_overview_expense, "Chi: ••••••")
            } else {
                setTextViewText(
                    R.id.widget_overview_balance,
                    WidgetRenderUtils.maskIfHidden(balanceText, isHidden)
                )

                val diffText = widgetData.getString("widget_month_difference", "0đ") ?: "0đ"
                val incomeText = widgetData.getString("widget_month_income", "0đ") ?: "0đ"
                val expenseText = widgetData.getString("widget_month_expense", "0đ") ?: "0đ"

                setTextViewText(
                    R.id.widget_overview_diff,
                    WidgetRenderUtils.maskIfHidden(diffText, isHidden)
                )
                setTextViewText(
                    R.id.widget_overview_income,
                    "Thu: " + WidgetRenderUtils.maskIfHidden(incomeText, isHidden)
                )
                setTextViewText(
                    R.id.widget_overview_expense,
                    "Chi: " + WidgetRenderUtils.maskIfHidden(expenseText, isHidden)
                )
            }

            // Giao dịch gần đây (3 giao dịch)
            val txsJson = widgetData.getString("widget_recent_transactions_json", "[]") ?: "[]"
            val txsArray = try {
                JSONArray(txsJson)
            } catch (_: Exception) {
                JSONArray()
            }

            val txRowIds = intArrayOf(R.id.widget_tx_1, R.id.widget_tx_2, R.id.widget_tx_3)
            val txTitleIds = intArrayOf(R.id.widget_tx_1_title, R.id.widget_tx_2_title, R.id.widget_tx_3_title)
            val txDateIds = intArrayOf(R.id.widget_tx_1_date, R.id.widget_tx_2_date, R.id.widget_tx_3_date)
            val txAmountIds = intArrayOf(R.id.widget_tx_1_amount, R.id.widget_tx_2_amount, R.id.widget_tx_3_amount)

            if (txsArray.length() == 0 || !isLoggedIn) {
                setViewVisibility(R.id.widget_tx_empty, View.VISIBLE)
                setViewVisibility(R.id.widget_tx_1, View.GONE)
                setViewVisibility(R.id.widget_tx_2, View.GONE)
                setViewVisibility(R.id.widget_tx_3, View.GONE)
            } else {
                setViewVisibility(R.id.widget_tx_empty, View.GONE)
                for (i in 0 until 3) {
                    if (i < txsArray.length()) {
                        val tx = txsArray.getJSONObject(i)
                        setViewVisibility(txRowIds[i], View.VISIBLE)
                        setTextViewText(txTitleIds[i], tx.optString("title", "Giao dịch"))
                        setTextViewText(txDateIds[i], tx.optString("date", ""))

                        val rawAmount = tx.optString("amount", "0đ")
                        setTextViewText(
                            txAmountIds[i],
                            WidgetRenderUtils.maskIfHidden(rawAmount, isHidden)
                        )
                    } else {
                        setViewVisibility(txRowIds[i], View.GONE)
                    }
                }
            }

            // Chạm vùng giao dịch mở màn hình Tất cả giao dịch
            val openTxsIntent = WidgetRenderUtils.getDeepLinkPendingIntent(
                context,
                "moneytracker://transactions",
                widgetId * 10 + 1
            )
            setOnClickPendingIntent(R.id.widget_tx_container, openTxsIntent)

            // Nút Thêm Chi
            val expenseIntent = WidgetRenderUtils.getDeepLinkPendingIntent(
                context,
                "moneytracker://add?type=expense",
                widgetId * 10 + 2
            )
            setOnClickPendingIntent(R.id.widget_overview_btn_expense, expenseIntent)

            // Nút Thêm Thu
            val incomeIntent = WidgetRenderUtils.getDeepLinkPendingIntent(
                context,
                "moneytracker://add?type=income",
                widgetId * 10 + 3
            )
            setOnClickPendingIntent(R.id.widget_overview_btn_income, incomeIntent)

            // Nút Giọng nói
            val voiceIntent = WidgetRenderUtils.getDeepLinkPendingIntent(
                context,
                "moneytracker://voice",
                widgetId * 10 + 4
            )
            setOnClickPendingIntent(R.id.widget_overview_btn_voice, voiceIntent)

            // Nút Quét hoá đơn
            val scanIntent = WidgetRenderUtils.getDeepLinkPendingIntent(
                context,
                "moneytracker://scan",
                widgetId * 10 + 5
            )
            setOnClickPendingIntent(R.id.widget_overview_btn_scan, scanIntent)
        }

        appWidgetManager.updateAppWidget(widgetId, views)
    }
}
