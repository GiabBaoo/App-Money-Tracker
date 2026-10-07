package com.example.money_tracker_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class BudgetWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_budget).apply {
                val budgetsJson = widgetData.getString("widget_budgets_json", "[]") ?: "[]"
                val budgetsArray = try {
                    JSONArray(budgetsJson)
                } catch (_: Exception) {
                    JSONArray()
                }

                var totalSpent = 0.0
                var totalLimit = 0.0

                for (i in 0 until budgetsArray.length()) {
                    val b = budgetsArray.optJSONObject(i) ?: continue
                    val spentStr = b.optString("spent", "0").replace(".", "").replace("đ", "").trim()
                    val limitStr = b.optString("limit", "0").replace(".", "").replace("đ", "").trim()
                    totalSpent += spentStr.toDoubleOrNull() ?: 0.0
                    totalLimit += limitStr.toDoubleOrNull() ?: 0.0
                }

                val totalPercent = if (totalLimit > 0) {
                    ((totalSpent / totalLimit) * 100).toInt().coerceIn(0, 100)
                } else {
                    0
                }

                // Cập nhật tổng % và hiển thị thanh tiến độ tương ứng
                setTextViewText(R.id.widget_budget_percent, "$totalPercent%")

                when {
                    totalPercent >= 100 -> {
                        setProgressBar(R.id.widget_budget_progress_red, 100, totalPercent, false)
                        setViewVisibility(R.id.widget_budget_progress_red, View.VISIBLE)
                        setViewVisibility(R.id.widget_budget_progress_orange, View.GONE)
                        setViewVisibility(R.id.widget_budget_progress_green, View.GONE)
                    }
                    totalPercent >= 75 -> {
                        setProgressBar(R.id.widget_budget_progress_orange, 100, totalPercent, false)
                        setViewVisibility(R.id.widget_budget_progress_orange, View.VISIBLE)
                        setViewVisibility(R.id.widget_budget_progress_red, View.GONE)
                        setViewVisibility(R.id.widget_budget_progress_green, View.GONE)
                    }
                    else -> {
                        setProgressBar(R.id.widget_budget_progress_green, 100, totalPercent, false)
                        setViewVisibility(R.id.widget_budget_progress_green, View.VISIBLE)
                        setViewVisibility(R.id.widget_budget_progress_red, View.GONE)
                        setViewVisibility(R.id.widget_budget_progress_orange, View.GONE)
                    }
                }

                if (budgetsArray.length() > 0) {
                    val spentFormatted = CurrencyUtilsStub.formatShort(totalSpent)
                    val limitFormatted = CurrencyUtilsStub.formatShort(totalLimit)
                    setTextViewText(R.id.widget_budget_total_amount, "$spentFormatted / $limitFormatted")
                } else {
                    setTextViewText(R.id.widget_budget_total_amount, "Chưa lập ngân sách")
                }

                // Hạn mức hôm nay
                val safeSpend = widgetData.getString("widget_safe_daily_spend", "") ?: ""
                val safeText = if (safeSpend.isNotEmpty() && safeSpend != "Không giới hạn" && safeSpend != "Đã vượt hạn mức") {
                    "Hôm nay còn $safeSpend"
                } else {
                    "Chi hôm nay: " + (widgetData.getString("widget_today_expense", "0đ") ?: "0đ")
                }
                setTextViewText(R.id.widget_budget_safe_spend, safeText)

                // 2 Danh mục chi tiêu ngân sách tiêu biểu
                if (budgetsArray.length() > 0) {
                    val b1 = budgetsArray.getJSONObject(0)
                    setTextViewText(R.id.widget_budget_cat_1_name, b1.optString("name", "Ăn uống"))
                    val p1 = b1.optInt("percent", 0).coerceIn(0, 100)
                    setTextViewText(R.id.widget_budget_cat_1_amount, "$p1%")
                    setProgressBar(R.id.widget_budget_cat_1_progress, 100, p1, false)
                    setViewVisibility(R.id.widget_budget_cat_1, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.widget_budget_cat_1, View.GONE)
                }

                if (budgetsArray.length() > 1) {
                    val b2 = budgetsArray.getJSONObject(1)
                    setTextViewText(R.id.widget_budget_cat_2_name, b2.optString("name", "Mua sắm"))
                    val p2 = b2.optInt("percent", 0).coerceIn(0, 100)
                    setTextViewText(R.id.widget_budget_cat_2_amount, "$p2%")
                    setProgressBar(R.id.widget_budget_cat_2_progress, 100, p2, false)
                    setViewVisibility(R.id.widget_budget_cat_2, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.widget_budget_cat_2, View.GONE)
                }

                // Nút Thêm Chi
                val expensePendingIntent = WidgetRenderUtils.getDeepLinkPendingIntent(
                    context,
                    "moneytracker://add?type=expense",
                    widgetId * 10 + 1
                )
                setOnClickPendingIntent(R.id.widget_btn_expense, expensePendingIntent)

                // Nút Quét bill
                val scanPendingIntent = WidgetRenderUtils.getDeepLinkPendingIntent(
                    context,
                    "moneytracker://scan_receipt",
                    widgetId * 10 + 2
                )
                setOnClickPendingIntent(R.id.widget_btn_scan, scanPendingIntent)

                // Chạm nền mở Màn hình Ngân sách
                val budgetIntent = WidgetRenderUtils.getDeepLinkPendingIntent(
                    context,
                    "moneytracker://budget",
                    widgetId * 10 + 3
                )
                setOnClickPendingIntent(R.id.widget_container, budgetIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

private object CurrencyUtilsStub {
    fun formatShort(amount: Double): String {
        return if (amount >= 1_000_000) {
            String.format(java.util.Locale.US, "%.1fM", amount / 1_000_000).replace(".0", "") + "đ"
        } else if (amount >= 1_000) {
            String.format(java.util.Locale.US, "%.0fk", amount / 1_000) + "đ"
        } else {
            "${amount.toInt()}đ"
        }
    }
}
