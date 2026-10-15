import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'update_backend.dart';
import 'update_controller.dart';

class _FakeBackend implements UpdateBackend {
  _FakeBackend(this.checkDelay, this.downloadDuration);
  final Duration checkDelay;
  final Duration downloadDuration;

  @override
  bool get isAvailable => true;

  @override
  Future<UpdateStatus> checkForUpdate(UpdateTrack track) async {
    await Future<void>.delayed(checkDelay);
    return UpdateStatus.outdated;
  }

  @override
  Future<void> update(UpdateTrack track) =>
      Future<void>.delayed(downloadDuration);
}

/// Runs the full UI flow (checking -> downloading -> ready) without a real
/// patch. It NEVER restarts the app: pressing "Restart now" just closes the
/// dialog and re-arms the simulation for the next resume/check.
class FakeUpdateController extends UpdateController {
  FakeUpdateController({
    super.config,
    super.onBeforeRestart,
    super.platform,
    Duration checkDelay = const Duration(seconds: 1),
    Duration downloadDuration = const Duration(seconds: 6),
  }) : super(backend: _FakeBackend(checkDelay, downloadDuration));

  /// How many times a (fake) restart was requested.
  int fakeRestartCount = 0;

  @override
  Future<void> performRestart() async {
    fakeRestartCount++;
    reset();
  }
}
