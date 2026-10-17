package com.pedrodiniz.memoryword

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.pedrodiniz.memoryword/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NotificationHelper.createChannel(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
                        }
                    }
                    result.success(true)
                }
                "showNotification" -> {
                    val id = call.argument<Int>("id") ?: 100
                    val title = call.argument<String>("title") ?: "MemoryWord"
                    val body = call.argument<String>("body") ?: ""
                    NotificationHelper.showSystemNotification(applicationContext, id, title, body)
                    result.success(true)
                }
                "scheduleReminder" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val silenced = call.argument<Boolean>("silenced") ?: false
                    val hour = call.argument<Int>("hour") ?: 19
                    val minute = call.argument<Int>("minute") ?: 0
                    val daysCsv = call.argument<String>("days") ?: "1,2,3,4,5"
                    val title = call.argument<String>("title") ?: "⏰ Hora de treinar!"
                    val body = call.argument<String>("body") ?: "O seu momento de memorização diária chegou!"

                    val prefs = applicationContext.getSharedPreferences("memoryword_prefs", Context.MODE_PRIVATE)
                    prefs.edit()
                        .putBoolean("enabled", enabled)
                        .putBoolean("silenced", silenced)
                        .putInt("hour", hour)
                        .putInt("minute", minute)
                        .putString("days", daysCsv)
                        .putString("title", title)
                        .putString("body", body)
                        .apply()

                    if (enabled && !silenced) {
                        NotificationHelper.scheduleNextAlarm(applicationContext, hour, minute)
                    } else {
                        NotificationHelper.cancelAlarm(applicationContext)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}

object NotificationHelper {
    const val CHANNEL_ID = "memory_word_channel_id"

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Lembretes e Progresso MemoryWord",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notificações de horário de treino e conquistas diárias"
                enableVibration(true)
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    fun showSystemNotification(context: Context, id: Int, title: String, body: String) {
        createChannel(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                return
            }
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            id,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(id, notification)
    }

    fun scheduleNextAlarm(context: Context, hour: Int, minute: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            777,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val now = Calendar.getInstance()
        val target = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        if (target.before(now) || target.timeInMillis <= now.timeInMillis) {
            target.add(Calendar.DAY_OF_YEAR, 1)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.timeInMillis, pendingIntent)
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, target.timeInMillis, pendingIntent)
        }
    }

    fun cancelAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            777,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val prefs = context.getSharedPreferences("memoryword_prefs", Context.MODE_PRIVATE)
        val enabled = prefs.getBoolean("enabled", false)
        val silenced = prefs.getBoolean("silenced", false)
        if (!enabled || silenced) return

        val hour = prefs.getInt("hour", 19)
        val minute = prefs.getInt("minute", 0)
        val daysCsv = prefs.getString("days", "1,2,3,4,5") ?: ""
        val title = prefs.getString("title", "⏰ Hora de treinar!") ?: "⏰ Hora de treinar!"
        val body = prefs.getString("body", "O seu momento de memorização diária chegou!") ?: ""

        val calDay = Calendar.getInstance().get(Calendar.DAY_OF_WEEK)
        val isoDay = if (calDay == Calendar.SUNDAY) 7 else calDay - 1

        val allowedDays = daysCsv.split(",").mapNotNull { it.trim().toIntOrNull() }
        if (allowedDays.contains(isoDay)) {
            NotificationHelper.showSystemNotification(context, 777, title, body)
        }

        NotificationHelper.scheduleNextAlarm(context, hour, minute)
    }
}