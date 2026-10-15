import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Thin seam over [ShorebirdUpdater] so the controller can be tested/faked.
abstract class UpdateBackend {
  bool get isAvailable;
  Future<UpdateStatus> checkForUpdate(UpdateTrack track);
  Future<void> update(UpdateTrack track);
}

/// Real implementation backed by `package:shorebird_code_push`.
class ShorebirdUpdateBackend implements UpdateBackend {
  ShorebirdUpdateBackend([ShorebirdUpdater? updater])
      : _updater = updater ?? ShorebirdUpdater();

  final ShorebirdUpdater _updater;

  @override
  bool get isAvailable => _updater.isAvailable;

  @override
  Future<UpdateStatus> checkForUpdate(UpdateTrack track) =>
      _updater.checkForUpdate(track: track);

  @override
  Future<void> update(UpdateTrack track) => _updater.update(track: track);
}
