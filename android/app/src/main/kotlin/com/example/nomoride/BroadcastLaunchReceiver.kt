package com.example.nomoride

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * FCM delivers the order broadcast here even when Android has frozen the
 * Flutter process. The alert and its sound are raised by Android itself.
 */
class BroadcastLaunchReceiver : BroadcastReceiver() {

    @Suppress("DEPRECATION")
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "onReceive extras=${intent.extras?.keySet()?.joinToString()}")
        val data = flatten(intent.extras)
        val type = data["type"] ?: data["event"] ?: return
        if (type !in BROADCAST_TYPES) return
        Log.d(TAG, "Broadcast while foreground=${MainActivity.isInForeground}: $type")
        Log.d(TAG, "distance fields=" + data.entries
            .filter { it.key.contains("dist", true) || it.key.equals("kmd", true) || it.value.contains("kmd", true) }
            .joinToString { "${it.key}=${it.value}" })

        val app = context.applicationContext
        BroadcastAlertPlayer.ensureChannels(app)
        val url = data["broadcast_sound_url"] ?: data["sound_url"] ?: data["song_url"]
        val playDuration = data["playDurationSeconds"]?.toIntOrNull()
            ?: data["play_duration_seconds"]?.toIntOrNull()
            ?: data["duration"]?.toIntOrNull()
            ?: 30
        // Sound must last as long as the broadcast card/timer is on screen.
        val popupSeconds = data["timer_seconds"]?.toIntOrNull()
            ?: data["timerSeconds"]?.toIntOrNull()
            ?: playDuration
        val soundSeconds = maxOf(playDuration, popupSeconds)

        if (MainActivity.isInForeground) {
            // In-app Flutter sheet owns UI + sound while the partner is in NomoRide.
            return
        }

        BroadcastAlertPlayer.playOrExtend(app, url, soundSeconds)
        if (BroadcastOverlay.canDraw(app)) {
            BroadcastOverlay.show(app, data)
        } else {
            BroadcastAlertPlayer.showNotification(app, data)
        }
    }

    private fun flatten(extras: Bundle?): Map<String, String> {
        val data = LinkedHashMap<String, String>()
        if (extras == null) return data
        for (key in extras.keySet()) {
            if (key.startsWith("google.") || key.startsWith("gcm.") || key in SKIPPED_KEYS) {
                continue
            }
            putFlattened(data, key, extras.get(key))
        }
        return data
    }

    private fun putFlattened(into: MutableMap<String, String>, key: String, value: Any?) {
        when (value) {
            null -> return
            is Bundle -> {
                for (child in value.keySet()) {
                    putFlattened(into, "$key.$child", value.get(child))
                }
            }
            is Map<*, *> -> {
                value.forEach { (child, nested) ->
                    putFlattened(into, "$key.$child", nested)
                }
            }
            is String -> {
                into[key] = value
                val trimmed = value.trim()
                if (trimmed.startsWith("{") && trimmed.endsWith("}")) {
                    try {
                        putJson(into, key, JSONObject(trimmed))
                    } catch (_: Exception) {
                    }
                }
            }
            is JSONObject -> putJson(into, key, value)
            is JSONArray -> into[key] = value.toString()
            else -> into[key] = value.toString()
        }
    }

    private fun putJson(into: MutableMap<String, String>, key: String, json: JSONObject) {
        val names = json.keys()
        while (names.hasNext()) {
            val child = names.next()
            putFlattened(into, "$key.$child", json.opt(child))
        }
    }

    companion object {
        private const val TAG = "BroadcastLaunch"
        private val BROADCAST_TYPES = setOf("BROADCAST_ORDER", "ORDER_BROADCAST", "order:broadcast")
        private val SKIPPED_KEYS = setOf("from", "collapse_key", "androidx.content.wakelockid")
    }
}
