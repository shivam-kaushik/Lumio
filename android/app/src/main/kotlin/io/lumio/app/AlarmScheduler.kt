package io.lumio.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class AlarmScheduler(private val context: Context) {
    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    
    companion object {
        private const val TAG = "AlarmScheduler"
    }

    fun scheduleExactAlarm(
        id: Int,
        title: String,
        body: String,
        scheduledTimeMillis: Long,
        payload: String?
    ): Boolean {
        Log.d(TAG, "═══════════════════════════════════════════════════")
        Log.d(TAG, "🔔 AlarmScheduler.scheduleExactAlarm called")
        Log.d(TAG, "═══════════════════════════════════════════════════")
        
        try {
            // Check if we can schedule exact alarms
            Log.d(TAG, "📋 Checking permissions...")
            Log.d(TAG, "   Android SDK: ${Build.VERSION.SDK_INT}")
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val canSchedule = alarmManager.canScheduleExactAlarms()
                Log.d(TAG, "   Can schedule exact alarms: $canSchedule")
                
                if (!canSchedule) {
                    Log.e(TAG, "❌ CANNOT SCHEDULE EXACT ALARMS - PERMISSION NOT GRANTED")
                    Log.e(TAG, "   User needs to grant 'Alarms & Reminders' permission")
                    Log.e(TAG, "   Go to: Settings → Apps → Lumio → Alarms & Reminders")
                    return false
                }
            } else {
                Log.d(TAG, "   Android < 12, exact alarm permission not required")
            }

            Log.d(TAG, "📝 Creating Intent and PendingIntent...")
            
            // Create intent for AlarmReceiver
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                putExtra(AlarmReceiver.EXTRA_NOTIFICATION_ID, id)
                putExtra(AlarmReceiver.EXTRA_TITLE, title)
                putExtra(AlarmReceiver.EXTRA_BODY, body)
                putExtra(AlarmReceiver.EXTRA_PAYLOAD, payload)
            }
            
            Log.d(TAG, "   Intent created: ${intent.component?.className}")
            Log.d(TAG, "   Intent extras:")
            Log.d(TAG, "     - notification_id: $id")
            Log.d(TAG, "     - title: $title")
            Log.d(TAG, "     - body: $body")
            Log.d(TAG, "     - payload: $payload")

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            if (pendingIntent != null) {
                Log.d(TAG, "✅ PendingIntent created successfully")
            } else {
                Log.e(TAG, "❌ Failed to create PendingIntent")
                return false
            }

            // Schedule exact alarm with wake-up
            val currentTime = System.currentTimeMillis()
            val timeUntilAlarm = scheduledTimeMillis - currentTime
            
            Log.d(TAG, "📅 Scheduling alarm:")
            Log.d(TAG, "   ID: $id")
            Log.d(TAG, "   Title: $title")
            Log.d(TAG, "   Scheduled time (millis): $scheduledTimeMillis")
            Log.d(TAG, "   Current time (millis): $currentTime")
            Log.d(TAG, "   Time until alarm: ${timeUntilAlarm / 1000} seconds")
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    scheduledTimeMillis,
                    pendingIntent
                )
                Log.d(TAG, "✅ Scheduled exact alarm (AllowWhileIdle): id=$id")
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    scheduledTimeMillis,
                    pendingIntent
                )
                Log.d(TAG, "✅ Scheduled exact alarm: id=$id")
            }
            
            // Verify it was scheduled by checking if pending intent exists
            val verifyIntent = PendingIntent.getBroadcast(
                context,
                id,
                Intent(context, AlarmReceiver::class.java),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (verifyIntent != null) {
                Log.d(TAG, "✅ Verified: PendingIntent exists for alarm id=$id")
            } else {
                Log.w(TAG, "⚠️ Warning: PendingIntent not found after scheduling id=$id")
            }
            
            return true
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to schedule alarm: ${e.message}")
            e.printStackTrace()
            return false
        }
    }

    fun cancelAlarm(id: Int) {
        try {
            // Create intent matching the one used during scheduling
            // The intent must match exactly (same action, component, etc.) for PendingIntent lookup
            val intent = Intent(context, AlarmReceiver::class.java)
            
            // Use FLAG_NO_CREATE to retrieve the existing PendingIntent
            // The request code (id) is the primary matching criterion
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            
            if (pendingIntent != null) {
                // Cancel the alarm
                alarmManager.cancel(pendingIntent)
                // Cancel the PendingIntent itself
                pendingIntent.cancel()
                Log.d(TAG, "✅ Successfully cancelled alarm: id=$id")
            } else {
                // This might happen if alarm already fired or was never scheduled
                Log.w(TAG, "⚠️ No active alarm found to cancel: id=$id (may have already fired or expired)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to cancel alarm id=$id: ${e.message}", e)
        }
    }

    fun cancelAllAlarms() {
        // Note: There's no direct way to cancel all alarms
        // This would need to be tracked on Flutter side
        Log.d(TAG, "🗑️ Cancel all alarms requested")
    }
}

