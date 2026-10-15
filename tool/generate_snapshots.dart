import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/home.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../test/helpers/test_profiles.dart';

const _captureKey = Key('documentation-snapshot');
const _servers = [
  VpnServer(id: 'tokyo', name: 'Tokyo · 01', target: 'tokyo', type: 'VLESS'),
  VpnServer(
    id: 'singapore',
    name: 'Singapore · 01',
    target: 'singapore',
    type: 'VLESS',
  ),
  VpnServer(
    id: 'frankfurt',
    name: 'Frankfurt · 01',
    target: 'frankfurt',
    type: 'Trojan',
  ),
  VpnServer(
    id: 'amsterdam',
    name: 'Amsterdam · 01',
    target: 'amsterdam',
    type: 'Trojan',
  ),
  VpnServer(
    id: 'london',
    name: 'London · 01',
    target: 'london',
    type: 'Shadowsocks',
  ),
  VpnServer(
    id: 'san-francisco',
    name: 'San Francisco · 01',
    target: 'san-francisco',
    type: 'Shadowsocks',
  ),
];

const _profile = Profile(
  id: 1,
  label: 'Demo subscription',
  url: 'https://subscription.example.invalid/demo',
  autoUpdateDuration: Duration(hours: 12),
  subscriptionInfo: SubscriptionInfo(expire: 1924948800),
  snapshot: ProfileSnapshot(
    revision: 1,
    generation: '0123456789abcdef0123456789abcdef',
    servers: _servers,
    managedGroups: VpnManagedGroups(
      selector: 'demo-selector',
      auto: 'demo-auto',
      fallback: 'demo-fallback',
    ),
  ),
);

class _DemoLatency extends VpnLatency {
  @override
  VpnLatencyState build() => const VpnLatencyState(
    results: {
      'tokyo': VpnNodeLatency(VpnLatencyStatus.measured, 42),
      'singapore': VpnNodeLatency(VpnLatencyStatus.measured, 68),
      'frankfurt': VpnNodeLatency(VpnLatencyStatus.measured, 156),
      'amsterdam': VpnNodeLatency(VpnLatencyStatus.measured, 164),
      'london': VpnNodeLatency(VpnLatencyStatus.measured, 178),
      'san-francisco': VpnNodeLatency(VpnLatencyStatus.measured, 203),
    },
  );
}

class _DemoActiveNode extends VpnActiveNode {
  @override
  AsyncValue<VpnServer?> build() => AsyncData(_servers.first);
}

Future<void> _loadFonts() async {
  const sdk = String.fromEnvironment('FLUTTER_SDK');
  final directory = Directory('$sdk/bin/cache/artifacts/material_fonts');
  if (sdk.isEmpty || !directory.existsSync()) {
    throw StateError(
      'Pass --dart-define=FLUTTER_SDK=/absolute/path/to/flutter. '
      'Run flutter precache first if the SDK has no cached fonts.',
    );
  }
  final roboto = FontLoader('Roboto');
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    roboto.addFont(
      File(
        '${directory.path}/Roboto-$weight.ttf',
      ).readAsBytes().then(ByteData.sublistView),
    );
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      File(
        '${directory.path}/MaterialIcons-Regular.otf',
      ).readAsBytes().then(ByteData.sublistView),
    );
  await icons.load();
}

Future<void> _saveSnapshot(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('snapshots').create(recursive: true);
      await File('snapshots/$name.png').writeAsBytes(
        bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  for (final scene in [
    (
      name: 'desktop-dark',
      size: const Size(1080, 720),
      brightness: Brightness.dark,
      proxyOnly: false,
      settings: false,
    ),
    (
      name: 'desktop-light',
      size: const Size(1080, 720),
      brightness: Brightness.light,
      proxyOnly: true,
      settings: false,
    ),
    (
      name: 'mobile-light',
      size: const Size(412, 960),
      brightness: Brightness.light,
      proxyOnly: false,
      settings: false,
    ),
    (
      name: 'connection-mode',
      size: const Size(840, 640),
      brightness: Brightness.dark,
      proxyOnly: true,
      settings: true,
    ),
  ]) {
    testWidgets('render ${scene.name}', (tester) async {
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([_profile])),
          vpnLatencyProvider.overrideWith(_DemoLatency.new),
          vpnActiveNodeProvider.overrideWith(_DemoActiveNode.new),
          vpnConnectionProvider.overrideWithValue(
            VpnConnection(
              phase: scene.proxyOnly
                  ? VpnConnectionPhase.proxyOnly
                  : VpnConnectionPhase.connected,
              canDisconnect: true,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(configProvider, (_, _) {});
      globalState.container = container;
      container.read(initProvider.notifier).value = true;
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      container.read(currentProfileIdProvider.notifier).value = _profile.id;
      container.read(viewSizeProvider.notifier).value = scene.size;
      container
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(vpnDefaultsPending: false));
      container
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith.tun(enable: !scene.proxyOnly));
      container
          .read(networkSettingProvider.notifier)
          .update((state) => state.copyWith(systemProxy: scene.proxyOnly));

      tester.view.physicalSize = scene.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(
            key: _captureKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              navigatorKey: globalState.navigatorKey,
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.delegate.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              theme: ThemeData(
                fontFamily: 'Roboto',
                useMaterial3: true,
                platform: scene.size.width < 600
                    ? TargetPlatform.android
                    : TargetPlatform.linux,
                colorScheme: container.read(
                  genColorSchemeProvider(scene.brightness),
                ),
              ).withAppShapes,
              builder: (context, child) => ThemeManager(
                // ignore: deprecated_member_use
                child: MaterialUiCompatibilityBridge(child: child!),
              ),
              home: const HomePage(),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/images/icon.png'),
          tester.element(find.byType(HomePage)),
        ),
      );
      await tester.pumpAndSettle();
      if (scene.settings) {
        await tester.tap(find.byKey(const Key('vpn-settings')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Connection mode'));
        await tester.pumpAndSettle();
      }
      await _saveSnapshot(tester, scene.name);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
