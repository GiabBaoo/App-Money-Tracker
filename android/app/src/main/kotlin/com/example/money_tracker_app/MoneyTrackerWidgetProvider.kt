package com.example.money_tracker_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class MoneyTrackerWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_money_tracker).apply {
                // Đọc tổng số dư từ HomeWidget SharedPreferences (mặc định "0đ")
                val totalBalance = widgetData.getString("widget_total_balance", "0đ") ?: "0đ"
                setTextViewText(R.id.widget_total_balance, totalBalance)

                // PendingIntent khi nhấn nút "+ Thêm khoản chi" mở thẳng màn hình thêm giao dịch qua deep link
                val addPendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("moneytracker://add_transaction")
                )
                setOnClickPendingIntent(R.id.widget_btn_add, addPendingIntent)

                // Khi bấm vào nền widget: mở ứng dụng
                val openAppPendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_container, openAppPendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
