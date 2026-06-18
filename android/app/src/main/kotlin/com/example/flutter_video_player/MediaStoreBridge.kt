package com.example.flutter_video_player

import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/// Bridges Android's MediaStore video index to Flutter.
///
/// Why this exists: walking the filesystem (Directory.listSync) is slow and
/// only sees files at the moment it runs, so newly downloaded videos don't
/// appear until a manual rescan. MediaStore is a system-maintained database
/// that Android keeps up to date automatically, so:
///   • `queryVideos` returns the whole index in one fast query, and
///   • a [ContentObserver] pushes `onChanged` the instant a video is added or
///     removed — the list updates live, no scan needed.
class MediaStoreBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    private val channel =
        MethodChannel(messenger, "com.example.flutter_video_player/media_store")
    private val mainHandler = Handler(Looper.getMainLooper())
    private var observer: ContentObserver? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "queryVideos" -> {
                    // Cursor queries can take a few ms on large libraries — run
                    // off the platform thread and reply back on it.
                    Thread {
                        val data = try { queryVideos() } catch (e: Exception) { emptyList() }
                        mainHandler.post { result.success(data) }
                    }.start()
                }
                "startWatching" -> { startWatching(); result.success(null) }
                "stopWatching" -> { stopWatching(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    private fun queryVideos(): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        val projection = arrayOf(
            MediaStore.Video.Media.DATA,           // absolute file path
            MediaStore.Video.Media.DISPLAY_NAME,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DATE_MODIFIED,  // epoch SECONDS
            MediaStore.Video.Media.DURATION,       // ms
        )
        val cursor = context.contentResolver.query(
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
            projection,
            null,
            null,
            "${MediaStore.Video.Media.DATE_MODIFIED} DESC",
        ) ?: return out

        cursor.use { c ->
            val dataIdx = c.getColumnIndexOrThrow(MediaStore.Video.Media.DATA)
            val nameIdx = c.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME)
            val sizeIdx = c.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)
            val dateIdx = c.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_MODIFIED)
            val durIdx = c.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)

            while (c.moveToNext()) {
                val path = c.getString(dataIdx) ?: continue
                val size = c.getLong(sizeIdx)
                if (size < 1024) continue // skip placeholder / truncated files
                out.add(
                    mapOf(
                        "path" to path,
                        "name" to (c.getString(nameIdx)
                            ?: path.substringAfterLast('/')),
                        "size" to size,
                        "modified" to c.getLong(dateIdx) * 1000L, // → ms
                        "duration" to c.getLong(durIdx),
                    )
                )
            }
        }
        return out
    }

    private fun startWatching() {
        if (observer != null) return
        val o = object : ContentObserver(mainHandler) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                channel.invokeMethod("onChanged", null)
            }
        }
        context.contentResolver.registerContentObserver(
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
            true, // notifyForDescendants — catch changes in any sub-path
            o,
        )
        observer = o
    }

    private fun stopWatching() {
        observer?.let { context.contentResolver.unregisterContentObserver(it) }
        observer = null
    }

    /// Called from MainActivity.onDestroy to release the observer + channel.
    fun dispose() {
        stopWatching()
        channel.setMethodCallHandler(null)
    }
}
