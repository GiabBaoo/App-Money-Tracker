package com.example.money_tracker_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject

class GoalWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_goal).apply {
                val goalsJson = widgetData.getString("widget_goals_json", "[]") ?: "[]"
                val goalsArray = try {
                    JSONArray(goalsJson)
                } catch (_: Exception) {
                    JSONArray()
                }

                val chosenGoalId = widgetData.getString("widget_${widgetId}_goal_id", "") ?: ""

                var selectedGoal: JSONObject? = null
                if (chosenGoalId.isNotEmpty()) {
                    for (i in 0 until goalsArray.length()) {
                        val obj = goalsArray.getJSONObject(i)
                        if (obj.optString("id") == chosenGoalId) {
                            selectedGoal = obj
                            break
                        }
                    }
                }

                // Nếu chưa cấu hình hoặc mục tiêu cũ bị xóa, lấy mục tiêu đầu tiên
                if (selectedGoal == null && goalsArray.length() > 0) {
                    selectedGoal = goalsArray.getJSONObject(0)
                }

                if (selectedGoal == null) {
                    setViewVisibility(R.id.widget_goal_empty, View.VISIBLE)
                    setViewVisibility(R.id.widget_goal_content, View.GONE)

                    val createGoalIntent = WidgetRenderUtils.getDeepLinkPendingIntent(
                        context,
                        "moneytracker://goal",
                        widgetId * 10 + 1
                    )
                    setOnClickPendingIntent(R.id.widget_container, createGoalIntent)
                } else {
                    setViewVisibility(R.id.widget_goal_empty, View.GONE)
                    setViewVisibility(R.id.widget_goal_content, View.VISIBLE)

                    val goalId = selectedGoal.optString("id", "")
                    val title = selectedGoal.optString("name", "Mục tiêu")
                    val current = selectedGoal.optString("current", "0đ")
                    val target = selectedGoal.optString("target", "0đ")
                    val remaining = selectedGoal.optString("remaining", "0đ")
                    val percent = selectedGoal.optInt("percent", 0).coerceIn(0, 100)

                    setTextViewText(R.id.widget_goal_title, title)
                    setTextViewText(R.id.widget_goal_percent, "$percent%")
                    setProgressBar(R.id.widget_goal_progress, 100, percent, false)
                    setTextViewText(R.id.widget_goal_amounts, "$current / $target")
                    setTextViewText(R.id.widget_goal_remaining, "Còn thiếu: $remaining")

                    val openGoalIntent = WidgetRenderUtils.getDeepLinkPendingIntent(
                        context,
                        "moneytracker://goal?id=$goalId",
                        widgetId * 10 + 1
                    )
                    setOnClickPendingIntent(R.id.widget_container, openGoalIntent)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
