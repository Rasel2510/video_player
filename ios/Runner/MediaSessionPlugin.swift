import AVFoundation
import Flutter
import MediaPlayer
import UIKit

/// iOS counterpart to the Android MediaSession in MainActivity.kt.
///
/// Speaks the same method channel ("…/media_session") and the same message
/// shapes the Dart `MediaSessionService` already sends, so no Dart changes are
/// needed. It drives:
///   • Control Center / lock-screen "Now Playing" info (`MPNowPlayingInfoCenter`)
///   • the remote transport commands (`MPRemoteCommandCenter`) → back to Dart
///   • the audio session (`AVAudioSession`) so playback continues in the
///     background (paired with the `audio` UIBackgroundMode in Info.plist).
public class MediaSessionPlugin: NSObject, FlutterPlugin {
  private static let channelName = "com.example.flutter_video_player/media_session"

  private var channel: FlutterMethodChannel?

  private var title = "Video Player"
  private var durationSec: Double = 0
  private var positionSec: Double = 0
  private var rate: Double = 1.0
  private var isPlaying = false

  private var artwork: MPMediaItemArtwork?
  private var artPath: String?

  private var commandsConfigured = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = MediaSessionPlugin()
    let channel = FlutterMethodChannel(
      name: channelName, binaryMessenger: registrar.messenger())
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setMetadata":
      if let args = call.arguments as? [String: Any] {
        let t = (args["title"] as? String) ?? ""
        title = t.isEmpty ? "Video Player" : t
        durationSec = millisToSeconds(args["duration"])
        loadArtwork(args["artPath"] as? String)
      }
      activateAudioSession()
      configureCommands()
      updateNowPlaying()
      result(nil)

    case "setPlaybackState":
      if let args = call.arguments as? [String: Any] {
        isPlaying = (args["isPlaying"] as? Bool) ?? false
        positionSec = millisToSeconds(args["position"])
        if let speed = args["speed"] as? NSNumber { rate = speed.doubleValue }
      }
      activateAudioSession()
      configureCommands()
      updateNowPlaying()
      result(nil)

    case "release":
      clearNowPlaying()
      result(nil)

    case "moveTaskToBack":
      // iOS does not allow an app to background itself programmatically.
      // Background audio simply continues via the active AVAudioSession +
      // the `audio` UIBackgroundMode, so this is a no-op here.
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // ── Audio session ──────────────────────────────────────────────────────────

  private func activateAudioSession() {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playback, mode: .moviePlayback)
      try session.setActive(true)
    } catch {
      // Non-fatal — playback still works foregrounded.
    }
  }

  // ── Remote commands → Dart ─────────────────────────────────────────────────

  private func configureCommands() {
    if commandsConfigured { return }
    commandsConfigured = true

    let center = MPRemoteCommandCenter.shared()

    center.playCommand.isEnabled = true
    center.playCommand.addTarget { [weak self] _ in
      self?.dispatch("play"); return .success
    }
    center.pauseCommand.isEnabled = true
    center.pauseCommand.addTarget { [weak self] _ in
      self?.dispatch("pause"); return .success
    }
    center.togglePlayPauseCommand.isEnabled = true
    center.togglePlayPauseCommand.addTarget { [weak self] _ in
      self?.dispatch(self?.isPlaying == true ? "pause" : "play"); return .success
    }
    center.nextTrackCommand.isEnabled = true
    center.nextTrackCommand.addTarget { [weak self] _ in
      self?.dispatch("next"); return .success
    }
    center.previousTrackCommand.isEnabled = true
    center.previousTrackCommand.addTarget { [weak self] _ in
      self?.dispatch("previous"); return .success
    }
    center.changePlaybackPositionCommand.isEnabled = true
    center.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let e = event as? MPChangePlaybackPositionCommandEvent else {
        return .commandFailed
      }
      self?.channel?.invokeMethod(
        "onMediaSeek", arguments: Int(e.positionTime * 1000))
      return .success
    }
  }

  private func dispatch(_ action: String) {
    channel?.invokeMethod("onMediaAction", arguments: action)
  }

  // ── Now Playing info ───────────────────────────────────────────────────────

  private func updateNowPlaying() {
    var info: [String: Any] = [
      MPMediaItemPropertyTitle: title,
      MPMediaItemPropertyPlaybackDuration: durationSec,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: positionSec,
      MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? rate : 0.0,
    ]
    if let artwork = artwork {
      info[MPMediaItemPropertyArtwork] = artwork
    }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    if #available(iOS 13.0, *) {
      MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }
  }

  private func clearNowPlaying() {
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    if #available(iOS 13.0, *) {
      MPNowPlayingInfoCenter.default().playbackState = .stopped
    }
    do {
      try AVAudioSession.sharedInstance().setActive(
        false, options: .notifyOthersOnDeactivation)
    } catch {}
  }

  // ── Artwork ────────────────────────────────────────────────────────────────

  private func loadArtwork(_ path: String?) {
    if path == artPath { return }
    artPath = path
    guard let path = path, let image = UIImage(contentsOfFile: path) else {
      artwork = nil
      return
    }
    artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Dart sends durations/positions as integer milliseconds; coerce safely.
  private func millisToSeconds(_ value: Any?) -> Double {
    guard let n = value as? NSNumber else { return 0 }
    return n.doubleValue / 1000.0
  }
}
