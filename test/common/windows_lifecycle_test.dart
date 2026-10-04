import 'dart:async';

import 'package:fl_clash/common/windows_lifecycle.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = WindowsLifecycle.channel;
  late WindowsLifecycle lifecycle;
  late int exits;

  setUp(() {
    lifecycle = WindowsLifecycle();
    exits = 0;
    messenger.setMockMethodCallHandler(channel, (_) async => false);
  });

  tearDown(() {
    lifecycle.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<void> exit() async {
    exits++;
  }

  Future<void> requestExit() async {
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall('requestExit')),
      (_) {},
    );
  }

  test('readiness alone does not request an exit', () async {
    await lifecycle.initialize(exit);

    expect(exits, 0);
  });

  test('forwards an installer request to the exit callback', () async {
    await lifecycle.initialize(exit);

    await requestExit();

    expect(exits, 1);
  });

  test('honors a shutdown requested before Dart was ready', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'ready');
      return true;
    });

    await lifecycle.initialize(exit);

    expect(exits, 1);
  });

  test('accepts an exit request while readiness is pending', () async {
    final ready = Completer<bool>();
    messenger.setMockMethodCallHandler(channel, (_) => ready.future);
    final initialization = lifecycle.initialize(exit);

    await requestExit();
    expect(exits, 1);
    ready.complete(false);
    await initialization;
    expect(exits, 1);
  });

  test('disposal detaches the callback while readiness is pending', () async {
    final ready = Completer<bool>();
    messenger.setMockMethodCallHandler(channel, (_) => ready.future);
    final initialization = lifecycle.initialize(exit);

    lifecycle.dispose();
    ready.complete(true);
    await initialization;

    expect(exits, 0);
  });
}
