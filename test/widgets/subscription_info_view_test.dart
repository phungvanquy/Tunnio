import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  final expire =
      DateTime(2100, 1, 1).millisecondsSinceEpoch ~/
      Duration.millisecondsPerSecond;

  testWidgets('hides expiry when both values do not fit', (tester) async {
    const trafficLabel = '1KB / 1GB';

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        builder: (context, child) {
          globalState.measure = Measure.of(context, 1);
          globalState.theme = CommonTheme.of(context, 1);
          return child!;
        },
        home: Scaffold(
          body: SizedBox(
            width: 120,
            child: SubscriptionInfoView(
              subscriptionInfo: SubscriptionInfo(
                upload: 1024,
                total: 1073741824,
                expire: expire,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(trafficLabel), findsOneWidget);
    expect(find.text('01/01/2100'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SubscriptionInfoView),
        matching: find.byType(Text),
      ),
      findsOneWidget,
    );
  });

  testWidgets('keeps expiry at its intrinsic width when both values fit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: SubscriptionInfoView(
              subscriptionInfo: SubscriptionInfo(
                upload: 1024,
                total: 1073741824,
                expire: expire,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('01/01/2100'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SubscriptionInfoView),
        matching: find.byType(Text),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('shows full subscription details in information rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        builder: (context, child) {
          globalState.measure = Measure.of(context, 1);
          globalState.theme = CommonTheme.of(context, 1);
          return child!;
        },
        home: Scaffold(
          body: SubscriptionInfoDetailView(
            subscriptionInfo: SubscriptionInfo(
              upload: 1024,
              download: 2048,
              total: 1073741824,
              expire: expire,
            ),
          ),
        ),
      ),
    );

    final appLocalizations = AppLocalizations.current;
    expect(find.text(appLocalizations.trafficUsage), findsOneWidget);
    expect(find.text(appLocalizations.usedTraffic), findsOneWidget);
    expect(find.text(appLocalizations.totalTraffic), findsOneWidget);
    expect(find.text(appLocalizations.expireTime), findsOneWidget);
    expect(find.text('01/01/2100'), findsOneWidget);
    expect(find.text('3KB'), findsOneWidget);
    expect(find.text('1GB'), findsOneWidget);
    expect(find.byType(DecorationListItem), findsNWidgets(3));
  });

  for (final invalid in [0, -1, 9223372036854775807]) {
    testWidgets(
      'subscription views handle an unspecified or invalid expiry: $invalid',
      (tester) async {
        final info = SubscriptionInfo(total: 100, expire: invalid);
        await tester.pumpWidget(
          TestApp(
            child: Scaffold(
              body: Column(
                children: [
                  SubscriptionInfoView(subscriptionInfo: info),
                  SubscriptionInfoDetailView(subscriptionInfo: info),
                ],
              ),
            ),
          ),
        );
        expect(find.text(AppLocalizations.current.unknown), findsNWidgets(2));
        expect(find.text(AppLocalizations.current.infiniteTime), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
