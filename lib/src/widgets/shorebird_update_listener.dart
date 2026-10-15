import 'package:flutter/material.dart';

import '../controller/update_controller.dart';
import '../l10n/update_strings.dart';
import 'update_dialog.dart';

/// Place in `MaterialApp.builder`:
///
/// ```dart
/// builder: (context, child) =>
///     ShorebirdUpdateListener(controller: controller, child: child!),
/// ```
///
/// Triggers checks on start/resume and shows a non-dismissible modal dialog
/// above whatever screen is open (a plain [Stack] — no `showDialog`, no
/// Navigator).
class ShorebirdUpdateListener extends StatefulWidget {
  const ShorebirdUpdateListener({
    super.key,
    required this.child,
    required this.controller,
    this.strings,
    this.downloadingBuilder,
    this.readyBuilder,
    this.accentColor,
    this.autoStart = true,
  });

  /// Main color of the dialog. Defaults to the app theme's primary color.
  final Color? accentColor;

  final Widget child;
  final UpdateController controller;

  /// Texts. Defaults to Arabic for `ar` locales and English otherwise.
  final UpdateStrings? strings;
  final UpdateContentBuilder? downloadingBuilder;
  final UpdateContentBuilder? readyBuilder;

  /// Run a check on first build.
  final bool autoStart;

  @override
  State<ShorebirdUpdateListener> createState() =>
      _ShorebirdUpdateListenerState();
}

class _ShorebirdUpdateListenerState extends State<ShorebirdUpdateListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Registered before the Router's own back dispatcher (we are its
    // ancestor), so we get to swallow the Android back button first.
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onChanged);
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.checkForUpdate();
      });
    }
  }

  @override
  void didUpdateWidget(ShorebirdUpdateListener old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.controller.config.checkOnResume) {
      widget.controller.checkForUpdate();
    }
  }

  @override
  Future<bool> didPopRoute() async => widget.controller.isDialogVisible;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final strings = widget.strings ??
        UpdateStrings.forLocale(Localizations.maybeLocaleOf(context));
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (controller.isDialogVisible)
          Positioned.fill(
            child: _BlockingOverlay(
              child: UpdateDialogCard(
                controller: controller,
                strings: strings,
                downloadingBuilder: widget.downloadingBuilder,
                readyBuilder: widget.readyBuilder,
                accentColor: widget.accentColor,
              ),
            ),
          ),
      ],
    );
  }
}

class _BlockingOverlay extends StatefulWidget {
  const _BlockingOverlay({required this.child});
  final Widget child;

  @override
  State<_BlockingOverlay> createState() => _BlockingOverlayState();
}

class _BlockingOverlayState extends State<_BlockingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return PopScope(
      canPop: false,
      child: Material(
        type: MaterialType.transparency,
        child: FadeTransition(
          opacity: curved,
          child: Stack(
            children: [
              // Absorbs all touches; tapping does nothing.
              const ModalBarrier(dismissible: false, color: Colors.black54),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ScaleTransition(
                      scale: Tween(begin: 0.9, end: 1.0).animate(curved),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
