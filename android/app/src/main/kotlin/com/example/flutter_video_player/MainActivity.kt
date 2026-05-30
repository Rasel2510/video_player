package com.example.flutter_video_player

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.flutter_video_player/media_session"
    private var mediaSession: MediaSessionCompat? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setMetadata" -> {
                        val title = call.argument<String>("title") ?: ""
                        val duration = call.argument<Int>("duration")?.toLong() ?: 0L
                        ensureSession()
                        mediaSession?.setMetadata(
                            MediaMetadataCompat.Builder()
                                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
                                .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, duration)
                                .build()
                        )
                        mediaSession?.isActive = true
                        result.success(null)
                    }
                    "setPlaybackState" -> {
                        val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                        val position = call.argument<Int>("position")?.toLong() ?: 0L
                        val speed = call.argument<Double>("speed")?.toFloat() ?: 1.0f
                        val state = if (isPlaying)
                            PlaybackStateCompat.STATE_PLAYING
                        else
                            PlaybackStateCompat.STATE_PAUSED
                        mediaSession?.setPlaybackState(
                            PlaybackStateCompat.Builder()
                                .setState(state, position, speed)
                                .setActions(
                                    PlaybackStateCompat.ACTION_PLAY or
                                    PlaybackStateCompat.ACTION_PAUSE or
                                    PlaybackStateCompat.ACTION_PLAY_PAUSE or
                                    PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                                    PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                                    PlaybackStateCompat.ACTION_SEEK_TO
                                )
                                .build()
                        )
                        result.success(null)
                    }
                    "release" -> {
                        mediaSession?.isActive = false
                        mediaSession?.release()
                        mediaSession = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun ensureSession() {
        if (mediaSession != null) return
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT
        val pi = PendingIntent.getActivity(this, 0, intent, flags)
        mediaSession = MediaSessionCompat(this, "VideoPlayer").apply {
            setSessionActivity(pi)
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay()  { sendMediaAction("play") }
                override fun onPause() { sendMediaAction("pause") }
                override fun onSkipToNext()     { sendMediaAction("next") }
                override fun onSkipToPrevious() { sendMediaAction("previous") }
                override fun onSeekTo(pos: Long) { sendMediaSeek(pos) }
            })
        }
    }

    private fun sendMediaAction(action: String) {
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CHANNEL).invokeMethod("onMediaAction", action)
        }
    }

    private fun sendMediaSeek(posMs: Long) {
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CHANNEL).invokeMethod("onMediaSeek", posMs)
        }
    }

    override fun onDestroy() {
        mediaSession?.release()
        super.onDestroy()
    }
}
