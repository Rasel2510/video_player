package com.example.flutter_video_player

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.support.v4.media.MediaMetadataCompat
import androidx.media.session.MediaButtonReceiver
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.flutter_video_player/media_session"
    private val NOTIFICATION_ID = 1001
    private val NOTIFICATION_CHANNEL_ID = "nova_player_playback"

    private var mediaSession: MediaSessionCompat? = null

    // Mirror of Flutter-side playback state so we can rebuild the notification
    private var isPlaying = false
    private var videoTitle = "Nova Player"

    // ── Flutter engine setup ──────────────────────────────────────────────────

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannel()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "setMetadata" -> {
                        videoTitle = call.argument<String>("title")?.takeIf { it.isNotBlank() } ?: "Nova Player"
                        val durationMs = call.argument<Int>("duration")?.toLong() ?: 0L
                        ensureSession()
                        mediaSession?.setMetadata(
                            MediaMetadataCompat.Builder()
                                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, videoTitle)
                                .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, durationMs)
                                .build()
                        )
                        mediaSession?.isActive = true
                        postNotification()
                        result.success(null)
                    }

                    "setPlaybackState" -> {
                        isPlaying = call.argument<Boolean>("isPlaying") ?: false
                        val positionMs = call.argument<Int>("position")?.toLong() ?: 0L
                        val speed = call.argument<Double>("speed")?.toFloat() ?: 1.0f
                        val state = if (isPlaying) PlaybackStateCompat.STATE_PLAYING
                                    else          PlaybackStateCompat.STATE_PAUSED
                        mediaSession?.setPlaybackState(
                            PlaybackStateCompat.Builder()
                                .setState(state, positionMs, speed)
                                .setActions(
                                    PlaybackStateCompat.ACTION_PLAY              or
                                    PlaybackStateCompat.ACTION_PAUSE             or
                                    PlaybackStateCompat.ACTION_PLAY_PAUSE        or
                                    PlaybackStateCompat.ACTION_SKIP_TO_NEXT      or
                                    PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS  or
                                    PlaybackStateCompat.ACTION_SEEK_TO
                                )
                                .build()
                        )
                        postNotification()
                        result.success(null)
                    }

                    "release" -> {
                        cancelNotification()
                        mediaSession?.isActive = false
                        mediaSession?.release()
                        mediaSession = null
                        isPlaying = false
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ── Notification channel (required on API 26+) ────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Nova Player",
                NotificationManager.IMPORTANCE_LOW   // silent — no sound/vibration
            ).apply {
                description = "Media playback controls"
                setShowBadge(false)
            }
            notificationManager().createNotificationChannel(channel)
        }
    }

    // ── Post / cancel media-style notification ────────────────────────────────

    /**
     * Posts (or updates) the media notification that shows playback controls
     * on the notification panel and lock screen.
     *
     * Uses [MediaButtonReceiver.buildMediaButtonPendingIntent] so that button
     * taps are routed to the active [MediaSessionCompat.Callback] — no extra
     * BroadcastReceiver needed.
     */
    private fun postNotification() {
        val session = mediaSession ?: return

        val immutableFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_IMMUTABLE else 0

        // Tap the notification → open the app
        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentPi = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag
        )

        // Action buttons via MediaButtonReceiver (routes to session callback)
        val prevPi = MediaButtonReceiver.buildMediaButtonPendingIntent(
            this, PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS)
        val playPausePi = MediaButtonReceiver.buildMediaButtonPendingIntent(
            this, PlaybackStateCompat.ACTION_PLAY_PAUSE)
        val nextPi = MediaButtonReceiver.buildMediaButtonPendingIntent(
            this, PlaybackStateCompat.ACTION_SKIP_TO_NEXT)

        val playPauseIcon = if (isPlaying) android.R.drawable.ic_media_pause
                            else          android.R.drawable.ic_media_play
        val playPauseLabel = if (isPlaying) "Pause" else "Play"

        val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle(videoTitle)
            .setContentText(if (isPlaying) "Playing" else "Paused")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(contentPi)
            // ongoing=true while playing so user can't swipe away the notification
            .setOngoing(isPlaying)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSilent(true)
            // Three action buttons: previous | play-pause | next
            .addAction(android.R.drawable.ic_media_previous, "Previous", prevPi)
            .addAction(playPauseIcon, playPauseLabel, playPausePi)
            .addAction(android.R.drawable.ic_media_next, "Next", nextPi)
            .setStyle(
                MediaStyle()
                    .setMediaSession(session.sessionToken)
                    // compact view shows indices 0, 1, 2 → previous, play/pause, next
                    .setShowActionsInCompactView(0, 1, 2)
            )
            .build()

        notificationManager().notify(NOTIFICATION_ID, notification)
    }

    private fun cancelNotification() {
        notificationManager().cancel(NOTIFICATION_ID)
    }

    // ── MediaSessionCompat ────────────────────────────────────────────────────

    private fun ensureSession() {
        if (mediaSession != null) return

        val immutableFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_IMMUTABLE else 0
        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)
        val sessionActivityPi = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag
        )

        mediaSession = MediaSessionCompat(this, "NovaPlayer").apply {
            setSessionActivity(sessionActivityPi)
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay()             { dispatchToFlutter("play") }
                override fun onPause()            { dispatchToFlutter("pause") }
                override fun onSkipToNext()       { dispatchToFlutter("next") }
                override fun onSkipToPrevious()   { dispatchToFlutter("previous") }
                override fun onSeekTo(pos: Long)  { dispatchSeekToFlutter(pos) }
            })
        }
    }

    private fun dispatchToFlutter(action: String) {
        flutterEngine?.dartExecutor?.binaryMessenger?.let { m ->
            MethodChannel(m, CHANNEL).invokeMethod("onMediaAction", action)
        }
    }

    private fun dispatchSeekToFlutter(posMs: Long) {
        flutterEngine?.dartExecutor?.binaryMessenger?.let { m ->
            MethodChannel(m, CHANNEL).invokeMethod("onMediaSeek", posMs)
        }
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override fun onDestroy() {
        cancelNotification()
        mediaSession?.release()
        mediaSession = null
        super.onDestroy()
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun notificationManager() =
        getSystemService(NotificationManager::class.java)
}
