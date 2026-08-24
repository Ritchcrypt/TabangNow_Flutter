package ph.tabangnow.dao

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
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
    companion object {
        private const val notificationChannelId = "tabangnow_notifications_v2"
        private const val notificationFeedbackChannel =
            "tabangnow/notification_feedback"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
            "android.resource://$packageName/raw/tabangnow_notification"
        )
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .build()

        val channel = NotificationChannel(
            notificationChannelId,
            "TabangNow Notifications",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "TabangNow announcements and operational notifications"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 320, 160, 320)
            setSound(notificationSound, audioAttributes)
            setShowBadge(true)
        }

        notificationManager.createNotificationChannel(channel)
    }

    private fun playNotificationFeedback() {
        try {
            val player = MediaPlayer.create(this, R.raw.tabangnow_notification)
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
                        longArrayOf(0, 320, 160, 320),
                        -1,
                    ),
                )
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(longArrayOf(0, 320, 160, 320), -1)
            }
        } catch (_: Throwable) {
            // Notification feedback must never break the app.
        }
    }
}
