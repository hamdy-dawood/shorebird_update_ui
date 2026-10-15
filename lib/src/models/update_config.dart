import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Configuration for the update flow.
class ShorebirdUpdateConfig {
  const ShorebirdUpdateConfig({
    this.checkOnResume = true,
    this.autoDownload = true,
    this.showErrors = false,
    this.track = UpdateTrack.stable,
    this.simulatedDuration = const Duration(seconds: 12),
    this.dismissibleWhenReady = false,
    this.autoRestartCountdown,
  });

  /// Also check for a patch whenever the app returns to the foreground.
  final bool checkOnResume;

  /// Download automatically when a patch is found. If false, call
  /// `UpdateController.downloadUpdate()` yourself.
  final bool autoDownload;

  /// Show a dismissible error dialog when the download fails. If false,
  /// failures are only logged.
  final bool showErrors;

  /// Shorebird track to check/download from.
  final UpdateTrack track;

  /// Time the simulated progress takes to ease from 0 to ~90%.
  final Duration simulatedDuration;

  /// Show a "Later" button in the success state (both platforms).
  final bool dismissibleWhenReady;

  /// Android only: restart automatically after this delay. `null` = never.
  final Duration? autoRestartCountdown;
}
