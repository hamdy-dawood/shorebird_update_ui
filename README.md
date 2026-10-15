# shorebird_update_ui

Drop-in, **non-dismissible** OTA-update dialog for apps using
[Shorebird](https://shorebird.dev) code push. It downloads a patch with a
progress dialog, then restarts the app (Android) or tells the user to reopen it
(iOS). No Bloc/Riverpod/GetX — just `ChangeNotifier`.

## 3-step integration

**1. Add the dependency** (path or git):

```yaml
dependencies:
  shorebird_update_ui:
    path: packages/shorebird_update_ui
  # or: git: { url: https://github.com/you/repo, path: packages/shorebird_update_ui }
```

**2. Disable Shorebird's silent auto-update** in `shorebird.yaml`:

```yaml
auto_update: false
```

**3. Wrap your app** (create the controller once, e.g. top-level or in a State):

```dart
final updateController = UpdateController();

MaterialApp(
  builder: (context, child) =>
      ShorebirdUpdateListener(controller: updateController, child: child!),
);
```

It checks on app start and on resume, never concurrently.

## Config (`ShorebirdUpdateConfig`)

| Option | Default | Meaning |
|---|---|---|
| `checkOnResume` | `true` | Also check when the app returns to foreground |
| `autoDownload` | `true` | Download when a patch is found (else call `controller.downloadUpdate()`) |
| `showErrors` | `false` | Show a dismissible error dialog on failure (else log only) |
| `track` | `stable` | `UpdateTrack.stable / beta / staging` |
| `simulatedDuration` | 12 s | Time for fake progress to ease 0 → ~90 % |
| `dismissibleWhenReady` | `false` | Show a "Later" button when ready (closes dialog for the session) |
| `autoRestartCountdown` | `null` | Android: auto-restart after this delay (user can tap "Restart now") |

`UpdateController` also accepts `onBeforeRestart` (async, e.g. save data),
`onRestartPressed` (replaces the default restart), and `platform` (preview).
`ShorebirdUpdateListener` accepts `strings` (`UpdateStrings.en` / `.ar` / your
own; default follows the locale), `downloadingBuilder` and `readyBuilder`.

## Platform behaviour

| | Android | iOS |
|---|---|---|
| Download dialog | yes | yes |
| Ready state | message + **Restart now** button | message + 2-step hint (close from app switcher, reopen) |
| Restart | `restart_app` full process restart (`RestartMode.process`) | never called — iOS can't restart itself |
| `autoRestartCountdown` | supported | ignored |
| Restart fails | falls back to the "close and reopen" instructions | n/a |
| `dismissibleWhenReady` ("Later") | yes | yes |

The dialog is a `Stack` + `ModalBarrier` (no `showDialog`/Navigator): barrier
taps do nothing, the Android back button is swallowed while it is visible.

If a patch was downloaded earlier but the app wasn't restarted, the download is
skipped and the success state shows directly. If the download fails the dialog
closes (or shows a dismissible error with `showErrors`) and the app is never
blocked.

## ⚠️ Limitation: progress is simulated

Shorebird does **not** expose real download progress. The percentage is
time-based: it eases from 0 to ~90 % while `update()` runs (over
`simulatedDuration`; it holds at 90 % if the download is slower), then animates
to 100 % when `update()` completes. It is a UX indicator, not a byte count.

## Testing without a patch

`ShorebirdUpdater.isAvailable` is false in debug, so nothing happens. Use the
fake to preview the whole flow; it **never restarts** the app:

```dart
final updateController = kDebugMode
    ? FakeUpdateController(platform: TargetPlatform.android) // or iOS
    : UpdateController();
```

Tests: `flutter test` (controller state transitions + dialog widget tests).
