package com.example.money_tracker_app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

class WidgetSyncWorker(
    private val appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        return try {
            val appWidgetManager = AppWidgetManager.getInstance(appContext)
            val prefs = WidgetRenderUtils.getPrefs(appContext)

            // 1. Balance Widget
            val balanceIds = appWidgetManager.getAppWidgetIds(
                ComponentName(appContext, MoneyTrackerWidgetProvider::class.java)
            )
            if (balanceIds.isNotEmpty()) {
                MoneyTrackerWidgetProvider().onUpdate(appContext, appWidgetManager, balanceIds, prefs)
            }

            // 2. Budget Widget
            val budgetIds = appWidgetManager.getAppWidgetIds(
                ComponentName(appContext, BudgetWidgetProvider::class.java)
            )
            if (budgetIds.isNotEmpty()) {
                BudgetWidgetProvider().onUpdate(appContext, appWidgetManager, budgetIds, prefs)
            }

            // 3. Goal Widget
            val goalIds = appWidgetManager.getAppWidgetIds(
                ComponentName(appContext, GoalWidgetProvider::class.java)
            )
            if (goalIds.isNotEmpty()) {
                GoalWidgetProvider().onUpdate(appContext, appWidgetManager, goalIds, prefs)
            }

            // 4. Overview Widget
            val overviewIds = appWidgetManager.getAppWidgetIds(
                ComponentName(appContext, OverviewWidgetProvider::class.java)
            )
            if (overviewIds.isNotEmpty()) {
                OverviewWidgetProvider().onUpdate(appContext, appWidgetManager, overviewIds, prefs)
            }

            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }

    companion object {
        private const val WORK_NAME = "PeriodicWidgetSyncWork"

        fun schedule(context: Context) {
            try {
                val request = PeriodicWorkRequestBuilder<WidgetSyncWorker>(
                    30, TimeUnit.MINUTES
                ).build()

                WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                    WORK_NAME,
                    ExistingPeriodicWorkPolicy.KEEP,
                    request
                )
            } catch (_: Exception) {}
        }
    }
}
