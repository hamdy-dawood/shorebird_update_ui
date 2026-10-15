import 'package:flutter/material.dart';

import '../controller/update_controller.dart';
import '../l10n/update_strings.dart';
import '../models/update_state.dart';

/// Builds custom card content for a state. Receives the controller so you can
/// read [UpdateController.progress] and call `restartNow()` / `dismiss()`.
typedef UpdateContentBuilder = Widget Function(
  BuildContext context,
  UpdateController controller,
);

/// The Material 3 card shown inside the blocking overlay.
class UpdateDialogCard extends StatelessWidget {
  const UpdateDialogCard({
    super.key,
    required this.controller,
    required this.strings,
    this.downloadingBuilder,
    this.readyBuilder,
    this.accentColor,
  });

  final UpdateController controller;
  final UpdateStrings strings;
  final UpdateContentBuilder? downloadingBuilder;
  final UpdateContentBuilder? readyBuilder;

  /// Main color of the dialog (icons, progress, button). Defaults to the app
  /// theme's primary color.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor;
    if (accent != null) {
      final base = Theme.of(context);
      final scheme = base.colorScheme.copyWith(
        primary: accent,
        onPrimary: Colors.white,
        primaryContainer: Color.alphaBlend(accent.withValues(alpha: 0.15),
            base.colorScheme.surfaceContainerHigh),
        onPrimaryContainer: accent,
      );
      return Theme(
        data: base.copyWith(colorScheme: scheme),
        child: Builder(builder: _buildCard),
      );
    }
    return _buildCard(context);
  }

  Widget _buildCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Material(
        color: scheme.surfaceContainerHigh,
        elevation: 6,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListenableBuilder(
            listenable: Listenable.merge([controller, controller.countdown]),
            builder: (context, _) => AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.92, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: _content(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final state = controller.state;
    switch (state) {
      case UpdateRestartRequired():
        return KeyedSubtree(
          key: const ValueKey('ready'),
          child: readyBuilder?.call(context, controller) ??
              _ReadyContent(controller: controller, strings: strings),
        );
      case UpdateError():
        return KeyedSubtree(
          key: const ValueKey('error'),
          child: _ErrorContent(controller: controller, strings: strings),
        );
      default:
        return KeyedSubtree(
          key: const ValueKey('downloading'),
          child: downloadingBuilder?.call(context, controller) ??
              _DownloadingContent(controller: controller, strings: strings),
        );
    }
  }
}

class _DownloadingContent extends StatelessWidget {
  const _DownloadingContent({required this.controller, required this.strings});
  final UpdateController controller;
  final UpdateStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = controller.progress.clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _PulsingIcon(icon: Icons.system_update_alt_rounded),
        const SizedBox(height: 20),
        Text(strings.updatingTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Text(strings.updatingSubtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 24),
        TweenAnimationBuilder<double>(
          tween: Tween(end: progress),
          duration: const Duration(milliseconds: 200),
          builder: (context, value, _) => Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 10),
              Text('${(value * 100).round()}%',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReadyContent extends StatelessWidget {
  const _ReadyContent({required this.controller, required this.strings});
  final UpdateController controller;
  final UpdateStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final manual = controller.showManualInstructions;
    final seconds = controller.countdown.value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SuccessIcon(),
        const SizedBox(height: 20),
        Text(strings.readyTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(manual ? strings.reopenMessage : strings.restartMessage,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant)),
        if (manual) ...[
          const SizedBox(height: 30),
          _Step(number: 1, text: strings.step1),
          const SizedBox(height: 8),
          _Step(number: 2, text: strings.step2),
        ] else ...[
          if (seconds != null) ...[
            if (seconds >= 2) ...[
              const SizedBox(height: 16),
              Text(
                strings.restartingIn.replaceAll('{seconds}', '$seconds'),
                style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
              ),
            ],
          ] else ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: controller.isRestarting ? null : controller.restartNow,
                child: Text(strings.restartNow, style: const TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ],
        if (controller.isDismissible) ...[
          const SizedBox(height: 4),
          TextButton(onPressed: controller.dismiss, child: Text(strings.later)),
        ],
      ],
    );
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.controller, required this.strings});
  final UpdateController controller;
  final UpdateStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline_rounded, size: 56, color: scheme.error),
        const SizedBox(height: 16),
        Text(strings.errorTitle,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(strings.errorMessage,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
              onPressed: controller.dismiss, child: Text(strings.close)),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: scheme.primaryContainer,
          child: Text('$number',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: scheme.onPrimaryContainer)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon({required this.icon});
  final IconData icon;

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ScaleTransition(
      scale: Tween(begin: 0.9, end: 1.1)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
            color: scheme.primaryContainer, shape: BoxShape.circle),
        child: Icon(widget.icon, size: 36, color: scheme.onPrimaryContainer),
      ),
    );
  }
}

class _SuccessIcon extends StatelessWidget {
  const _SuccessIcon();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: v, child: child),
      ),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
            color: scheme.primaryContainer, shape: BoxShape.circle),
        child: Icon(Icons.check_rounded,
            size: 42, color: scheme.onPrimaryContainer),
      ),
    );
  }
}
