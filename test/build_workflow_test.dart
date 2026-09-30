import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final workflow =
      loadYaml(File('.github/workflows/build.yaml').readAsStringSync())
          as YamlMap;
  final jobs = workflow['jobs'] as YamlMap;
  final build = jobs['build'] as YamlMap;
  final release = jobs['release'] as YamlMap;
  const tagPush =
      "github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v')";

  test('all branch pushes and manual runs build without enabling releases', () {
    final events = workflow['on'] as YamlMap;
    expect(events.containsKey('workflow_dispatch'), isTrue);
    expect(events['push']['branches'], contains('**'));
    expect(
      build['if'],
      "github.event_name == 'workflow_dispatch' || "
      "github.event_name == 'push'",
    );
    expect(release['if'], tagPush);
    expect(workflow['permissions']['contents'], 'read');
    expect(release['permissions']['contents'], 'write');
    expect(
      workflow['env']['IS_STABLE'],
      '\${{ $tagPush && !contains(github.ref_name, \'-\') }}',
    );
  });

  test('test artifacts target Android and Windows while tags retain Linux', () {
    final matrix = build['strategy']['matrix']['include'] as String;
    expect(matrix, contains('$tagPush &&'));
    final targets = RegExp(r"'(\[.*?\])'")
        .allMatches(matrix)
        .map((match) => jsonDecode(match[1]!) as List<dynamic>)
        .toList();

    expect(targets, hasLength(2));
    expect(targets[0].map((target) => target['platform']), [
      'android',
      'windows',
      'linux',
    ]);
    expect(targets[1], [
      {
        'platform': 'android',
        'os': 'ubuntu-latest',
        'arch': 'arm64',
        'args': '--arch arm64',
      },
      {
        'platform': 'windows',
        'os': 'windows-2022',
        'arch': 'amd64',
        'args': '--targets exe',
      },
    ]);
    expect(build['strategy']['fail-fast'], isFalse);
  });

  test('artifact builds retain every validation prerequisite', () {
    expect(build['needs'], [
      'dart',
      'plugins',
      'go',
      'xray-interop',
      'android',
      'rust',
      'windows-helper-test',
    ]);
    expect(release['needs'], ['build']);
  });

  test('stable releases publish the structured changelog', () {
    final dartSteps = (jobs['dart'] as YamlMap)['steps'] as YamlList;
    final releaseSteps = release['steps'] as YamlList;
    final render = dartSteps.firstWhere(
      (step) => step['name'] == 'Render stable release notes',
    );
    final upload = dartSteps.firstWhere(
      (step) => step['name'] == 'Upload stable release notes',
    );
    final download = releaseSteps.firstWhere(
      (step) => step['name'] == 'Download stable release notes',
    );
    final publish = releaseSteps.firstWhere(
      (step) => step['name'] == 'Release stable',
    );

    expect(render['if'], "env.IS_STABLE == 'true'");
    expect(
      render['run'],
      contains(r'render release --tag "$GITHUB_REF_NAME" --out release.md'),
    );
    expect(upload['if'], render['if']);
    expect(upload['with']['name'], 'release-notes');
    expect(upload['with']['path'], 'release.md');
    expect(download['if'], render['if']);
    expect(download['with']['name'], 'release-notes');
    expect(download['with']['path'], './notes');
    expect(publish['if'], render['if']);
    expect(publish['with']['body_path'], './notes/release.md');
    expect(publish['with']['files'], './dist/*');
    expect(publish['with']['prerelease'], isFalse);
  });

  test('test builds use native assets and do not consume release signing', () {
    final steps = build['steps'] as YamlList;
    final checkout = steps.firstWhere((step) => step['name'] == 'Checkout');
    final signing = steps.firstWhere(
      (step) => step['name'] == 'Setup Android Signing',
    );
    final setup = steps.firstWhere((step) => step['name'] == 'Setup');
    final upload = steps.firstWhere(
      (step) => step['name'] == 'Upload test installer',
    );
    final releaseUpload = steps.firstWhere(
      (step) => step['name'] == 'Upload release packages',
    );

    expect(checkout['with']['submodules'], 'recursive');
    expect(signing['if'], "matrix.platform == 'android' && $tagPush");
    expect(setup['shell'], 'bash');
    expect(setup['run'], contains('set -o pipefail\n'));
    expect(
      setup['run'],
      contains(RegExp(r'^dart setup\.dart ', multiLine: true)),
    );
    expect(setup['run'], contains(r'${{ matrix.args }}'));
    expect(upload['uses'], 'actions/upload-artifact@v7');
    expect(upload['if'], '\${{ !($tagPush) }}');
    expect(upload['with']['archive'], isFalse);
    expect(upload['with']['name'], r'${{ steps.test-installer.outputs.name }}');
    expect(upload['with']['path'], r'${{ steps.test-installer.outputs.path }}');
    expect(upload['with']['if-no-files-found'], 'error');
    expect(releaseUpload['if'], tagPush);
    expect(releaseUpload['with']['path'], './dist');
    expect(releaseUpload['with']['name'], startsWith('artifact-'));
    expect(
      steps.any((step) => (step['run'] ?? '').toString().contains('= false')),
      isFalse,
    );
  });

  group('Android signing setup', () {
    late Directory workspace;
    final steps = build['steps'] as YamlList;
    final signing = steps.firstWhere(
      (step) => step['name'] == 'Setup Android Signing',
    );

    ProcessResult runSigning(Map<String, String> environment) =>
        Process.runSync(
          'bash',
          ['-e', '-c', signing['run'] as String],
          workingDirectory: workspace.path,
          environment: {
            'IS_STABLE': 'true',
            'KEYSTORE': '',
            'KEY_ALIAS': '',
            'STORE_PASSWORD': '',
            'KEY_PASSWORD': '',
            ...environment,
          },
        );

    setUp(() {
      workspace = Directory.systemTemp.createTempSync('tunnio-signing-');
      Directory('${workspace.path}/android/app').createSync(recursive: true);
    });

    tearDown(() => workspace.deleteSync(recursive: true));

    for (final stable in ['true', 'false']) {
      test('missing keystore permits fallback with IS_STABLE=$stable', () {
        final result = runSigning({'IS_STABLE': stable});
        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(result.stdout, contains('debug signing fallback'));
        expect(
          File('${workspace.path}/android/app/keystore.jks').existsSync(),
          isFalse,
        );
        expect(
          File('${workspace.path}/android/local.properties').existsSync(),
          isFalse,
        );
      });
    }

    test('configured credentials are written without logging them', () {
      final result = runSigning({
        'KEYSTORE': base64Encode(utf8.encode('fixture-keystore')),
        'KEY_ALIAS': 'fixture-alias',
        'STORE_PASSWORD': 'fixture-store-password',
        'KEY_PASSWORD': 'fixture-key-password',
      });
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(
        File('${workspace.path}/android/app/keystore.jks').readAsStringSync(),
        'fixture-keystore',
      );
      expect(
        File('${workspace.path}/android/local.properties').readAsStringSync(),
        'keyAlias=fixture-alias\nstorePassword=fixture-store-password\nkeyPassword=fixture-key-password\n',
      );
      expect('${result.stdout}${result.stderr}', isNot(contains('fixture-')));
    });

    test('a supplied keystore still requires complete credentials', () {
      for (final missing in ['KEY_ALIAS', 'STORE_PASSWORD', 'KEY_PASSWORD']) {
        final result = runSigning({
          'KEYSTORE': base64Encode(utf8.encode('fixture-keystore')),
          'KEY_ALIAS': 'fixture-alias',
          'STORE_PASSWORD': 'fixture-store-password',
          'KEY_PASSWORD': 'fixture-key-password',
          missing: '',
        });
        expect(result.exitCode, isNot(0));
        expect(result.stderr, contains('$missing is required'));
        expect(
          File('${workspace.path}/android/app/keystore.jks').existsSync(),
          isFalse,
        );
      }
    });
  }, skip: !Platform.isLinux);

  test('Core checkout points to the published repository without SSH keys', () {
    final submodules = File('.gitmodules').readAsStringSync();
    expect(
      submodules,
      contains('url = https://github.com/phungvanquy/Tunnio-core.git'),
    );
    expect(submodules, contains('branch = main'));
  });
}
