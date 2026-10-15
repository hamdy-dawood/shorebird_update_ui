/// The state of the update flow exposed by `UpdateController`.
sealed class UpdateState {
  const UpdateState();
}

/// Nothing is happening (or Shorebird is unavailable).
class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

/// Asking the Shorebird server whether a patch exists.
class UpdateChecking extends UpdateState {
  const UpdateChecking();
}

/// A patch is downloading. [progress] is simulated, in the range 0..1.
class UpdateDownloading extends UpdateState {
  const UpdateDownloading(this.progress);
  final double progress;
}

/// A patch is downloaded; the app must be restarted to apply it.
class UpdateRestartRequired extends UpdateState {
  const UpdateRestartRequired();
}

/// Check or download failed.
class UpdateError extends UpdateState {
  const UpdateError(this.error);
  final Object error;
}

/// The app is already on the latest patch.
class UpdateUpToDate extends UpdateState {
  const UpdateUpToDate();
}
