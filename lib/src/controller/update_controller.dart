import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/animation.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../models/update_config.dart';
import '../models/update_state.dart';
import 'update_backend.dart';

/// Drives the whole update flow. Plain [ChangeNotifier]; no state-management
/// package required.
///
/// Create one instance, pass it to `ShorebirdUpdateListener`, and call
/// [dispose] when you are done with it.
class UpdateController extends ChangeNotifier {
  UpdateController({
    this.config = const ShorebirdUpdateConfig(),
    UpdateBackend? backend,
    this.onBeforeRestart,
    this.onRestartPressed,
    this.platform,
  }) : _backend = backend ?? ShorebirdUpdateBackend();

  final ShorebirdUpdateConfig config;
  final UpdateBackend _backend;

  /// Called (and awaited) before the app restarts, so you can save data.
  final Future<void> Function()? onBeforeRestart;

  /// Fully replaces the default restart behaviour (`Restart.restartApp()`).
  final Future<void> Function()? onRestartPressed;

  /// Overrides the detected platform (useful for previews/tests).
  final TargetPlatform? platform;

  static const Duration _tick = Duration(milliseconds: 50);
  static const double _simulatedCeiling = 0.9;

  UpdateState _state = const UpdateIdle();
  bool _busy = false;
  bool _disposed = false;
  bool _dismissed = false; // "Later" pressed for this session
  bool _errorDismissed = false;
  bool _restarting = false;
  bool _restartFailed = false;
  bool _updateAvailable = false;
  Timer? _progressTimer;
  Timer? _countdownTimer;

  /// Seconds left before the automatic restart (Android), or null.
  final ValueNotifier<int?> countdown = ValueNotifier<int?>(null);

  UpdateState get state => _state;

  /// Simulated progress 0..1 (only meaningful while downloading).
  double get progress => switch (_state) {
        UpdateDownloading(:final progress) => progress,
        UpdateRestartRequired() => 1,
        _ => 0,
      };

  /// True when a patch was found but not downloaded (`autoDownload: false`).
  bool get updateAvailable => _updateAvailable;

  /// Whether the app can restart itself on this platform (Android only).
  bool get canRestart =>
      !kIsWeb && (platform ?? defaultTargetPlatform) == TargetPlatform.android;

  /// True when the user must be told to close and reopen the app manually
  /// (iOS, or the restart failed).
  bool get showManualInstructions => !canRestart || _restartFailed;

  bool get isRestarting => _restarting;

  /// Whether the blocking dialog should currently be on screen.
  bool get isDialogVisible => switch (_state) {
        UpdateDownloading() => true,
        UpdateRestartRequired() => !_dismissed,
        UpdateError() => config.showErrors && !_errorDismissed,
        _ => false,
      };

  /// Whether the visible dialog may be closed by the user.
  bool get isDismissible => switch (_state) {
        UpdateRestartRequired() => config.dismissibleWhenReady,
        UpdateError() => true,
        _ => false,
      };

  /// Checks for a patch and (if [ShorebirdUpdateConfig.autoDownload])
  /// downloads it. Safe to call repeatedly; never runs concurrently.
  Future<void> checkForUpdate() async {
    if (_busy || _disposed) return;
    if (_state is UpdateDownloading || _state is UpdateRestartRequired) return;
    if (!_backend.isAvailable) return;

    _busy = true;
    try {
      _errorDismissed = false;
      _setState(const UpdateChecking());
      final status = await _backend.checkForUpdate(config.track);
      switch (status) {
        case UpdateStatus.restartRequired:
          _onReady();
        case UpdateStatus.outdated:
          _updateAvailable = true;
          if (config.autoDownload) {
            await _download();
          } else {
            _setState(const UpdateIdle());
          }
        case UpdateStatus.upToDate:
          _setState(const UpdateUpToDate());
        case UpdateStatus.unavailable:
          _setState(const UpdateIdle());
      }
    } catch (e, st) {
      _fail(e, st);
    } finally {
      _busy = false;
    }
  }

  /// Manually start the download (for `autoDownload: false`).
  Future<void> downloadUpdate() async {
    if (_busy || _disposed || !_backend.isAvailable) return;
    if (_state is UpdateDownloading || _state is UpdateRestartRequired) return;
    _busy = true;
    try {
      await _download();
    } catch (e, st) {
      _fail(e, st);
    } finally {
      _busy = false;
    }
  }

  Future<void> _download() async {
    var elapsed = Duration.zero;
    _setState(const UpdateDownloading(0));
    _progressTimer = Timer.periodic(_tick, (_) {
      elapsed += _tick;
      final t = (elapsed.inMilliseconds / config.simulatedDuration.inMilliseconds)
          .clamp(0.0, 1.0);
      _setState(UpdateDownloading(
        _simulatedCeiling * Curves.easeOutCubic.transform(t),
      ));
    });
    try {
      await _backend.update(config.track);
    } finally {
      _progressTimer?.cancel();
      _progressTimer = null;
    }
    await _animateTo(1);
    _updateAvailable = false;
    _onReady();
  }

  Future<void> _animateTo(double target) {
    final from = progress;
    const total = Duration(milliseconds: 400);
    const step = Duration(milliseconds: 20);
    final completer = Completer<void>();
    var elapsed = Duration.zero;
    Timer.periodic(step, (timer) {
      elapsed += step;
      final t = (elapsed.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
      if (_disposed) {
        timer.cancel();
        completer.complete();
        return;
      }
      _setState(UpdateDownloading(from + (target - from) * t));
      if (t >= 1) {
        timer.cancel();
        completer.complete();
      }
    });
    return completer.future;
  }

  void _onReady() {
    _restartFailed = false;
    _setState(const UpdateRestartRequired());
    final wait = config.autoRestartCountdown;
    if (canRestart && wait != null && !_dismissed) {
      var seconds = wait.inSeconds < 1 ? 1 : wait.inSeconds;
      countdown.value = seconds;
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        seconds--;
        if (seconds <= 0) {
          timer.cancel();
          countdown.value = 0;
          restartNow();
        } else {
          countdown.value = seconds;
        }
      });
    }
  }

  void _fail(Object error, StackTrace stack) {
    _progressTimer?.cancel();
    _progressTimer = null;
    _log('Update failed: $error');
    if (error is! UpdateException) _log('$stack');
    _setState(UpdateError(error));
  }

  /// Restarts the app (Android only). Falls back to manual instructions if
  /// the restart fails. Does nothing on iOS.
  Future<void> restartNow() async {
    if (!canRestart || _restarting || _disposed) return;
    _restarting = true;
    _stopCountdown();
    notifyListeners();
    try {
      await onBeforeRestart?.call();
      if (onRestartPressed != null) {
        await onRestartPressed!();
      } else {
        await performRestart();
      }
    } catch (e) {
      _log('Restart failed: $e');
      _restartFailed = true;
    } finally {
      _restarting = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// The actual restart. Overridden by `FakeUpdateController`.
  ///
  /// Uses [RestartMode.process] (full process kill) so the new Shorebird patch
  /// is loaded; an engine-only restart would not apply it.
  @protected
  Future<void> performRestart() async {
    final result = await Restart.restartApp(mode: RestartMode.process);
    if (!result.success) {
      throw StateError('Restart failed: ${result.code} ${result.message}');
    }
  }

  /// Closes the dialog: "Later" (when `dismissibleWhenReady`) or the error
  /// dialog. Ignored when the dialog is not dismissible.
  void dismiss() {
    if (!isDismissible) return;
    if (_state is UpdateRestartRequired) {
      _dismissed = true;
      _stopCountdown();
    } else if (_state is UpdateError) {
      _errorDismissed = true;
      _state = const UpdateIdle();
    }
    notifyListeners();
  }

  /// Returns to idle and clears session flags (used by the fake controller).
  @protected
  void reset() {
    _stopCountdown();
    _dismissed = false;
    _errorDismissed = false;
    _restartFailed = false;
    _setState(const UpdateIdle());
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    countdown.value = null;
  }

  void _setState(UpdateState s) {
    if (_disposed) return;
    _state = s;
    notifyListeners();
  }

  void _log(String message) => debugPrint('[shorebird_update_ui] $message');

  @override
  void dispose() {
    _disposed = true;
    _progressTimer?.cancel();
    _countdownTimer?.cancel();
    countdown.dispose();
    super.dispose();
  }
}
