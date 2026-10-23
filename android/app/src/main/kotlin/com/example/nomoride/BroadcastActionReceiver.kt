package com.example.nomoride

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Decline from the heads-up notification. The app stays in the background;
 * the alert and its sound are dismissed (or advanced to the next queued order).
 */
class BroadcastActionReceiver : BroadcastReceiver() {

    @Suppress("DEPRECATION", "UNCHECKED_CAST")
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_DECLINE) return
        val data = intent.getSerializableExtra(MainActivity.EXTRA_BROADCAST) as? HashMap<String, String>
            ?: return
        // Same path as overlay Decline: stop sound when queue empties, else show next.
        BroadcastAlertPlayer.stop()
        MainActivity.notifyFlutterOverlayDeclined(data)
        BroadcastOverlay.dismissCurrent(context.applicationContext, data)
        BroadcastAlertPlayer.cancel(context.applicationContext, data)
    }

    companion object {
        const val ACTION_DECLINE = "com.nomoride.BROADCAST_DECLINE"
    }
}
