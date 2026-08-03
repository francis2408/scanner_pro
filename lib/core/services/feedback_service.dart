import 'package:flutter/services.dart';

/// Manages audio beep and haptic feedback triggers upon scan detection events.
class FeedbackService {
  /// Emits success feedback (light/medium haptic vibration & system sound).
  static Future<void> playSuccessFeedback({
    bool sound = true,
    bool vibration = true,
  }) async {
    if (vibration) {
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {}
    }
    if (sound) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  /// Emits failure/error feedback (heavy haptic vibration).
  static Future<void> playFailureFeedback({
    bool sound = true,
    bool vibration = true,
  }) async {
    if (vibration) {
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {}
    }
    if (sound) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }
}
