package com.example.money_tracker_app

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.ListView
import android.widget.TextView
import org.json.JSONArray

class WidgetConfigActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val appWidgetManager = AppWidgetManager.getInstance(this)
        val providerInfo = appWidgetManager.getAppWidgetInfo(appWidgetId)
        val providerClassName = providerInfo?.provider?.className ?: ""

        val prefs = WidgetRenderUtils.getPrefs(this)

        val layout = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setPadding(40, 40, 40, 40)
        }

        val titleView = TextView(this).apply {
            textSize = 18f
            setTypeface(null, android.graphics.Typeface.BOLD)
            setPadding(0, 0, 0, 30)
        }
        layout.addView(titleView)

        val listView = ListView(this)
        layout.addView(listView)
        setContentView(layout)

        if (providerClassName.contains("GoalWidgetProvider")) {
            titleView.text = getString(R.string.widget_config_choose_goal)
            val goalsJson = prefs.getString("widget_goals_json", "[]") ?: "[]"
            val items = mutableListOf<Pair<String, String>>() // Name, Id

            try {
                val array = JSONArray(goalsJson)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    val id = obj.optString("id", "")
                    val name = obj.optString("name", "Mục tiêu")
                    val current = obj.optString("current", "0đ")
                    val target = obj.optString("target", "0đ")
                    items.add(Pair("$name ($current / $target)", id))
                }
            } catch (_: Exception) {}

            if (items.isEmpty()) {
                items.add(Pair("Chưa có mục tiêu nào", ""))
            }

            val adapter = ArrayAdapter(this, android.R.layout.simple_list_item_1, items.map { it.first })
            listView.adapter = adapter

            listView.setOnItemClickListener { _, _, position, _ ->
                val chosenId = items[position].second
                prefs.edit().putString("widget_${appWidgetId}_goal_id", chosenId).apply()

                val provider = GoalWidgetProvider()
                provider.onUpdate(this, appWidgetManager, intArrayOf(appWidgetId), prefs)

                val resultValue = Intent().apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                setResult(RESULT_OK, resultValue)
                finish()
            }
        } else {
            // MoneyTrackerWidgetProvider hoặc OverviewWidgetProvider: Chọn ví hiển thị
            titleView.text = getString(R.string.widget_config_choose_wallet)
            val walletsJson = prefs.getString("widget_wallets_json", "[]") ?: "[]"
            val items = mutableListOf<Pair<String, String>>() // Display, Id
            items.add(Pair(getString(R.string.widget_config_all_wallets), ""))

            try {
                val array = JSONArray(walletsJson)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    val id = obj.optString("id", "")
                    val name = obj.optString("name", "Ví")
                    val balance = obj.optString("balance", "0đ")
                    items.add(Pair("$name ($balance)", id))
                }
            } catch (_: Exception) {}

            val adapter = ArrayAdapter(this, android.R.layout.simple_list_item_1, items.map { it.first })
            listView.adapter = adapter

            listView.setOnItemClickListener { _, _, position, _ ->
                val chosenId = items[position].second
                prefs.edit().putString("widget_${appWidgetId}_wallet_id", chosenId).apply()

                if (providerClassName.contains("OverviewWidgetProvider")) {
                    val provider = OverviewWidgetProvider()
                    provider.onUpdate(this, appWidgetManager, intArrayOf(appWidgetId), prefs)
                } else {
                    val provider = MoneyTrackerWidgetProvider()
                    provider.onUpdate(this, appWidgetManager, intArrayOf(appWidgetId), prefs)
                }

                val resultValue = Intent().apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                setResult(RESULT_OK, resultValue)
                finish()
            }
        }
    }
}
