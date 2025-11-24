package io.lumio.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class AlarmReceiver : BroadcastReceiver() {
    companion object {
        const val EXTRA_NOTIFICATION_ID = "notification_id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_PAYLOAD = "payload"
        const val CHANNEL_ID = "lumio_reminders"
        const val CHANNEL_NAME = "Lumio Reminders"
    }

    override fun onReceive(context: Context, intent: Intent) {
        android.util.Log.d("AlarmReceiver", "🔔 AlarmReceiver triggered!")
        android.util.Log.d("AlarmReceiver", "   Intent action: ${intent.action}")
        
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "Reminder"
        val body = intent.getStringExtra(EXTRA_BODY) ?: ""
        val payload = intent.getStringExtra(EXTRA_PAYLOAD)

        android.util.Log.d("AlarmReceiver", "   Notification ID: $notificationId")
        android.util.Log.d("AlarmReceiver", "   Title: $title")
        android.util.Log.d("AlarmReceiver", "   Body: $body")
        android.util.Log.d("AlarmReceiver", "   Payload: $payload")

        // Create notification channel
        createNotificationChannel(context)
        
        android.util.Log.d("AlarmReceiver", "✅ Notification channel created")

        // Build notification
        val mainIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            putExtra("notification_payload", payload)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        // Show notification
        val notificationManager = NotificationManagerCompat.from(context)
        try {
            notificationManager.notify(notificationId, notification)
            android.util.Log.d("AlarmReceiver", "✅ Notification shown successfully (id=$notificationId)")
        } catch (e: SecurityException) {
            android.util.Log.e("AlarmReceiver", "❌ SecurityException showing notification: ${e.message}")
            e.printStackTrace()
        } catch (e: Exception) {
            android.util.Log.e("AlarmReceiver", "❌ Error showing notification: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, importance).apply {
                description = "Notifications for Lumio reminders"
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
            }

            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}

