import 'package:fl_clash/common/common.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  group('formatSubscriptionExpiry', () {
    for (final (date, expected) in [
      (DateTime(2024, 12, 22), '22/12/2024'),
      (DateTime(2027, 2, 9), '09/02/2027'),
      (DateTime(2028, 2, 29, 23, 59, 59), '29/02/2028'),
      (DateTime(2100, 1, 1), '01/01/2100'),
      (DateTime(9999, 12, 31, 23, 59, 59), '31/12/9999'),
    ]) {
      test('formats the local expiration date as $expected', () {
        final seconds =
            date.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
        expect(formatSubscriptionExpiry(seconds), expected);
      });
    }

    for (final seconds in [
      null,
      0,
      -1,
      DateTime(10000).millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond,
      8640000000001,
      9223372036854775807,
    ]) {
      test('returns no date for an unspecified or invalid value: $seconds', () {
        expect(formatSubscriptionExpiry(seconds), isNull);
      });
    }
  });

  group('DateTimeExtension', () {
    test('detects dates before now', () {
      expect(
        DateTime.now().subtract(const Duration(milliseconds: 1)).isBeforeNow,
        isTrue,
      );
    });

    test('isBeforeSecure keeps null as false and non-null as true', () {
      final dateTime = DateTime(2026, 5, 27);

      expect(dateTime.isBeforeSecure(null), isFalse);
      expect(dateTime.isBeforeSecure(DateTime(2026, 5, 26)), isTrue);
      expect(dateTime.isBeforeSecure(DateTime(2026, 5, 28)), isTrue);
    });

    test('formats date, full datetime, and time slices', () {
      final dateTime = DateTime(2026, 5, 27, 14, 3, 9);

      expect(dateTime.show, '2026-05-27');
      expect(dateTime.showFull, '2026-05-27 14:03:09');
      expect(dateTime.showTime, ' 14:03:09');
    });

    testWidgets(
      'getLastUpdateTimeDesc returns unknown for epoch or year <= 1970',
      (tester) async {
        late BuildContext buildContext;
        await tester.pumpWidget(
          TestApp(
            child: Builder(
              builder: (context) {
                buildContext = context;
                return const SizedBox();
              },
            ),
          ),
        );

        final epochZero = DateTime.fromMillisecondsSinceEpoch(0);
        final year1970 = DateTime.utc(1970, 1, 1);
        final year1 = DateTime.utc(1, 1, 1);

        final l10n = buildContext.appLocalizations;
        expect(epochZero.getLastUpdateTimeDesc(buildContext), l10n.unknown);
        expect(year1970.getLastUpdateTimeDesc(buildContext), l10n.unknown);
        expect(year1.getLastUpdateTimeDesc(buildContext), l10n.unknown);
      },
    );

    testWidgets(
      'getLastUpdateTimeDesc returns relative times for valid dates',
      (tester) async {
        late BuildContext buildContext;
        await tester.pumpWidget(
          TestApp(
            child: Builder(
              builder: (context) {
                buildContext = context;
                return const SizedBox();
              },
            ),
          ),
        );

        final l10n = buildContext.appLocalizations;
        final now = DateTime.now();

        expect(now.getLastUpdateTimeDesc(buildContext), l10n.justNow);
        expect(
          now
              .subtract(const Duration(minutes: 5))
              .getLastUpdateTimeDesc(buildContext),
          l10n.minutesAgo(5),
        );
        expect(
          now
              .subtract(const Duration(hours: 3))
              .getLastUpdateTimeDesc(buildContext),
          l10n.hoursAgo(3),
        );
        expect(
          now
              .subtract(const Duration(days: 4))
              .getLastUpdateTimeDesc(buildContext),
          l10n.daysAgo(4),
        );
      },
    );
  });
}
