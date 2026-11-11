import 'dart:async';
import 'dart:io';

import 'package:atompay_mobile/core/storage/prefs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Where microphone (and, on iOS, speech recognition) permission stands.
/// Asked on the first mic tap, after the explainer (brief §10).
enum MicPermission {
  granted,

  /// Never asked: show the explainer, then the system prompt.
  notAsked,

  /// Refused; the mic now opens Permissions.
  denied,

  /// Only the phone's settings can turn it back on.
  blocked,
}

/// The phone's own speech recogniser, English only. Only the text leaves
/// the phone; no audio is uploaded or stored.
abstract class VoiceInput {
  Future<MicPermission> status();

  /// Shows the system prompt(s).
  Future<MicPermission> request();

  /// Starts listening. [onText] gets the live transcript, then the final
  /// one with `done: true`. Returns false when the phone can't listen.
  Future<bool> start({
    required void Function(String text, {required bool done}) onText,
    required VoidCallback onStopped,
  });

  /// Stops and keeps what was heard (a final `onText` follows).
  Future<void> stop();

  /// Stops and throws away what was heard.
  Future<void> cancel();
}

/// Reads one answer aloud on the phone.
abstract class Speaker {
  /// Completes when the reading ends or is stopped.
  Future<void> speak(String text);
  Future<void> stop();
}

final voiceInputProvider = Provider<VoiceInput>(
  (ref) => DeviceVoiceInput(ref.watch(sharedPreferencesProvider)),
);

final speakerProvider = Provider<Speaker>((ref) {
  final s = DeviceSpeaker();
  ref.onDispose(() => unawaited(s.stop()));
  return s;
});

class DeviceVoiceInput implements VoiceInput {
  new(this._prefs);

  final SharedPreferences _prefs;
  final _speech = SpeechToText();
  bool _ready = false;
  bool _cancelled = false;
  static const _askedKey = 'mic.asked';

  /// iOS needs speech recognition as well as the microphone.
  List<Permission> get _permissions => [
    Permission.microphone,
    if (Platform.isIOS) Permission.speech,
  ];

  @override
  Future<MicPermission> status() async {
    final all = [for (final p in _permissions) await p.status];
    if (all.every((s) => s.isGranted || s.isLimited)) {
      return MicPermission.granted;
    }
    if (all.any((s) => s.isPermanentlyDenied || s.isRestricted)) {
      return MicPermission.blocked;
    }
    return (_prefs.getBool(_askedKey) ?? false)
        ? MicPermission.denied
        : MicPermission.notAsked;
  }

  @override
  Future<MicPermission> request() async {
    await _prefs.setBool(_askedKey, true);
    final result = await _permissions.request();
    final all = result.values;
    if (all.every((s) => s.isGranted || s.isLimited)) {
      return MicPermission.granted;
    }
    if (all.any((s) => s.isPermanentlyDenied || s.isRestricted)) {
      return MicPermission.blocked;
    }
    return MicPermission.denied;
  }

  @override
  Future<bool> start({
    required void Function(String text, {required bool done}) onText,
    required VoidCallback onStopped,
  }) async {
    _cancelled = false;
    if (!_ready) {
      _ready = await _speech.initialize(
        onStatus: (s) {
          if (s == SpeechToText.doneStatus) onStopped();
        },
        onError: (_) => onStopped(),
      );
    }
    if (!_ready) return false;
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'en_US',
        // Stops by itself on a pause.
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 60),
        cancelOnError: true,
        listenMode: ListenMode.search,
      ),
      onResult: (r) {
        if (_cancelled) return;
        onText(r.recognizedWords, done: r.finalResult);
      },
    );
    return true;
  }

  @override
  Future<void> stop() async {
    if (_ready) await _speech.stop();
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    if (_ready) await _speech.cancel();
  }
}

class DeviceSpeaker implements Speaker {
  final _tts = FlutterTts();
  bool _set = false;

  @override
  Future<void> speak(String text) async {
    if (!_set) {
      _set = true;
      await _tts.setLanguage('en-US');
      await _tts.awaitSpeakCompletion(true);
    }
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    // Nothing to stop if the engine was never started.
    if (!_set) return;
    await _tts.stop();
  }
}
