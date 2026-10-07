package com.example.money_tracker_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class QuickActionsWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_quick_actions).apply {
                // Nút Thêm Khoản Chi
                val expenseIntent = WidgetRenderUtils.getDeepLinkPendingIntent(
                    context,
                    "moneytracker://add?type=expense",
                    widgetId * 10 + 1
                )
                setOnClickPendingIntent(R.id.widget_qa_expense, expenseIntent)

                // Nút Thêm Khoản Thu
                val incomeIntent = WidgetRenderUtils.getDeepLinkPendingIntent(
                    context,
                    "moneytracker://add?type=income",
                    widgetId * 10 + 2
                )
                setOnClickPendingIntent(R.id.widget_qa_income, incomeIntent)

                // Nút Trợ lý giọng nói
                val voiceIntent = WidgetRenderUtils.getDeepLinkPendingIntent(
                    context,
                    "moneytracker://voice",
                    widgetId * 10 + 3
                )
                setOnClickPendingIntent(R.id.widget_qa_voice, voiceIntent)

                // Nút Quét hoá đơn OCR
                val scanIntent = WidgetRenderUtils.getDeepLinkPendingIntent(
                    context,
                    "moneytracker://scan",
                    widgetId * 10 + 4
                )
                setOnClickPendingIntent(R.id.widget_qa_scan, scanIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
