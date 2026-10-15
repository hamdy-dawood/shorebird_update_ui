import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:shorebird_update_ui/shorebird_update_ui.dart';

class TestBackend implements UpdateBackend {
  TestBackend({
    this.available = true,
    this.status = UpdateStatus.outdated,
    this.failUpdate = false,
  });

  bool available;
  UpdateStatus status;
  bool failUpdate;
  int checks = 0;
  int updates = 0;
  Completer<void>? gate;

  @override
  bool get isAvailable => available;

  @override
  Future<UpdateStatus> checkForUpdate(UpdateTrack track) async {
    checks++;
    return status;
  }

  @override
  Future<void> update(UpdateTrack track) async {
    updates++;
    if (gate != null) await gate!.future;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (failUpdate) throw const UpdateException(message: "x", reason: UpdateFailureReason.downloadFailed);
  }
}

void main() {
  const config = ShorebirdUpdateConfig(
    simulatedDuration: Duration(milliseconds: 300),
  );

  test('does nothing when Shorebird is unavailable', () async {
    final backend = TestBackend(available: false);
    final c = UpdateController(config: config, backend: backend);
    await c.checkForUpdate();
    expect(c.state, isA<UpdateIdle>());
    expect(backend.checks, 0);
    c.dispose();
  });

  test('outOfDate: checking -> downloading -> restartRequired', () async {
    final backend = TestBackend();
    final c = UpdateController(config: config, backend: backend);
    final seen = <Type>[];
    c.addListener(() {
      if (seen.isEmpty || seen.last != c.state.runtimeType) {
        seen.add(c.state.runtimeType);
      }
    });
    await c.checkForUpdate();
    expect(seen, [UpdateChecking, UpdateDownloading, UpdateRestartRequired]);
    expect(c.progress, 1);
    expect(c.isDialogVisible, isTrue);
    c.dispose();
  });

  test('already restartRequired skips download', () async {
    final backend = TestBackend(status: UpdateStatus.restartRequired);
    final c = UpdateController(config: config, backend: backend);
    await c.checkForUpdate();
    expect(c.state, isA<UpdateRestartRequired>());
    expect(backend.updates, 0);
    c.dispose();
  });

  test('upToDate', () async {
    final c = UpdateController(
        config: config, backend: TestBackend(status: UpdateStatus.upToDate));
    await c.checkForUpdate();
    expect(c.state, isA<UpdateUpToDate>());
    expect(c.isDialogVisible, isFalse);
    c.dispose();
  });

  test('failure ends in error, hides dialog, and allows retry', () async {
    final backend = TestBackend(failUpdate: true);
    final c = UpdateController(config: config, backend: backend);
    await c.checkForUpdate();
    expect(c.state, isA<UpdateError>());
    expect(c.isDialogVisible, isFalse); // showErrors defaults to false
    backend.failUpdate = false;
    await c.checkForUpdate();
    expect(c.state, isA<UpdateRestartRequired>());
    c.dispose();
  });

  test('never runs concurrently', () async {
    final backend = TestBackend()..gate = Completer<void>();
    final c = UpdateController(config: config, backend: backend);
    final first = c.checkForUpdate();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await c.checkForUpdate(); // ignored
    expect(backend.checks, 1);
    backend.gate!.complete();
    await first;
    c.dispose();
  });

  test('progress eases up to at most 90% while downloading', () async {
    final backend = TestBackend()..gate = Completer<void>();
    final c = UpdateController(config: config, backend: backend);
    final f = c.checkForUpdate();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(c.progress, greaterThan(0.5));
    expect(c.progress, lessThanOrEqualTo(0.9));
    backend.gate!.complete();
    await f;
    c.dispose();
  });

  test('iOS never restarts and shows manual instructions', () async {
    var restarted = false;
    final c = UpdateController(
      config: config,
      backend: TestBackend(),
      platform: TargetPlatform.iOS,
      onRestartPressed: () async => restarted = true,
    );
    await c.checkForUpdate();
    await c.restartNow();
    expect(restarted, isFalse);
    expect(c.showManualInstructions, isTrue);
    c.dispose();
  });

  test('Android restart failure falls back to manual instructions', () async {
    final c = UpdateController(
      config: config,
      backend: TestBackend(),
      platform: TargetPlatform.android,
      onRestartPressed: () async => throw Exception('boom'),
    );
    await c.checkForUpdate();
    expect(c.showManualInstructions, isFalse);
    await c.restartNow();
    expect(c.showManualInstructions, isTrue);
    c.dispose();
  });

  test('onBeforeRestart runs before restart; Later hides dialog', () async {
    final order = <String>[];
    final c = UpdateController(
      config: const ShorebirdUpdateConfig(
        simulatedDuration: Duration(milliseconds: 300),
        dismissibleWhenReady: true,
      ),
      backend: TestBackend(),
      platform: TargetPlatform.android,
      onBeforeRestart: () async => order.add('before'),
      onRestartPressed: () async => order.add('restart'),
    );
    await c.checkForUpdate();
    await c.restartNow();
    expect(order, ['before', 'restart']);
    c.dismiss();
    expect(c.isDialogVisible, isFalse);
    c.dispose();
  });

  test('FakeUpdateController runs the flow without restarting', () async {
    final c = FakeUpdateController(
      config: config,
      checkDelay: const Duration(milliseconds: 10),
      downloadDuration: const Duration(milliseconds: 50),
      platform: TargetPlatform.android,
    );
    await c.checkForUpdate();
    expect(c.state, isA<UpdateRestartRequired>());
    await c.restartNow();
    expect(c.fakeRestartCount, 1);
    expect(c.state, isA<UpdateIdle>());
    c.dispose();
  });
}
