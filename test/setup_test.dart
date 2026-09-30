import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../setup.dart' as setup;

void main() {
  group('setup.dart', () {
    test('parses -v as verbose mode', () {
      final results = setup.createSetupArgParser().parse(['android', '-v']);

      expect(results['verbose'], isTrue);
      expect(results.rest, ['android']);
    });

    test('accepts dev application environment', () {
      final results = setup.createSetupArgParser().parse([
        'android',
        '--env',
        'dev',
      ]);

      expect(results['env'], 'dev');
    });

    test('Flutter build environment does not depend on Core SHA256', () {
      expect(setup.createBuildEnvironment('dev'), {'APP_ENV': 'dev'});
    });

    test('uses an ignored local key or build environment for encryption', () {
      final root = Directory.systemTemp.createTempSync('tunnio-build-key-');
      addTearDown(() => root.deleteSync(recursive: true));
      expect(
        setup.readSubscriptionPrivateKey(root.path, environment: {}),
        isNull,
      );
      File(
        '${root.path}/env.local.json',
      ).writeAsStringSync(jsonEncode({'VPN_RSA_PRIVATE_KEY_B64': 'local-key'}));
      expect(
        setup.readSubscriptionPrivateKey(root.path, environment: {}),
        'local-key',
      );
      expect(
        setup.readSubscriptionPrivateKey(
          root.path,
          environment: {'VPN_RSA_PRIVATE_KEY_B64': 'ci-key'},
        ),
        'ci-key',
      );
      expect(
        setup.createBuildEnvironment('stable', privateKeyBase64: 'ci-key'),
        {'APP_ENV': 'stable', 'VPN_RSA_PRIVATE_KEY_B64': 'ci-key'},
      );
    });

    test('omits verbose from flutter build args by default', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: false,
      );

      expect(args, ['dart-define-from-file=env.json', 'split-per-abi']);
    });

    test('adds verbose to flutter build args with -v', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: true,
      );

      expect(args, [
        'verbose',
        'dart-define-from-file=env.json',
        'split-per-abi',
      ]);
    });

    test('refuses to package while a native build hook is skipped', () {
      const pubspec = '''
hooks:
  user_defines:
    setup:
      build_assets: false
    rust_api:
      build_assets: true
''';

      expect(setup.packagesNotBuildingAssets(pubspec), ['setup']);
      expect(setup.packagesNotBuildingAssets('name: x\n'), isEmpty);
    });

    test('packages every Linux format on every architecture', () {
      expect(setup.createPackageTargets('linux', null), 'deb,appimage,rpm');
      expect(setup.createPackageTargets('linux', 'deb'), 'deb');
      expect(setup.createPackageTargets('macos', null), 'dmg');
    });

    test('downloads the appimagetool build matching the host', () {
      expect(setup.appImageToolArch('arm64'), 'aarch64');
      expect(setup.appImageToolArch('amd64'), 'x86_64');
    });
  });
}
