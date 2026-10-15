import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shorebird_update_ui/shorebird_update_ui.dart';

class _GatedBackend implements UpdateBackend {
  final gate = Completer<void>();
  @override
  bool get isAvailable => true;
  @override
  Future<UpdateStatus> checkForUpdate(UpdateTrack track) async =>
      UpdateStatus.outdated;
  @override
  Future<void> update(UpdateTrack track) => gate.future;
}

void main() {
  testWidgets('switches downloading -> success and cannot be dismissed',
      (tester) async {
    final backend = _GatedBackend();
    final controller = UpdateController(
      config: const ShorebirdUpdateConfig(
        simulatedDuration: Duration(milliseconds: 500),
      ),
      backend: backend,
      platform: TargetPlatform.android,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: const Scaffold(body: Center(child: Text('home'))),
      builder: (context, child) => ShorebirdUpdateListener(
        controller: controller,
        strings: UpdateStrings.en,
        child: child!,
      ),
    ));

    // Auto-start kicks in after the first frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Updating the app...'), findsOneWidget);
    expect(find.textContaining('%'), findsOneWidget);

    // Barrier tap does nothing.
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(find.text('Updating the app...'), findsOneWidget);

    // Back button is swallowed.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    expect(find.text('Updating the app...'), findsOneWidget);

    // Finish the download.
    backend.gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Update ready!'), findsOneWidget);
    expect(find.text('Updating the app...'), findsNothing);
    expect(find.text('Restart now'), findsOneWidget);
    expect(find.text('Later'), findsNothing);

    // Still not dismissible when ready.
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(await tester.binding.handlePopRoute(), isTrue);
    expect(find.text('Update ready!'), findsOneWidget);
  });

  testWidgets('iOS shows instructions and no restart button', (tester) async {
    final controller = FakeUpdateController(
      config: const ShorebirdUpdateConfig(
        simulatedDuration: Duration(milliseconds: 200),
      ),
      checkDelay: const Duration(milliseconds: 10),
      downloadDuration: const Duration(milliseconds: 50),
      platform: TargetPlatform.iOS,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: const SizedBox(),
      builder: (context, child) => ShorebirdUpdateListener(
        controller: controller,
        strings: UpdateStrings.en,
        child: child!,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Update ready!'), findsOneWidget);
    expect(find.text('Restart now'), findsNothing);
    expect(find.text('Open it again'), findsOneWidget);
  });

  testWidgets('hides restart button when countdown is active', (tester) async {
    final controller = FakeUpdateController(
      config: const ShorebirdUpdateConfig(
        simulatedDuration: Duration(milliseconds: 100),
        autoRestartCountdown: Duration(seconds: 10),
      ),
      checkDelay: const Duration(milliseconds: 10),
      downloadDuration: const Duration(milliseconds: 20),
      platform: TargetPlatform.android,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: const SizedBox(),
      builder: (context, child) => ShorebirdUpdateListener(
        controller: controller,
        strings: UpdateStrings.en,
        child: child!,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Update ready!'), findsOneWidget);
    expect(find.text('Restart now'), findsNothing);
    expect(find.textContaining('Restarting in'), findsOneWidget);

    controller.dispose();
  });
}
