package com.example.money_tracker_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object WidgetRenderUtils {
    const val PREFS_NAME = "HomeWidgetPreferences"
    const val ACTION_TOGGLE_PRIVACY = "com.example.money_tracker_app.ACTION_TOGGLE_PRIVACY"
    const val ACTION_AUTO_HIDE = "com.example.money_tracker_app.ACTION_AUTO_HIDE"
    const val ACTION_TOGGLE_PERIOD = "com.example.money_tracker_app.ACTION_TOGGLE_PERIOD"
    const val EXTRA_WIDGET_ID = "extra_widget_id"
    const val EXTRA_PERIOD = "extra_period"

    fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    /**
     * Mặc định là hiển thị đầy đủ (false).
     * Chỉ ẩn khi người dùng chủ động chạm vào con mắt.
     */
    fun isPrivacyHidden(context: Context, widgetId: Int): Boolean {
        return try {
            getPrefs(context).getBoolean("widget_${widgetId}_hidden", false)
        } catch (_: Exception) {
            false
        }
    }

    fun togglePrivacy(context: Context, widgetId: Int) {
        val prefs = getPrefs(context)
        val current = isPrivacyHidden(context, widgetId)
        prefs.edit().putBoolean("widget_${widgetId}_hidden", !current).apply()
    }

    fun togglePrivacyWithTimeout(context: Context, providerClass: Class<*>, widgetId: Int) {
        togglePrivacy(context, widgetId)
    }

    fun maskIfHidden(value: String, isHidden: Boolean): String {
        return if (isHidden) "••••••" else value
    }

    fun isDateCurrent(snapshotDate: String?): Boolean {
        if (snapshotDate.isNullOrEmpty()) return false
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        return today == snapshotDate
    }

    fun getPeriod(context: Context, widgetId: Int): String {
        return try {
            getPrefs(context).getString("widget_${widgetId}_period", "month") ?: "month"
        } catch (_: Exception) {
            "month"
        }
    }

    fun setPeriod(context: Context, widgetId: Int, period: String) {
        try {
            getPrefs(context).edit().putString("widget_${widgetId}_period", period).apply()
        } catch (_: Exception) {}
    }

    fun getDeepLinkPendingIntent(context: Context, uriString: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse(uriString)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun getTogglePrivacyPendingIntent(context: Context, providerClass: Class<*>, widgetId: Int): PendingIntent {
        val intent = Intent(context, providerClass).apply {
            action = ACTION_TOGGLE_PRIVACY
            putExtra(EXTRA_WIDGET_ID, widgetId)
        }
        return PendingIntent.getBroadcast(
            context,
            widgetId * 1000 + 1,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun getTogglePeriodPendingIntent(context: Context, providerClass: Class<*>, widgetId: Int, period: String): PendingIntent {
        val intent = Intent(context, providerClass).apply {
            action = ACTION_TOGGLE_PERIOD
            putExtra(EXTRA_WIDGET_ID, widgetId)
            putExtra(EXTRA_PERIOD, period)
        }
        return PendingIntent.getBroadcast(
            context,
            widgetId * 1000 + 3 + if (period == "week") 1 else 2,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun isNightMode(context: Context): Boolean {
        val nightModeFlags = context.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK
        return nightModeFlags == android.content.res.Configuration.UI_MODE_NIGHT_YES
    }

    fun renderSevenDaysChartBitmap(
        context: Context,
        chartJsonString: String?,
        widthDp: Float = 140f,
        heightDp: Float = 44f,
        isDarkMode: Boolean = isNightMode(context)
    ): android.graphics.Bitmap {
        val density = context.resources.displayMetrics.density
        val widthPx = kotlin.math.max(1, (widthDp * density).toInt())
        val heightPx = kotlin.math.max(1, (heightDp * density).toInt())

        val bitmap = android.graphics.Bitmap.createBitmap(widthPx, heightPx, android.graphics.Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(bitmap)

        val daysList = mutableListOf<Triple<String, Float, Boolean>>()
        if (!chartJsonString.isNullOrEmpty()) {
            try {
                val jsonArray = org.json.JSONArray(chartJsonString)
                for (i in 0 until jsonArray.length()) {
                    val obj = jsonArray.getJSONObject(i)
                    val label = obj.optString("day_label", "")
                    val ratio = obj.optDouble("ratio", 0.1).toFloat()
                    val isToday = obj.optBoolean("is_today", false)
                    daysList.add(Triple(label, ratio.coerceIn(0.08f, 1.0f), isToday))
                }
            } catch (_: Exception) {}
        }

        if (daysList.isEmpty()) {
            val defaultDays = listOf("T2", "T3", "T4", "T5", "T6", "T7", "CN")
            defaultDays.forEachIndexed { idx, d ->
                daysList.add(Triple(d, 0.15f, idx == 6))
            }
        }

        val barPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
        val textPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = android.graphics.Paint.Align.CENTER
            textSize = 9f * density
        }

        val bottomTextPadding = 2f * density
        val textHeight = 11f * density
        val barAreaHeight = heightPx - textHeight - bottomTextPadding
        val count = daysList.size
        val stepX = widthPx.toFloat() / count
        val barWidth = (stepX * 0.42f).coerceAtLeast(4f * density)
        val cornerRadius = 3f * density

        val normalBarColor = if (isDarkMode) android.graphics.Color.parseColor("#475569") else android.graphics.Color.parseColor("#CBD5E1")
        val todayBarColor = android.graphics.Color.parseColor("#2F7E79")
        val normalTextColor = if (isDarkMode) android.graphics.Color.parseColor("#94A3B8") else android.graphics.Color.parseColor("#64748B")
        val todayTextColor = android.graphics.Color.parseColor("#2F7E79")

        val baseLinePaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
            color = if (isDarkMode) android.graphics.Color.parseColor("#334155") else android.graphics.Color.parseColor("#E2E8F0")
            strokeWidth = 1f * density
        }
        canvas.drawLine(4f * density, barAreaHeight, widthPx - 4f * density, barAreaHeight, baseLinePaint)

        daysList.forEachIndexed { i, (label, ratio, isToday) ->
            val centerX = i * stepX + stepX / 2f
            val left = centerX - barWidth / 2f
            val right = centerX + barWidth / 2f

            val barH = (barAreaHeight * ratio).coerceAtLeast(4f * density)
            val top = barAreaHeight - barH
            val bottom = barAreaHeight

            barPaint.color = if (isToday) todayBarColor else normalBarColor
            val rect = android.graphics.RectF(left, top, right, bottom)
            canvas.drawRoundRect(rect, cornerRadius, cornerRadius, barPaint)

            // Draw label text
            textPaint.color = if (isToday) todayTextColor else normalTextColor
            textPaint.typeface = if (isToday) android.graphics.Typeface.DEFAULT_BOLD else android.graphics.Typeface.DEFAULT
            canvas.drawText(label, centerX, heightPx - bottomTextPadding, textPaint)
        }

        return bitmap
    }
}
