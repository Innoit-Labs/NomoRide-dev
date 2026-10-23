package com.example.nomoride

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var channel: MethodChannel? = null
    private var pendingBroadcast: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        BroadcastAlertPlayer.ensureChannels(this)
        pendingBroadcast = readBroadcast(intent)
        pendingBroadcast?.let {
            openedOverOtherApp = true
            BroadcastAlertPlayer.stop()
            BroadcastAlertPlayer.cancel(this, it)
            BroadcastOverlay.dismissCurrent(this, it)
        }
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePendingBroadcast" -> {
                        result.success(pendingBroadcast)
                        pendingBroadcast = null
                    }
                    "canDrawOverlays" -> result.success(canDrawOverlays())
                    "isNativeSoundPlaying" -> result.success(BroadcastAlertPlayer.isPlaying())
                    "stopNativeSound" -> {
                        BroadcastAlertPlayer.stopFromFlutter()
                        result.success(null)
                    }
                    "setOnlineService" -> {
                        val online = call.argument<Boolean>("online") == true
                        if (online) {
                            OnlineForegroundService.start(this@MainActivity)
                        } else {
                            OnlineForegroundService.stop(this@MainActivity)
                        }
                        result.success(null)
                    }
                    "consumeOpenedOverOtherApp" -> {
                        result.success(openedOverOtherApp)
                        openedOverOtherApp = false
                    }
                    "moveToBack" -> {
                        moveTaskToBack(true)
                        result.success(null)
                    }
                    "openOverlaySettings" -> {
                        openOverlaySettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        flutterChannel = channel
    }

    override fun onDestroy() {
        if (flutterChannel === channel) flutterChannel = null
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readBroadcast(intent)?.let { data ->
            if (!isInForeground) openedOverOtherApp = true
            BroadcastAlertPlayer.stop()
            BroadcastAlertPlayer.cancel(this, data)
            BroadcastOverlay.dismissCurrent(this, data)
            channel?.invokeMethod("broadcastLaunched", data)
        }
    }

    override fun onResume() {
        super.onResume()
        isInForeground = true
    }

    override fun onPause() {
        isInForeground = false
        super.onPause()
    }

    @Suppress("UNCHECKED_CAST", "DEPRECATION")
    private fun readBroadcast(intent: Intent?): Map<String, String>? {
        val data = intent?.getSerializableExtra(EXTRA_BROADCAST) as? HashMap<String, String>
        intent?.removeExtra(EXTRA_BROADCAST)
        return data
    }

    private fun canDrawOverlays(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)

    private fun openOverlaySettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        startActivity(
            Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName"),
            ),
        )
    }

    companion object {
        const val CHANNEL = "com.nomoride/broadcast_launch"
        const val EXTRA_BROADCAST = "nomoride_broadcast"

        private val mainHandler = Handler(Looper.getMainLooper())

        @Volatile
        var isInForeground = false

        @Volatile
        var openedOverOtherApp = false

        @Volatile
        private var flutterChannel: MethodChannel? = null

        /** Ask Flutter to stop its AudioPlayer (overlay Decline cannot reach it otherwise). */
        fun notifyFlutterStopSound() {
            mainHandler.post {
                try {
                    flutterChannel?.invokeMethod("stopBroadcastSound", null)
                } catch (_: Exception) {
                }
            }
        }

        fun notifyFlutterOverlayDeclined(data: Map<String, String>) {
            mainHandler.post {
                try {
                    flutterChannel?.invokeMethod("overlayDeclined", HashMap(data))
                } catch (_: Exception) {
                }
            }
        }
    }
}
