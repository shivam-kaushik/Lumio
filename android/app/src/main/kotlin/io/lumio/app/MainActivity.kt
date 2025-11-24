package io.lumio.app

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "io.lumio.app/permissions"
    private val ALARM_CHANNEL = "io.lumio.app/alarms"
    private val WIFI_CHANNEL = "io.lumio.app/wifi"
    private val DEVICE_STATE_CHANNEL = "io.lumio.app/device_state"
    private lateinit var alarmScheduler: AlarmScheduler
    private var batteryReceiver: BroadcastReceiver? = null
    private lateinit var flutterEngine: FlutterEngine

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        this.flutterEngine = flutterEngine
        alarmScheduler = AlarmScheduler(this)
        
        // Permissions channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasExactAlarmPermission" -> {
                    val hasPermission = checkExactAlarmPermission()
                    result.success(hasPermission)
                }
                "openExactAlarmSettings" -> {
                    openExactAlarmSettings()
                    result.success(null)
                }
                "isBatteryOptimizationDisabled" -> {
                    val isDisabled = isBatteryOptimizationDisabled()
                    result.success(isDisabled)
                }
                "requestDisableBatteryOptimization" -> {
                    requestDisableBatteryOptimization()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        
        // Alarm scheduler channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL).setMethodCallHandler { call, result ->
            android.util.Log.d("MainActivity", "═══════════════════════════════════════════════════")
            android.util.Log.d("MainActivity", "📞 Method channel call received")
            android.util.Log.d("MainActivity", "   Channel: $ALARM_CHANNEL")
            android.util.Log.d("MainActivity", "   Method: ${call.method}")
            android.util.Log.d("MainActivity", "   Arguments: ${call.arguments}")
            
            when (call.method) {
                "scheduleExactAlarm" -> {
                    android.util.Log.d("MainActivity", "   Processing scheduleExactAlarm...")
                    
                    val id = call.argument<Int>("id") ?: 0
                    val title = call.argument<String>("title") ?: "Reminder"
                    val body = call.argument<String>("body") ?: ""
                    val scheduledTimeMillis = call.argument<Long>("scheduledTimeMillis") ?: 0L
                    val payload = call.argument<String>("payload")
                    
                    android.util.Log.d("MainActivity", "   Extracted arguments:")
                    android.util.Log.d("MainActivity", "     - id: $id")
                    android.util.Log.d("MainActivity", "     - title: \"$title\"")
                    android.util.Log.d("MainActivity", "     - body: \"$body\"")
                    android.util.Log.d("MainActivity", "     - scheduledTimeMillis: $scheduledTimeMillis")
                    android.util.Log.d("MainActivity", "     - payload: $payload")
                    android.util.Log.d("MainActivity", "   Calling alarmScheduler.scheduleExactAlarm()...")
                    
                    val success = alarmScheduler.scheduleExactAlarm(id, title, body, scheduledTimeMillis, payload)
                    
                    android.util.Log.d("MainActivity", "   Result from alarmScheduler: $success")
                    android.util.Log.d("MainActivity", "   Sending result back to Flutter: $success")
                    android.util.Log.d("MainActivity", "═══════════════════════════════════════════════════")
                    
                    result.success(success)
                }
                "cancelAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    alarmScheduler.cancelAlarm(id)
                    result.success(null)
                }
                "cancelAllAlarms" -> {
                    alarmScheduler.cancelAllAlarms()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        
        // WiFi channel for getting current SSID
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIFI_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCurrentWifiSsid" -> {
                    val ssid = getCurrentWifiSsid()
                    result.success(ssid)
                }
                else -> result.notImplemented()
            }
        }
        
        // Device state channel for battery and screen unlock detection
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_STATE_CHANNEL).setMethodCallHandler { call, result ->
            android.util.Log.d("MainActivity", "🔋 DeviceState: Method call: ${call.method}")
            
            when (call.method) {
                "getBatteryState" -> {
                    val state = getBatteryState()
                    android.util.Log.d("MainActivity", "🔋 Battery state: charging=${state["isCharging"]}, level=${state["batteryLevel"]}")
                    result.success(state)
                }
                "startBatteryMonitoring" -> {
                    startBatteryMonitoring(flutterEngine)
                    result.success(true)
                }
                "stopBatteryMonitoring" -> {
                    stopBatteryMonitoring()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        // Set up screen unlock detection (via activity lifecycle)
        setupScreenUnlockDetection(flutterEngine)
        
        // Start battery monitoring
        startBatteryMonitoring(flutterEngine)
    }
    
    override fun onResume() {
        super.onResume()
        // Screen unlock detected (simplified - in production use more sophisticated detection)
        notifyScreenUnlock()
    }
    
    private fun setupScreenUnlockDetection(flutterEngine: FlutterEngine) {
        // Screen unlock is detected via onResume() lifecycle method
        // For more accurate detection, you'd need a DeviceAdminReceiver or accessibility service
        // This is a simplified implementation
        android.util.Log.d("MainActivity", "📱 Screen unlock detection setup (via lifecycle)")
    }
    
    private fun notifyScreenUnlock() {
        try {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_STATE_CHANNEL)
            channel.invokeMethod("onScreenUnlock", null)
            android.util.Log.d("MainActivity", "📱 Screen unlock event sent to Flutter")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error notifying screen unlock: ${e.message}")
        }
    }
    
    private fun getBatteryState(): Map<String, Any> {
        return try {
            val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            val batteryLevel = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            val status = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_STATUS)
            val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING || 
                           status == BatteryManager.BATTERY_STATUS_FULL
            
            mapOf(
                "isCharging" to isCharging,
                "batteryLevel" to batteryLevel
            )
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error getting battery state: ${e.message}")
            mapOf(
                "isCharging" to false,
                "batteryLevel" to 0
            )
        }
    }
    
    private fun startBatteryMonitoring(flutterEngine: FlutterEngine) {
        if (batteryReceiver != null) {
            return // Already monitoring
        }
        
        batteryReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == Intent.ACTION_BATTERY_CHANGED) {
                    val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                    val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                    val batteryPct = if (level >= 0 && scale > 0) {
                        (level * 100 / scale.toFloat()).toInt()
                    } else {
                        0
                    }
                    
                    val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                    val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                                   status == BatteryManager.BATTERY_STATUS_FULL
                    
                    android.util.Log.d("MainActivity", "🔋 Battery changed: charging=$isCharging, level=$batteryPct%")
                    
                    try {
                        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_STATE_CHANNEL)
                        channel.invokeMethod("onBatteryStateChanged", mapOf(
                            "isCharging" to isCharging,
                            "batteryLevel" to batteryPct
                        ))
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Error sending battery state: ${e.message}")
                    }
                }
            }
        }
        
        val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        registerReceiver(batteryReceiver, filter)
        android.util.Log.d("MainActivity", "🔋 Battery monitoring started")
    }
    
    private fun stopBatteryMonitoring() {
        batteryReceiver?.let {
            try {
                unregisterReceiver(it)
                batteryReceiver = null
                android.util.Log.d("MainActivity", "🔋 Battery monitoring stopped")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Error stopping battery monitoring: ${e.message}")
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopBatteryMonitoring()
    }

    private fun getCurrentWifiSsid(): String? {
        return try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as android.net.wifi.WifiManager
            val wifiInfo = wifiManager.connectionInfo
            
            if (wifiInfo != null && wifiInfo.ssid != null) {
                // Remove quotes from SSID (Android adds them)
                var ssid = wifiInfo.ssid
                if (ssid.startsWith("\"") && ssid.endsWith("\"")) {
                    ssid = ssid.substring(1, ssid.length - 1)
                }
                
                // Check for "unknown ssid" (returned when location is off or no permission)
                if (ssid == "<unknown ssid>" || ssid.isEmpty()) {
                    null
                } else {
                    ssid
                }
            } else {
                null
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error getting WiFi SSID: ${e.message}")
            null
        }
    }

    private fun checkExactAlarmPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }

    private fun openExactAlarmSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                startActivity(intent)
            } catch (e: Exception) {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            }
        }
    }

    private fun isBatteryOptimizationDisabled(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(packageName)
        } else {
            true
        }
    }

    private fun requestDisableBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            } catch (e: Exception) {
                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                startActivity(intent)
            }
        }
    }
}

