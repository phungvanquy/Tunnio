import 'package:fl_clash/common/dav_client.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/backup_and_restore.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

const _existing = DAVProps(
  uri: 'https://dav.example.com/remote',
  user: 'alice',
  password: 'secret',
  fileName: 'custom.zip',
);

class _BackupAction extends BackupAction {
  final restored = <RestoreOption>[];

  @override
  void build() {}

  @override
  Future<void> restore(RestoreOption option) async {
    restored.add(option);
  }
}

class _DavClient extends DAVClient {
  _DavClient() : super(_existing);

  int restores = 0;

  @override
  Future<bool> ping() async => true;

  @override
  Future<bool> restore() async {
    restores++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late _BackupAction backupAction;

  setUp(() {
    backupAction = _BackupAction();
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        backupActionProvider.overrideWith(() => backupAction),
      ],
    );
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1200, 1400);
    container.listen(davSettingProvider, (_, _) {}, fireImmediately: true);
  });

  tearDown(() => container.dispose());

  Future<void> pumpDialog(WidgetTester tester, Widget dialog) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(child: Scaffold(body: dialog)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('RestoreOptionsDialog', () {
    Future<RestoreOption?> openAndChoose(
      WidgetTester tester,
      String label,
    ) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      RestoreOption? chosen;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    chosen = await showDialog<RestoreOption>(
                      context: context,
                      builder: (_) => const RestoreOptionsDialog(),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      return chosen;
    }

    testWidgets('returns onlyProfiles for the config-only option', (
      tester,
    ) async {
      expect(
        await openAndChoose(tester, 'Restore profiles only'),
        RestoreOption.onlyProfiles,
      );
    });

    testWidgets('returns all for the full-data option', (tester) async {
      expect(
        await openAndChoose(tester, 'Restore all data'),
        RestoreOption.all,
      );
    });
  });

  group('WebDAVFormDialog', () {
    testWidgets('rejects an empty form and stores nothing', (tester) async {
      await pumpDialog(tester, const WebDAVFormDialog());

      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(container.read(davSettingProvider), isNull);
      expect(find.byType(WebDAVFormDialog), findsOneWidget);
    });

    testWidgets('names the password toggle by what pressing it does', (
      tester,
    ) async {
      await pumpDialog(tester, const WebDAVFormDialog());

      final toggle = find.descendant(
        of: find.widgetWithIcon(TextFormField, Icons.password),
        matching: find.byType(IconButton),
      );
      expect(tester.widget<IconButton>(toggle).tooltip, 'Show password');

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(tester.widget<IconButton>(toggle).tooltip, 'Hide password');
    });

    testWidgets('rejects a malformed address', (tester) async {
      await pumpDialog(tester, const WebDAVFormDialog());

      await tester.enterText(
        find.widgetWithIcon(TextFormField, Icons.link),
        'not-a-url',
      );
      await tester.enterText(
        find.widgetWithIcon(TextFormField, Icons.account_circle),
        'alice',
      );
      await tester.enterText(
        find.widgetWithIcon(TextFormField, Icons.password),
        'secret',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(container.read(davSettingProvider), isNull);
    });

    testWidgets('stores a valid binding with the default file name', (
      tester,
    ) async {
      await pumpDialog(tester, const WebDAVFormDialog());

      await tester.enterText(
        find.widgetWithIcon(TextFormField, Icons.link),
        'https://dav.example.com/remote',
      );
      await tester.enterText(
        find.widgetWithIcon(TextFormField, Icons.account_circle),
        'alice',
      );
      await tester.enterText(
        find.widgetWithIcon(TextFormField, Icons.password),
        'secret',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      final dav = container.read(davSettingProvider);
      expect(dav?.uri, 'https://dav.example.com/remote');
      expect(dav?.user, 'alice');
      expect(dav?.password, 'secret');
      expect(dav?.fileName, defaultDavFileName);
    });

    testWidgets('editing preserves the previously chosen file name', (
      tester,
    ) async {
      container.read(davSettingProvider.notifier).update((_) => _existing);
      await pumpDialog(tester, const WebDAVFormDialog(dav: _existing));

      await tester.enterText(
        find.widgetWithIcon(TextFormField, Icons.account_circle),
        'bob',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      final dav = container.read(davSettingProvider);
      expect(dav?.user, 'bob');
      expect(dav?.fileName, 'custom.zip');
    });

    testWidgets('offers delete only when editing an existing binding', (
      tester,
    ) async {
      await pumpDialog(tester, const WebDAVFormDialog());
      expect(find.widgetWithText(TextButton, 'Delete'), findsNothing);

      await pumpDialog(tester, const WebDAVFormDialog(dav: _existing));
      expect(find.widgetWithText(TextButton, 'Delete'), findsOneWidget);
    });

    testWidgets('delete clears the stored binding only after confirmation', (
      tester,
    ) async {
      container.read(davSettingProvider.notifier).update((_) => _existing);
      await pumpDialog(tester, const WebDAVFormDialog(dav: _existing));

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(container.read(davSettingProvider), _existing);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(davSettingProvider), _existing);
      expect(find.byType(WebDAVFormDialog), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Confirm'));
      await tester.pumpAndSettle();

      expect(container.read(davSettingProvider), isNull);
    });

    testWidgets('toggles password visibility', (tester) async {
      await pumpDialog(tester, const WebDAVFormDialog(dav: _existing));

      expect(find.byIcon(Icons.visibility), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });
  });

  group('BackupAndRestore', () {
    testWidgets('WebDAV indicator announces connection state', (tester) async {
      final semantics = tester.ensureSemantics();
      final client = _DavClient();
      final connection = DAVConnectionController(createClient: (_) => client);
      container.read(davSettingProvider.notifier).update((_) => _existing);
      await pumpDialog(tester, BackupAndRestore(connection: connection));

      expect(find.bySemanticsLabel(RegExp('Connected')), findsWidgets);
      connection.value = false;
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('Connection failed')), findsWidgets);
      semantics.dispose();
    });

    testWidgets('confirmed WebDAV restore uses the chosen option', (
      tester,
    ) async {
      final client = _DavClient();
      final connection = DAVConnectionController(createClient: (_) => client);
      container.read(davSettingProvider.notifier).update((_) => _existing);
      await pumpDialog(tester, BackupAndRestore(connection: connection));

      await tester.tap(find.text('Restore data from WebDAV'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore profiles only'));
      await tester.pumpAndSettle();
      expect(client.restores, 0);

      await tester.tap(find.widgetWithText(TextButton, 'Confirm'));
      await tester.pumpAndSettle();

      expect(client.restores, 1);
      expect(backupAction.restored, [RestoreOption.onlyProfiles]);
      expect(tester.takeException(), isNull);
    });

    for (final option in ['Restore profiles only', 'Restore all data']) {
      testWidgets('local $option cancellation leaves data untouched', (
        tester,
      ) async {
        await pumpDialog(tester, const BackupAndRestore());

        await tester.tap(find.text('Restore data from a file'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(option));
        await tester.pumpAndSettle();

        expect(find.textContaining('may be replaced'), findsOneWidget);
        expect(backupAction.restored, isEmpty);
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(backupAction.restored, isEmpty);
        expect(tester.takeException(), isNull);
      });

      testWidgets('WebDAV $option cancellation does not download', (
        tester,
      ) async {
        final client = _DavClient();
        final connection = DAVConnectionController(createClient: (_) => client);
        container.read(davSettingProvider.notifier).update((_) => _existing);
        await pumpDialog(tester, BackupAndRestore(connection: connection));

        await tester.tap(find.text('Restore data from WebDAV'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(option));
        await tester.pumpAndSettle();

        expect(find.textContaining('may be replaced'), findsOneWidget);
        expect(client.restores, 0);
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(client.restores, 0);
        expect(backupAction.restored, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
