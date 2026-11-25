package com.example.money_tracker_app

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.util.Calendar
import java.util.concurrent.TimeUnit

class MidnightBackupWorker(
    private val appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        if (hour >= 3) {
            return Result.success()
        }

        val completion = CompletableDeferred<Boolean>()
        var engine: FlutterEngine? = null

        return try {
            withContext(Dispatchers.Main) {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(appContext)
                loader.ensureInitializationComplete(appContext, null)

                val flutterEngine = FlutterEngine(appContext)
                engine = flutterEngine

                MethodChannel(
                    flutterEngine.dartExecutor.binaryMessenger,
                    BACKUP_CHANNEL
                ).setMethodCallHandler { call, result ->
                    if (call.method == "complete") {
                        val success = call.arguments as? Boolean ?: false
                        completion.complete(success)
                        result.success(null)
                    } else {
                        result.notImplemented()
                    }
                }

                val entrypoint = DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(),
                    "package:money_tracker_app/services/midnight_sync_service.dart",
                    "midnightBackupBackgroundMain"
                )
                flutterEngine.dartExecutor.executeDartEntrypoint(entrypoint)
            }

            val succeeded = withTimeoutOrNull(90_000L) { completion.await() } ?: false
            if (succeeded) {
                Result.success()
            } else if (runAttemptCount < 2) {
                Result.retry()
            } else {
                Result.failure()
            }
        } catch (_: Exception) {
            if (runAttemptCount < 2) Result.retry() else Result.failure()
        } finally {
            engine?.let { flutterEngine ->
                withContext(Dispatchers.Main) {
                    flutterEngine.destroy()
                }
            }
        }
    }

    companion object {
        private const val WORK_NAME = "MidnightCloudBackupWork"
        private const val BACKUP_CHANNEL = "app.mono/midnight_backup"

        fun computeInitialDelayMillis(now: Calendar = Calendar.getInstance()): Long {
            val next = (now.clone() as Calendar).apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 5)
                set(Calendar.MILLISECOND, 0)
                if (!after(now)) {
                    add(Calendar.DAY_OF_YEAR, 1)
                }
            }
            return (next.timeInMillis - now.timeInMillis).coerceAtLeast(0L)
        }

        fun schedule(context: Context) {
            try {
                val constraints = Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build()

                val request = PeriodicWorkRequestBuilder<MidnightBackupWorker>(
                    24,
                    TimeUnit.HOURS
                )
                    .setInitialDelay(computeInitialDelayMillis(), TimeUnit.MILLISECONDS)
                    .setConstraints(constraints)
                    .build()

                WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                    WORK_NAME,
                    ExistingPeriodicWorkPolicy.KEEP,
                    request
                )
            } catch (_: Exception) {}
        }
    }
}
