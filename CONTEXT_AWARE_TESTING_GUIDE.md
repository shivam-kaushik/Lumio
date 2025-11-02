# Context-Aware Reminder Testing Guide

## Overview
This guide provides comprehensive testing steps for the enhanced context-aware reminder system. The system now supports:
- **Location-based triggers** (GPS geofences, WiFi, home detection)
- **Activity-based triggers** (walking, running, driving, cycling, stationary)
- **Device state triggers** (charging start/stop, screen unlock)
- **Time-based triggers** (scheduled reminders)
- **Pattern learning** (adaptive timing based on user behavior)

## Prerequisites

### 1. Setup Emulator
```bash
# Start Android emulator
flutter emulators --launch <emulator_id>

# Or use Android Studio:
# Tools > Device Manager > Create/Start Virtual Device
```

### 2. Required Permissions
Ensure the app has requested:
- **Location** (While in Use or Always)
- **Notifications**
- **Microphone** (for voice input)
- **Battery optimization disabled** (Settings → Battery → Awarely → Don't optimize)
- **Exact alarm permission** (Android 12+, Settings → Apps → Awarely → Schedule exact alarms)

### 3. Enable Logging
All context-aware features have comprehensive logging. View logs using:

```bash
# View all logs
adb logcat | grep -E "(TriggerEngine|ActivityRecognition|DeviceState|Context)"

# View specific service logs
adb logcat | grep TriggerEngine
adb logcat | grep ActivityRecognition  
adb logcat | grep DeviceState
```

## Testing Scenarios

### Scenario 1: Location-Based Reminders (Home Detection)

#### Test: Remind when leaving home
1. **Setup:**
   - Go to Settings → Home Setup
   - Add your home WiFi SSID
   - Set GPS location for home

2. **Create Reminder:**
   - "Take my keys when I leave home"
   - Enable "Trigger on leaving"

3. **Test:**
   - Connect to home WiFi
   - Wait for location to stabilize (watch logs for "🏠 Home status check")
   - Disconnect from WiFi or move away (>100m from home)
   - **Expected:** Reminder notification appears

4. **Verify Logs:**
   ```
   📡 Connectivity changed: wifi
   🏠 Home status check: was=true, now=false
   🚪 LEAVING HOME detected
   🔔 TRIGGER ENGINE: Triggering Reminder
   ```

#### Test: Remind when arriving home
1. **Create Reminder:**
   - "Turn on lights when I arrive home"
   - Enable "Trigger on arriving"

2. **Test:**
   - Be away from home (not on home WiFi)
   - Connect to home WiFi or move within 100m of home
   - **Expected:** Reminder notification appears

### Scenario 2: Activity-Based Reminders

#### Test: Remind when walking
1. **Create Reminder:**
   - "Take a 10-minute walk" 
   - Set activity trigger: "Walking"

2. **Test:**
   - Start walking (move device at 1-5 km/h speed)
   - Watch logs for activity detection
   - **Expected:** After activity changes to "Walking", reminder triggers

3. **Verify Logs:**
   ```
   🏃 ActivityRecognition: Position update - speed: 3.5 km/h
   🔄 ActivityRecognition: ACTIVITY CHANGED
      Previous: Stationary
      New: Walking
   🏃 TriggerEngine: Activity changed: Stationary -> Walking
   🔔 TRIGGER ENGINE: Triggering Reminder
   ```

#### Test: Remind when driving
1. **Create Reminder:**
   - "Check parking meter"
   - Set activity trigger: "Driving"

2. **Test:**
   - Simulate driving (speed >60 km/h)
   - **Expected:** Reminder triggers when speed exceeds threshold

### Scenario 3: Device State Triggers

#### Test: Remind when charging starts
1. **Create Reminder:**
   - "Unplug phone at 80%"
   - Set trigger: "When charging starts"

2. **Test:**
   - Connect charger to device
   - Watch logs for battery state change
   - **Expected:** Reminder triggers immediately

3. **Verify Logs:**
   ```
   🔋 DeviceState: Method call: onBatteryStateChanged
   🔋 Battery changed: charging=true, level=45%
   🔋 DeviceStateService: Battery state changed
      Was charging: false
      Now charging: true
   🔔 TRIGGER ENGINE: Triggering Reminder (device_state: chargingStarted)
   ```

#### Test: Remind on screen unlock
1. **Create Reminder:**
   - "Review today's tasks"
   - Set trigger: "When screen unlocks"

2. **Test:**
   - Lock device
   - Unlock device (or resume app)
   - **Expected:** Reminder triggers on unlock

3. **Verify Logs:**
   ```
   📱 Screen unlock event sent to Flutter
   🔔 TRIGGER ENGINE: Triggering Reminder (device_state: screenUnlock)
   ```

### Scenario 4: Combined Context Triggers (Rule Engine)

#### Test: Multi-condition reminder
1. **Create Reminder:**
   - "Log your day"
   - Conditions:
     - Time: After 6 PM
     - Device state: Screen unlock
     - Activity: Stationary (not driving)

2. **Test:**
   - Wait until 6 PM
   - Unlock screen while stationary
   - **Expected:** Reminder triggers only when ALL conditions met

### Scenario 5: Pattern Learning & Adaptive Timing

#### Test: Learning optimal timing
1. **Create Reminder:**
   - "Take medicine"
   - Set for 9 AM daily
   - Enable "Smart Timing"

2. **Use the app normally:**
   - Complete reminder at 8:30 AM (early)
   - Skip reminder at 9 AM
   - Complete reminder at 9:15 AM (late)

3. **After 5+ completions:**
   - System learns your pattern
   - **Expected:** Reminder adjusts to 8:45 AM (optimal time)

4. **Verify Logs:**
   ```
   🧠 LEARNING SERVICE: Learning Optimal Timing
   🧠 Learned optimal timing: 8:45 (completion rate: 75%)
   🔔 Applying Smart Timing...
      Original time: 09:00
      Adjusted time: 08:45
   ```

### Scenario 6: Fallback Mechanisms

#### Test: Location unavailable fallback
1. **Setup:**
   - Disable location services
   - Create location-based reminder

2. **Expected Behavior:**
   - System logs warning
   - Falls back to time-based reminder if time specified
   - Shows notification explaining context unavailable

3. **Verify Logs:**
   ```
   ⚠️ TriggerEngine: Location permission not granted
   🔄 Falling back to time-based reminder
   ```

#### Test: Activity detection unavailable
1. **Setup:**
   - Deny location permission (required for activity)
   - Create activity-based reminder

2. **Expected:**
   - System detects permission denied
   - Falls back to time-based if available
   - Logs appropriate warning

### Scenario 7: Battery Optimization

#### Test: Background monitoring continues
1. **Setup:**
   - Disable battery optimization (Settings → Battery → Awarely)
   - Create location-based reminder
   - Minimize app

2. **Test:**
   - Move device location
   - **Expected:** Reminder still triggers in background

3. **Verify:**
   - Check logs continue even when app minimized
   - Notifications appear from background

## Advanced Testing

### Simulating Context Changes in Emulator

#### Simulate GPS Location:
```bash
# Set location via ADB
adb emu geo fix <longitude> <latitude>

# Example: Set to New York
adb emu geo fix -74.0060 40.7128

# Reset to original
adb emu geo fix reset
```

#### Simulate Battery State:
```bash
# Set battery level (0-100)
adb shell dumpsys battery set level 50

# Set charging state
adb shell dumpsys battery set ac 1  # Charging
adb shell dumpsys battery set ac 0  # Not charging

# Reset
adb shell dumpsys battery reset
```

#### Simulate WiFi Connection:
- Emulator Settings → WiFi → Connect/Disconnect
- Or use Android Studio's Extended Controls → WiFi

### Testing Activity Detection
Since activity is inferred from GPS speed:
1. Use ADB to simulate movement:
   ```bash
   # Simulate walking speed (3 km/h = ~0.83 m/s)
   # Update location every few seconds
   adb emu geo fix -74.0060 40.7128
   # Wait 5 seconds
   adb emu geo fix -74.0061 40.7129  # Moved ~100m
   ```

### Testing Pattern Learning
1. Create multiple reminders with smart timing
2. Complete/skip reminders at different times
3. Wait for 5+ events per reminder
4. Check analytics screen for learned patterns
5. Create new similar reminder - should auto-suggest optimal time

## Debugging Tips

### 1. Check Service Status
Look for these log tags:
- `TriggerEngine` - Context monitoring status
- `ActivityRecognition` - Activity detection
- `DeviceState` - Battery/screen state
- `HomeDetection` - Home location detection

### 2. Common Issues

**Issue: Reminders not triggering**
- Check permissions are granted
- Verify battery optimization disabled
- Check exact alarm permission (Android 12+)
- Review logs for errors

**Issue: Activity detection not working**
- Ensure location permission granted
- Check if GPS is enabled
- Verify device is moving (speed > threshold)

**Issue: Device state not detected**
- Verify native code compiled correctly
- Check method channel communication in logs
- Restart app after granting permissions

**Issue: Pattern learning not working**
- Ensure at least 5 completion events exist
- Check `learning_patterns` table in database
- Review LearningService logs

### 3. Database Inspection
```bash
# Access database on device
adb shell
run-as com.example.awarely
cd databases
sqlite3 awarely.db

# Check reminders
SELECT id, text, activityType, onArriveContext, onLeaveContext FROM reminders;

# Check context events
SELECT * FROM context_events ORDER BY triggerTime DESC LIMIT 10;

# Check learning patterns
SELECT * FROM learning_patterns;
```

## Performance Testing

### Battery Usage
Monitor battery impact:
```bash
# Check battery stats
adb shell dumpsys batterystats | grep awarely

# Monitor CPU usage
adb shell top -n 1 | grep awarely
```

### Memory Usage
```bash
# Check memory
adb shell dumpsys meminfo com.example.awarely
```

## Expected Log Output Examples

### Successful Trigger:
```
🔔═══════════════════════════════════════════════════
🔔 TRIGGER ENGINE: Triggering Reminder
🔔═══════════════════════════════════════════════════
   Reminder ID: abc123
   Text: "Take my keys"
   Context Type: location_leaving
   Time: 2024-01-15 08:30:00
✅ Trigger stats updated
✅ Context event created
📱 Showing notification...
✅ Notification shown
🔔═══════════════════════════════════════════════════
```

### Pattern Learning:
```
🧠═══════════════════════════════════════════════════
🧠 PATTERN LEARNING: Analyzing User Patterns
🧠═══════════════════════════════════════════════════
   Reminder ID: abc123
✅ Pattern learning complete
   Patterns discovered:
   - Completion rate: 0.75
   - Best context: location_arriving
   - Optimal hour: 18
   - Confidence: 0.85
```

## Next Steps

After testing, verify:
1. ✅ All trigger types work correctly
2. ✅ Fallbacks activate when context unavailable
3. ✅ Pattern learning improves over time
4. ✅ Battery usage is acceptable
5. ✅ Notifications appear reliably
6. ✅ Background monitoring continues

## Support

For issues, check:
1. Logs for error messages
2. Permission status in Settings
3. Battery optimization disabled
4. Exact alarm permission (Android 12+)
5. Location services enabled

