package ph.tabangnow.dao

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private fun extractResetLink(intent: Intent?): String? {
        val link = intent?.data ?: return null
        if (link.scheme != "https") return null
        val path = link.pathSegments ?: return null
        if (path.size != 2 || path[0] != "reset-password" || path[1].isBlank()) return null
        if (link.getQueryParameter("email").isNullOrBlank()) return null
        return link.toString()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractResetLink(intent)?.let { url ->
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, "tabangnow/password_reset_links")
                    .invokeMethod("onResetLink", url)
            }
        }
    }
    companion object {
        private const val notificationChannelId = "tabangnow_notifications_v4"
        private const val notificationFeedbackChannel =
            "tabangnow/notification_feedback"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "tabangnow/password_reset_links",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialResetLink" -> result.success(extractResetLink(intent))
                else -> result.notImplemented()
            }
        }
        createNotificationChannel()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            notificationFeedbackChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "playNotificationFeedback" -> {
                    playNotificationFeedback()
                    result.success(null)
                }


                else -> result.notImplemented()
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val notificationManager = getSystemService(NotificationManager::class.java)

        if (notificationManager.getNotificationChannel(notificationChannelId) != null) {
            return
        }

        val notificationSound = Uri.parse(
            "android.resource://$packageName/raw/tabangnow_notification_v4"
        )
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .build()

        val channel = NotificationChannel(
            notificationChannelId,
            "TabangNow Notifications",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "TabangNow notifications with enhanced sound and vibration"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 850, 250, 850, 250, 1200)
            setSound(notificationSound, audioAttributes)
            setShowBadge(true)
        }

        notificationManager.createNotificationChannel(channel)
    }


    private fun playNotificationFeedback() {
        try {
            val player = MediaPlayer.create(this, R.raw.tabangnow_notification_v4)
            player?.setOnCompletionListener { completed ->
                completed.release()
            }
            player?.start()
        } catch (_: Throwable) {
            // Flutter still retains its fallback notification feedback.
        }

        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
                    as VibratorManager
                manager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(
                    VibrationEffect.createWaveform(
                        longArrayOf(0, 850, 250, 850, 250, 1200),
                        -1,
                    ),
                )
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(longArrayOf(0, 850, 250, 850, 250, 1200), -1)
            }
        } catch (_: Throwable) {
            // Notification feedback must never break the app.
        }
    }
}
