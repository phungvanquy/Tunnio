import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/tools.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    container.listen(configProvider, (_, _) {});
    globalState.container = container;
  });

  tearDown(() => container.dispose());

  Future<void> pumpSettings(
    WidgetTester tester, {
    bool isDesktop = true,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    container.read(viewSizeProvider.notifier).value = const Size(1000, 800);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(child: ToolsView(isDesktop: isDesktop)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectMode(WidgetTester tester, String label) async {
    await tester.tap(find.text('Connection mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('mode selection overrides the pending first-connect default', (
    tester,
  ) async {
    container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(vpnDefaultsPending: true));
    await pumpSettings(tester);
    expect(find.text('Connection mode'), findsOneWidget);
    expect(find.text('VPN (TUN) + system proxy'), findsOneWidget);

    await selectMode(tester, 'System proxy');

    final saved = container.read(configProvider);
    expect(saved.appSettingProps.vpnDefaultsPending, isFalse);
    expect(saved.patchClashConfig.tun.enable, isFalse);
    expect(saved.networkProps.systemProxy, isTrue);
    expect(find.text('System proxy'), findsOneWidget);

    await selectMode(tester, 'VPN (TUN)');

    expect(container.read(patchClashConfigProvider).tun.enable, isTrue);
    expect(container.read(networkSettingProvider).systemProxy, isFalse);
    expect(find.text('VPN (TUN)'), findsOneWidget);
  });

  for (final settings in [
    (tun: true, proxy: true, label: 'VPN (TUN) + system proxy'),
    (tun: true, proxy: false, label: 'VPN (TUN)'),
    (tun: false, proxy: true, label: 'System proxy'),
    (tun: false, proxy: false, label: 'Manual proxy'),
  ]) {
    testWidgets('opening and dismissing preserves ${settings.label}', (
      tester,
    ) async {
      container
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith.tun(enable: settings.tun));
      container
          .read(networkSettingProvider.notifier)
          .update((state) => state.copyWith(systemProxy: settings.proxy));
      final before = container.read(configProvider);
      await pumpSettings(tester);
      expect(find.text(settings.label), findsOneWidget);

      await tester.tap(find.text('Connection mode'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Recommended for apps and games'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Only apps that follow system proxy'),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(container.read(configProvider), before);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(settings.label), findsOneWidget);
    });
  }

  testWidgets('selecting TUN replaces a saved combined mode', (tester) async {
    container
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith.tun(enable: true));
    await pumpSettings(tester);

    await selectMode(tester, 'VPN (TUN)');

    expect(container.read(patchClashConfigProvider).tun.enable, isTrue);
    expect(container.read(networkSettingProvider).systemProxy, isFalse);
    expect(find.text('VPN (TUN)'), findsOneWidget);
  });

  testWidgets('mobile settings do not offer desktop connection modes', (
    tester,
  ) async {
    await pumpSettings(tester, isDesktop: false);

    expect(find.text('Connection mode'), findsNothing);
    expect(find.text('Application'), findsOneWidget);
  });

  testWidgets('the selector remains usable with large text', (tester) async {
    await pumpSettings(tester, textScale: 2);
    await tester.ensureVisible(find.text('Connection mode'));
    await tester.pumpAndSettle();

    await selectMode(tester, 'VPN (TUN)');

    expect(container.read(patchClashConfigProvider).tun.enable, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a dialog result is ignored after Settings is removed', (
    tester,
  ) async {
    await pumpSettings(tester);
    final before = container.read(configProvider);
    await tester.tap(find.text('Connection mode'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: SizedBox()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('VPN (TUN)'));
    await tester.pumpAndSettle();

    expect(container.read(configProvider), before);
    expect(tester.takeException(), isNull);
  });
}
