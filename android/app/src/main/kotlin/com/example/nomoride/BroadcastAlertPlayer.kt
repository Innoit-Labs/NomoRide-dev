package com.example.nomoride

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Plays a broadcast's sound URL and posts the heads-up alert from Android,
 * so both still happen after the app process was frozen in the background.
 */
object BroadcastAlertPlayer {
    private const val TAG = "BroadcastAlert"
    const val CHANNEL_ID = "nomoride_order_alerts"
    private const val BACKEND_CHANNEL_ID = "high_importance_channel"

    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var stopRunnable: Runnable? = null

    /** Bumped on every [stop]/invalidates in-flight prepareAsync callbacks. */
    @Volatile
    private var playGeneration = 0

    @Volatile
    private var playingUntilElapsed = 0L

    fun isPlaying(): Boolean = SystemClock.elapsedRealtime() < playingUntilElapsed

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        // FCM auto-created this channel at low importance the first time a
        // broadcast arrived. Importance can only go up after a delete.
        val existing = manager.getNotificationChannel(BACKEND_CHANNEL_ID)
        if (existing != null && existing.importance < NotificationManager.IMPORTANCE_HIGH) {
            manager.deleteNotificationChannel(BACKEND_CHANNEL_ID)
        }
        manager.createNotificationChannel(channel(BACKEND_CHANNEL_ID, "Order broadcasts"))
        manager.createNotificationChannel(channel(CHANNEL_ID, "New order requests"))
    }

    private fun channel(id: String, name: String): NotificationChannel {
        return NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Alerts for new delivery order requests"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 400, 200, 400)
            lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
        }
    }

    fun notificationId(data: Map<String, String>): Int {
        val key = data["order_id"] ?: data["orderId"] ?: data["orderNumber"] ?: data["order_number"]
        return key?.hashCode() ?: 1001
    }

    fun showNotification(context: Context, data: Map<String, String>) {
        ensureChannels(context)
        val title = data["title"]?.takeIf { it.isNotBlank() } ?: "New Order Broadcast Available"
        val summary = data["body"]?.takeIf { it.isNotBlank() } ?: "New order request"
        val pickup = data["pickup_address"] ?: data["pickupAddress"]
        val drop = data["delivery_address"] ?: data["deliveryAddress"]
        val details = buildString {
            append(summary)
            if (!pickup.isNullOrBlank()) append("\nPickup: $pickup")
            if (!drop.isNullOrBlank()) append("\nDrop: $drop")
        }
        val id = notificationId(data)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val open = pendingActivity(context, id, data, "open")
        val accept = pendingActivity(context, id + 1, data, "accept")
        val decline = PendingIntent.getBroadcast(
            context,
            id + 2,
            Intent(context, BroadcastActionReceiver::class.java).apply {
                action = BroadcastActionReceiver.ACTION_DECLINE
                putExtra(MainActivity.EXTRA_BROADCAST, HashMap(data))
            },
            flags,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(summary)
            .setStyle(NotificationCompat.BigTextStyle().bigText(details))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(open)
            .setFullScreenIntent(open, true)
            .addAction(0, "Decline", decline)
            .addAction(0, "Accept", accept)
            .setVibrate(longArrayOf(0, 400, 200, 400))
            .build()
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.notify(id, notification)
    }

    fun cancel(context: Context, data: Map<String, String>) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.cancel(notificationId(data))
    }

    fun popupIntent(context: Context, data: Map<String, String>, action: String = "open"): Intent {
        val payload = HashMap(data)
        payload["launch_action"] = action
        return Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(MainActivity.EXTRA_BROADCAST, payload)
        }
    }

    private fun pendingActivity(
        context: Context,
        requestCode: Int,
        data: Map<String, String>,
        action: String,
    ): PendingIntent {
        val payload = HashMap(data)
        payload["launch_action"] = action
        val launch = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(MainActivity.EXTRA_BROADCAST, payload)
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * Starts alert sound, or extends the existing one when another broadcast
     * arrives while the first is still ringing.
     */
    fun playOrExtend(context: Context, url: String?, durationSeconds: Int) {
        if (isPlaying() && player != null) {
            extend(durationSeconds)
            return
        }
        play(context, url, durationSeconds)
    }

    fun extend(durationSeconds: Int) {
        val seconds = if (durationSeconds > 0) durationSeconds else 30
        stopRunnable?.let { handler.removeCallbacks(it) }
        playingUntilElapsed = SystemClock.elapsedRealtime() + seconds * 1000L
        val stopTask = Runnable { stop() }
        stopRunnable = stopTask
        handler.postDelayed(stopTask, seconds * 1000L)
        Log.d(TAG, "Extended sound for ${seconds}s")
    }

    fun play(context: Context, url: String?, durationSeconds: Int) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            handler.post { play(context, url, durationSeconds) }
            return
        }
        val source = url?.trim().orEmpty()
        if (source.isEmpty()) return
        stopInternal(notifyFlutter = false)
        val generation = ++playGeneration
        val seconds = if (durationSeconds > 0) durationSeconds else 30
        playingUntilElapsed = SystemClock.elapsedRealtime() + seconds * 1000L

        val app = context.applicationContext
        val lock = (app.getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "nomoride:broadcast_sound")
        lock.acquire(seconds * 1000L + 5_000L)
        wakeLock = lock

        val media = MediaPlayer()
        player = media
        media.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
        )
        media.setWakeMode(app, PowerManager.PARTIAL_WAKE_LOCK)
        media.isLooping = true
        media.setOnPreparedListener { prepared ->
            // Decline/stop may have run while prepareAsync was in flight.
            if (generation != playGeneration || player !== prepared) {
                try {
                    prepared.release()
                } catch (_: Exception) {
                }
                return@setOnPreparedListener
            }
            try {
                prepared.start()
            } catch (e: Exception) {
                Log.e(TAG, "Could not start prepared sound", e)
            }
        }
        media.setOnErrorListener { _, what, extra ->
            Log.e(TAG, "Sound failed ($what/$extra): $source")
            true
        }
        try {
            media.setDataSource(source)
            media.prepareAsync()
            Log.d(TAG, "Playing $source for ${seconds}s (gen=$generation)")
        } catch (e: Exception) {
            Log.e(TAG, "Could not start sound: $source", e)
            stopInternal(notifyFlutter = false)
            return
        }
        val stopTask = Runnable { stop() }
        stopRunnable = stopTask
        handler.postDelayed(stopTask, seconds * 1000L)
    }

    fun stop() {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            handler.postAtFrontOfQueue { stopInternal(notifyFlutter = true) }
            return
        }
        stopInternal(notifyFlutter = true)
    }

    /** Called from Flutter — do not bounce stopBroadcastSound back to Dart. */
    fun stopFromFlutter() {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            handler.postAtFrontOfQueue { stopInternal(notifyFlutter = false) }
            return
        }
        stopInternal(notifyFlutter = false)
    }

    private fun stopInternal(notifyFlutter: Boolean) {
        playGeneration++
        stopRunnable?.let { handler.removeCallbacks(it) }
        stopRunnable = null
        playingUntilElapsed = 0L
        val media = player
        player = null
        media?.setOnPreparedListener(null)
        media?.setOnCompletionListener(null)
        media?.setOnErrorListener(null)
        media?.run {
            try {
                isLooping = false
            } catch (_: Exception) {
            }
            try {
                if (isPlaying) pause()
            } catch (_: Exception) {
            }
            try {
                stop()
            } catch (_: Exception) {
            }
            try {
                reset()
            } catch (_: Exception) {
            }
            try {
                release()
            } catch (_: Exception) {
            }
        }
        wakeLock?.run {
            try {
                if (isHeld) release()
            } catch (_: Exception) {
            }
        }
        wakeLock = null
        Log.d(TAG, "Sound stopped")
        if (notifyFlutter) {
            MainActivity.notifyFlutterStopSound()
        }
    }
}
