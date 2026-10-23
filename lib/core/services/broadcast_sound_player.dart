import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Plays the `broadcast_sound_url` sent with an order broadcast.
class BroadcastSoundPlayer {
  BroadcastSoundPlayer._();

  static AudioPlayer? _player;
  static String? _playingUrl;
  static Timer? _stopTimer;

  static bool get isPlaying => _playingUrl != null;

  static const _channel = MethodChannel('com.nomoride/broadcast_launch');

  /// Loops [url] for [durationSeconds] (popup/timer length), or plays it
  /// once when no duration is given. Returns false when there is nothing to
  /// play or playback failed, so the caller can fall back to the system alert.
  static Future<bool> play(String? url, {int? durationSeconds}) async {
    final source = url?.trim();
    if (source == null || source.isEmpty) return false;

    final seconds = durationSeconds != null && durationSeconds > 0
        ? durationSeconds
        : null;

    // Same clip already looping for at least this long — keep it.
    if (_playingUrl == source &&
        seconds != null &&
        _stopTimer?.isActive == true) {
      return true;
    }

    // Take over from the native player so duration matches the popup timer.
    await _stopNative();

    try {
      final player = _player ??= AudioPlayer();
      _stopTimer?.cancel();
      await player.stop();
      await player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.notificationRingtone,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
        ),
      );
      final limited = seconds != null;
      await player.setReleaseMode(limited ? ReleaseMode.loop : ReleaseMode.stop);
      _playingUrl = source;
      await player.play(UrlSource(source));
      if (limited) {
        _stopTimer = Timer(Duration(seconds: seconds), stop);
      } else {
        unawaited(player.onPlayerComplete.first.then((_) {
          if (_playingUrl == source) _playingUrl = null;
        }));
      }
      return true;
    } catch (e) {
      debugPrint('[BroadcastSound] Could not play $source: $e');
      _playingUrl = null;
      return false;
    }
  }

  static Future<void> _stopNative() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('stopNativeSound');
    } catch (_) {}
  }

  static Future<void> stop() async {
    _stopTimer?.cancel();
    _stopTimer = null;
    await _stopNative();
    if (_playingUrl == null && _player == null) return;
    _playingUrl = null;
    try {
      await _player?.stop();
    } catch (e) {
      debugPrint('[BroadcastSound] Stop failed: $e');
    }
  }
}
