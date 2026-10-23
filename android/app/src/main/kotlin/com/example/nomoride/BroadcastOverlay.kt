package com.example.nomoride

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

/**
 * The in-app broadcast card, drawn over whatever app is open.
 * Colors match the Flutter card: gold #E6C27A on #0F0F14.
 *
 * Multiple broadcasts are queued: a new order never replaces an active card;
 * Decline / timeout advances to the next pending order.
 */
object BroadcastOverlay {
    private const val GOLD = 0xFFE6C27A.toInt()
    private const val CARD = 0xFF0F0F14.toInt()
    private const val INNER = 0xFF1E1E28.toInt()
    private const val CREAM = 0xFFF5E6C8.toInt()

    private val handler = Handler(Looper.getMainLooper())
    private var windowManager: WindowManager? = null
    private var root: View? = null
    private var tick: Runnable? = null
    private var current: Map<String, String>? = null
    private val queue = mutableListOf<Map<String, String>>()
    private var queueBadge: TextView? = null

    fun canDraw(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)

    fun show(context: Context, data: Map<String, String>) {
        if (!canDraw(context)) return
        handler.post { enqueueOnMain(context.applicationContext, data) }
    }

    fun hide() {
        handler.post { clearAllOnMain() }
    }

    /** Decline / swipe-away for one order; shows the next queued order if any. */
    fun dismissCurrent(context: Context, data: Map<String, String>) {
        handler.post {
            val app = context.applicationContext
            BroadcastAlertPlayer.cancel(app, data)
            val key = orderKey(data)
            queue.removeAll { key.isNotEmpty() && orderKey(it) == key }

            val isVisible = key.isEmpty() || orderKey(current) == key || current == null
            if (isVisible && root != null) {
                hideOnMain()
                current = null
            }

            if (root == null && current == null) {
                if (queue.isNotEmpty()) {
                    showNextOnMain(app)
                } else {
                    BroadcastAlertPlayer.stop()
                    MainActivity.notifyFlutterStopSound()
                }
            } else {
                refreshQueueBadge()
            }
        }
    }

    private fun enqueueOnMain(context: Context, data: Map<String, String>) {
        val key = orderKey(data)
        if (key.isNotEmpty()) {
            if (orderKey(current) == key) return
            if (queue.any { orderKey(it) == key }) return
        }
        if (root == null && current == null) {
            current = data
            showCardOnMain(context, data)
            return
        }
        queue.add(HashMap(data))
        refreshQueueBadge()
    }

    private fun showNextOnMain(context: Context) {
        if (queue.isEmpty()) {
            current = null
            BroadcastAlertPlayer.stop()
            return
        }
        val next = queue.removeAt(0)
        current = next
        showCardOnMain(context, next)
    }

    private fun clearAllOnMain() {
        queue.clear()
        current = null
        hideOnMain()
        BroadcastAlertPlayer.stop()
    }

    private fun showCardOnMain(context: Context, data: Map<String, String>) {
        hideOnMain()
        val app = context.applicationContext
        val wm = app.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val view = buildCard(app, data)
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            android.graphics.PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP
        }
        try {
            wm.addView(view, params)
            windowManager = wm
            root = view
            refreshQueueBadge()
        } catch (_: Exception) {
            BroadcastAlertPlayer.showNotification(app, data)
            current = null
            // Keep queued items; try next after a beat so one bad addView does not drop all.
            if (queue.isNotEmpty()) {
                handler.postDelayed({ showNextOnMain(app) }, 300)
            }
        }
    }

    private fun hideOnMain() {
        tick?.let { handler.removeCallbacks(it) }
        tick = null
        queueBadge = null
        val view = root ?: return
        try {
            windowManager?.removeView(view)
        } catch (_: Exception) {
        }
        root = null
        windowManager = null
    }

    private fun orderKey(data: Map<String, String>?): String {
        if (data == null) return ""
        return data["order_id"]
            ?: data["orderId"]
            ?: data["broadcast_id"]
            ?: data["broadcastId"]
            ?: data["orderNumber"]
            ?: data["order_number"]
            ?: ""
    }

    private fun refreshQueueBadge() {
        val pending = queue.size
        val badge = queueBadge ?: return
        if (pending <= 0) {
            badge.visibility = View.GONE
            return
        }
        badge.visibility = View.VISIBLE
        badge.text = "+$pending more"
    }

    private fun buildCard(context: Context, data: Map<String, String>): View {
        val isDelivery = (data["flow_type"] ?: data["flowType"] ?: "delivery")
            .equals("delivery", ignoreCase = true)
        val title = if (isDelivery) "NEW ORDER REQUEST" else "NEW RETURN REQUEST"
        val orderNo = data["orderNumber"] ?: data["order_number"] ?: ""
        val earning = data["formatted_earning"]
            ?: data["body"]?.substringAfter("Earning:", "")?.trim().orEmpty()
            .ifBlank { "₹${data["earning_amount"] ?: data["amount"] ?: ""}" }
        val distance = distanceLabel(data)
        var seconds = data["timer_seconds"]?.toIntOrNull()
            ?: data["timerSeconds"]?.toIntOrNull()
            ?: 60

        val scrim = LinearLayout(context).apply {
            setBackgroundColor(Color.TRANSPARENT)
            gravity = Gravity.TOP
            setPadding(dp(context, 16), statusBar(context) + dp(context, 8), dp(context, 16), 0)
        }

        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            background = round(CARD, dp(context, 22), GOLD, dp(context, 1))
            setPadding(dp(context, 16), dp(context, 14), dp(context, 16), dp(context, 16))
        }

        val header = LinearLayout(context).apply { gravity = Gravity.CENTER_VERTICAL }
        header.addView(pill(context, title, GOLD, 0x26E6C27A))
        val moreBadge = TextView(context).apply {
            setTextColor(CREAM)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            typeface = Typeface.DEFAULT_BOLD
            visibility = View.GONE
            setPadding(dp(context, 8), dp(context, 4), dp(context, 8), dp(context, 4))
            background = round(INNER, dp(context, 12), GOLD, dp(context, 1))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { marginStart = dp(context, 8) }
        }
        queueBadge = moreBadge
        header.addView(moreBadge)
        val timerView = TextView(context).apply {
            text = seconds.toString()
            setTextColor(GOLD)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            background = round(INNER, dp(context, 24), GOLD, dp(context, 2))
            layoutParams = LinearLayout.LayoutParams(dp(context, 42), dp(context, 42)).apply {
                marginStart = dp(context, 8)
            }
        }
        header.addView(View(context), LinearLayout.LayoutParams(0, 1, 1f))
        header.addView(timerView)
        card.addView(header)

        card.addView(space(context, 12))
        val info = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            background = round(INNER, dp(context, 14), 0x66E6C27A.toInt(), dp(context, 1))
            setPadding(dp(context, 12), dp(context, 10), dp(context, 12), dp(context, 10))
        }
        info.addView(column(context, "ORDER NUMBER", if (orderNo.isBlank()) "-" else "#$orderNo", Color.WHITE, Gravity.START), weight(1f))
        info.addView(column(context, "YOU EARN", earning, GOLD, Gravity.END))
        card.addView(info)

        if (distance.isNotBlank()) {
            card.addView(space(context, 12))
            card.addView(place(context, "DISTANCE", distance, GOLD))
        }

        card.addView(space(context, 16))
        // Swipe only on the body — not on Accept/Decline — so button clicks always fire.
        attachSwipe(card, context, data, excludeBottomDp = 56)
        val actions = LinearLayout(context)
        val decline = button(context, "Decline", Color.TRANSPARENT, CREAM, GOLD)
        decline.isClickable = true
        decline.isFocusable = true
        decline.setOnClickListener {
            BroadcastAlertPlayer.stop()
            MainActivity.notifyFlutterOverlayDeclined(data)
            dismissCurrent(context, data)
        }
        val accept = button(context, "Accept Order", GOLD, Color.BLACK, GOLD)
        accept.isClickable = true
        accept.isFocusable = true
        accept.setOnClickListener {
            // Accept this order; keep any remaining queue for when partner returns.
            BroadcastAlertPlayer.stop()
            handler.post {
                BroadcastAlertPlayer.cancel(context, data)
                hideOnMain()
                current = null
            }
            context.startActivity(BroadcastAlertPlayer.popupIntent(context, data, "accept"))
        }
        actions.addView(decline, weight(2f))
        actions.addView(View(context), LinearLayout.LayoutParams(dp(context, 10), 1))
        actions.addView(accept, weight(3f))
        card.addView(actions)

        scrim.addView(card, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT,
        ))

        val task = object : Runnable {
            override fun run() {
                seconds -= 1
                if (seconds <= 0) {
                    dismissCurrent(context, data)
                } else {
                    timerView.text = seconds.toString()
                    timerView.setTextColor(if (seconds <= 5) Color.RED else GOLD)
                    handler.postDelayed(this, 1000)
                }
            }
        }
        tick = task
        handler.postDelayed(task, 1000)
        return scrim
    }

    private fun attachSwipe(
        card: View,
        context: Context,
        data: Map<String, String>,
        excludeBottomDp: Int,
    ) {
        var downX = 0f
        var dragging = false
        val excludeBottom = dp(context, excludeBottomDp)
        card.setOnTouchListener { view, event ->
            // Let Accept / Decline receive their own clicks.
            if (event.y >= view.height - excludeBottom) {
                if (dragging) {
                    view.animate().translationX(0f).alpha(1f).setDuration(120).start()
                    dragging = false
                }
                return@setOnTouchListener false
            }
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX
                    dragging = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - downX
                    if (kotlin.math.abs(dx) > dp(context, 16)) dragging = true
                    if (dragging) {
                        view.translationX = dx
                        view.alpha = (1f - kotlin.math.abs(dx) / (view.width.coerceAtLeast(1) * 1.2f))
                            .coerceIn(0.35f, 1f)
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    val dx = view.translationX
                    val offScreen = view.width.coerceAtLeast(dp(context, 200)) * 1.3f
                    if (kotlin.math.abs(dx) > view.width * 0.28f) {
                        val target = if (dx > 0) offScreen else -offScreen
                        view.animate().translationX(target).alpha(0f).setDuration(180)
                            .withEndAction {
                                BroadcastAlertPlayer.stop()
                                dismissCurrent(context, data)
                            }
                            .start()
                    } else if (!dragging) {
                        view.animate().translationX(0f).alpha(1f).setDuration(80).start()
                        BroadcastAlertPlayer.stop()
                        handler.post {
                            BroadcastAlertPlayer.cancel(context, data)
                            hideOnMain()
                            current = null
                        }
                        context.startActivity(BroadcastAlertPlayer.popupIntent(context, data, "open"))
                    } else {
                        view.animate().translationX(0f).alpha(1f).setDuration(160).start()
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun distanceLabel(data: Map<String, String>): String {
        val preferred = data.entries.firstOrNull { (key, _) ->
            key.equals("kmd", true) ||
                key.endsWith(".kmd") ||
                key.endsWith("_kmd") ||
                key.contains("distance", true)
        }?.value
        extractKm(preferred)?.let { return it }
        for (value in data.values) {
            if (!value.contains("kmd", ignoreCase = true)) continue
            extractKm(value)?.let { return it }
        }
        return ""
    }

    private fun extractKm(raw: String?): String? {
        if (raw.isNullOrBlank()) return null
        val nested = Regex(
            """kmd[^0-9]{0,8}([0-9]+(?:\.[0-9]+)?)""",
            RegexOption.IGNORE_CASE,
        ).find(raw)?.groupValues?.getOrNull(1)
        val token = nested ?: raw.trim().trim('"').takeIf {
            it.matches(Regex("""[0-9]+(?:\.[0-9]+)?\s*km?""", RegexOption.IGNORE_CASE))
        }?.replace(Regex("""\s*km""", RegexOption.IGNORE_CASE), "")
        val number = token?.trim()?.toDoubleOrNull()
            ?: raw.trim().trim('"').toDoubleOrNull()
            ?: return null
        if (number <= 0) return null
        val text = if (number % 1.0 == 0.0) number.toInt().toString() else number.toString()
        return "${text}km"
    }

    private fun statusBar(context: Context): Int {
        val id = context.resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (id > 0) context.resources.getDimensionPixelSize(id) else dp(context, 24)
    }

    private fun pill(context: Context, text: String, color: Int, fill: Int): TextView {
        return TextView(context).apply {
            this.text = text
            setTextColor(color)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            typeface = Typeface.DEFAULT_BOLD
            letterSpacing = 0.04f
            setPadding(dp(context, 10), dp(context, 4), dp(context, 10), dp(context, 4))
            background = round(fill, dp(context, 20), color, dp(context, 1))
        }
    }

    private fun column(context: Context, label: String, value: String, valueColor: Int, gravity: Int): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            this.gravity = gravity
            addView(TextView(context).apply {
                text = label
                setTextColor(0x99F5E6C8.toInt())
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f)
                this.gravity = gravity
            })
            addView(TextView(context).apply {
                text = value
                setTextColor(valueColor)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, if (valueColor == GOLD) 18f else 14f)
                typeface = Typeface.DEFAULT_BOLD
                this.gravity = gravity
            })
        }
    }

    private fun place(context: Context, label: String, value: String, color: Int): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            addView(TextView(context).apply {
                text = label
                setTextColor(color)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
                typeface = Typeface.DEFAULT_BOLD
            })
            addView(TextView(context).apply {
                text = value
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                maxLines = 2
            })
        }
    }

    private fun button(context: Context, label: String, fill: Int, text: Int, stroke: Int): TextView {
        return TextView(context).apply {
            this.text = label
            setTextColor(text)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, dp(context, 12), 0, dp(context, 12))
            background = round(fill, dp(context, 12), stroke, dp(context, 1))
        }
    }

    private fun space(context: Context, dp: Int): View {
        return View(context).apply {
            layoutParams = LinearLayout.LayoutParams(1, dp(context, dp))
        }
    }

    private fun weight(value: Float): LinearLayout.LayoutParams {
        return LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, value)
    }

    private fun round(fill: Int, radius: Int, stroke: Int, strokeWidth: Int): GradientDrawable {
        return GradientDrawable().apply {
            setColor(fill)
            cornerRadius = radius.toFloat()
            setStroke(strokeWidth, stroke)
        }
    }

    private fun dp(context: Context, value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            context.resources.displayMetrics,
        ).toInt()
    }
}
