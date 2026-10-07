package com.example.money_tracker_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class LargeWidgetProvider : HomeWidgetProvider() {

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
            WidgetRenderUtils.ACTION_TOGGLE_PERIOD -> {
                val newPeriod = intent.getStringExtra(WidgetRenderUtils.EXTRA_PERIOD) ?: "month"
                WidgetRenderUtils.setPeriod(context, widgetId, newPeriod)
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
        val views = RemoteViews(context.packageName, R.layout.widget_large).apply {
            val isHidden = WidgetRenderUtils.isPrivacyHidden(context, widgetId)
            val currentPeriod = WidgetRenderUtils.getPeriod(context, widgetId) // "week" or "month"

            // 1. Tiêu đề ví & Số dư
            val chosenWalletId = widgetData.getString("widget_${widgetId}_wallet_id", "") ?: ""
            var displayTitle = "Tài chính"
            var displayBalance = widgetData.getString("widget_total_balance", "0đ") ?: "0đ"

            if (chosenWalletId.isNotEmpty()) {
                val walletsJson = widgetData.getString("widget_wallets_json", "[]") ?: "[]"
                try {
                    val array = JSONArray(walletsJson)
                    for (i in 0 until array.length()) {
                        val obj = array.getJSONObject(i)
                        if (obj.optString("id") == chosenWalletId) {
                            displayTitle = "Ví " + obj.optString("name", "Ví")
                            displayBalance = obj.optString("balance", "0đ")
                            break
                        }
                    }
                } catch (_: Exception) {}
            }

            setTextViewText(R.id.widget_title, displayTitle)
            setTextViewText(R.id.widget_total_balance, WidgetRenderUtils.maskIfHidden(displayBalance, isHidden))

            // 2. Tab Tuần / Tháng (Dùng setViewVisibility hoàn toàn an toàn)
            val isWeek = currentPeriod == "week"

            if (isWeek) {
                setViewVisibility(R.id.widget_tabs_week_active, View.VISIBLE)
                setViewVisibility(R.id.widget_tabs_month_active, View.GONE)
            } else {
                setViewVisibility(R.id.widget_tabs_week_active, View.GONE)
                setViewVisibility(R.id.widget_tabs_month_active, View.VISIBLE)
            }

            val weekPendingIntent = WidgetRenderUtils.getTogglePeriodPendingIntent(context, LargeWidgetProvider::class.java, widgetId, "week")
            val monthPendingIntent = WidgetRenderUtils.getTogglePeriodPendingIntent(context, LargeWidgetProvider::class.java, widgetId, "month")

            setOnClickPendingIntent(R.id.widget_tab_week, weekPendingIntent)
            setOnClickPendingIntent(R.id.widget_tab_month, monthPendingIntent)
            setOnClickPendingIntent(R.id.widget_tab_week_alt, weekPendingIntent)
            setOnClickPendingIntent(R.id.widget_tab_month_alt, monthPendingIntent)

            // 3. Dòng tiền
            val incomeVal = if (isWeek) {
                widgetData.getString("widget_week_income", "0đ") ?: "0đ"
            } else {
                widgetData.getString("widget_month_income", "0đ") ?: "0đ"
            }

            val expenseVal = if (isWeek) {
                widgetData.getString("widget_week_expense", "0đ") ?: "0đ"
            } else {
                widgetData.getString("widget_month_expense", "0đ") ?: "0đ"
            }

            val diffVal = if (isWeek) {
                widgetData.getString("widget_week_difference", "+0đ") ?: "+0đ"
            } else {
                widgetData.getString("widget_month_difference", "+0đ") ?: "+0đ"
            }

            val maskedIncome = WidgetRenderUtils.maskIfHidden(incomeVal, isHidden)
            val maskedExpense = WidgetRenderUtils.maskIfHidden(expenseVal, isHidden)
            val maskedDiff = WidgetRenderUtils.maskIfHidden(diffVal, isHidden)

            val periodLabel = if (isWeek) "Tuần" else "Tháng"
            setTextViewText(R.id.widget_period_flow, "$periodLabel: +$maskedIncome • -$maskedExpense")
            setTextViewText(R.id.widget_period_diff, maskedDiff)

            // 4. Huy hiệu so sánh tháng trước (Dùng setViewVisibility an toàn)
            val vsPercent: String = try {
                val str = widgetData.getString("widget_month_vs_last_month_percent", "")
                if (!str.isNullOrEmpty()) {
                    str
                } else {
                    widgetData.getInt("widget_month_vs_last_month_percent", 0).toString()
                }
            } catch (_: Exception) {
                try {
                    widgetData.getInt("widget_month_vs_last_month_percent", 0).toString()
                } catch (_: Exception) {
                    "0"
                }
            }
            val vsStatus = widgetData.getString("widget_month_vs_last_month_status", "neutral")
            when (vsStatus) {
                "increased" -> {
                    setTextViewText(R.id.widget_comparison_badge_neg, "↑ $vsPercent% so với tháng trước")
                    setViewVisibility(R.id.widget_comparison_badge_neg, View.VISIBLE)
                    setViewVisibility(R.id.widget_comparison_badge, View.GONE)
                }
                "decreased" -> {
                    setTextViewText(R.id.widget_comparison_badge, "↓ $vsPercent% so với tháng trước")
                    setViewVisibility(R.id.widget_comparison_badge, View.VISIBLE)
                    setViewVisibility(R.id.widget_comparison_badge_neg, View.GONE)
                }
                else -> {
                    setTextViewText(R.id.widget_comparison_badge, "Chi tiêu ổn định")
                    setViewVisibility(R.id.widget_comparison_badge, View.VISIBLE)
                    setViewVisibility(R.id.widget_comparison_badge_neg, View.GONE)
                }
            }

            // 5. Hạn mức ngày
            val safeSpend = widgetData.getString("widget_safe_daily_spend", "") ?: ""
            val safeText = if (safeSpend.isNotEmpty() && safeSpend != "Không giới hạn" && safeSpend != "Đã vượt hạn mức") {
                "Hạn mức hôm nay: " + WidgetRenderUtils.maskIfHidden(safeSpend, isHidden)
            } else {
                "Chi hôm nay: " + WidgetRenderUtils.maskIfHidden(widgetData.getString("widget_today_expense", "0đ") ?: "0đ", isHidden)
            }
            setTextViewText(R.id.widget_safe_spend_value, safeText)

            // 6. Mini bar chart 7 ngày
            val chartJson = widgetData.getString("widget_seven_days_chart_json", "[]")
            val chartBitmap = WidgetRenderUtils.renderSevenDaysChartBitmap(
                context,
                chartJson,
                widthDp = 130f,
                heightDp = 50f
            )
            setImageViewBitmap(R.id.widget_bar_chart, chartBitmap)

            // 7. Top 3 danh mục
            val categoriesJson = widgetData.getString("widget_top_categories_json", "[]") ?: "[]"
            try {
                val catArray = JSONArray(categoriesJson)
                val catViews = listOf(
                    Pair(R.id.widget_cat_1_name, R.id.widget_cat_1_amount),
                    Pair(R.id.widget_cat_2_name, R.id.widget_cat_2_amount),
                    Pair(R.id.widget_cat_3_name, R.id.widget_cat_3_amount)
                )
                for (i in 0 until 3) {
                    val (nameId, amountId) = catViews[i]
                    if (i < catArray.length()) {
                        val catObj = catArray.getJSONObject(i)
                        val name = catObj.optString("name", "Khác")
                        val amount = catObj.optString("amount", "0đ")
                        setTextViewText(nameId, "• $name")
                        setTextViewText(amountId, WidgetRenderUtils.maskIfHidden(amount, isHidden))
                    } else {
                        setTextViewText(nameId, if (i == 0) "• Chưa có chi tiêu" else "")
                        setTextViewText(amountId, "")
                    }
                }
            } catch (_: Exception) {}

            // 8. Icon con mắt vector
            setImageViewResource(
                R.id.widget_btn_eye,
                if (isHidden) R.drawable.ic_eye_hidden else R.drawable.ic_eye_visible
            )
            val eyePendingIntent = WidgetRenderUtils.getTogglePrivacyPendingIntent(
                context,
                LargeWidgetProvider::class.java,
                widgetId
            )
            setOnClickPendingIntent(R.id.widget_btn_eye, eyePendingIntent)

            // 9. Nút đáy
            val expensePendingIntent = WidgetRenderUtils.getDeepLinkPendingIntent(
                context,
                "moneytracker://add?type=expense",
                widgetId * 10 + 1
            )
            setOnClickPendingIntent(R.id.widget_btn_expense, expensePendingIntent)

            val incomePendingIntent = WidgetRenderUtils.getDeepLinkPendingIntent(
                context,
                "moneytracker://add?type=income",
                widgetId * 10 + 2
            )
            setOnClickPendingIntent(R.id.widget_btn_income, incomePendingIntent)

            val scanPendingIntent = WidgetRenderUtils.getDeepLinkPendingIntent(
                context,
                "moneytracker://scan_receipt",
                widgetId * 10 + 4
            )
            setOnClickPendingIntent(R.id.widget_btn_scan, scanPendingIntent)

            val reportPendingIntent = WidgetRenderUtils.getDeepLinkPendingIntent(
                context,
                "moneytracker://report",
                widgetId * 10 + 5
            )
            setOnClickPendingIntent(R.id.widget_btn_report, reportPendingIntent)

            // Chạm nền -> Mở Ví
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
