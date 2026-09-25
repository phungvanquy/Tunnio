import 'package:fl_clash/common/server_country.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('display names omit only a redundant leading country flag', () {
    expect(serverDisplayName('🇯🇵 Tokyo'), 'Tokyo');
    expect(serverDisplayName('  🇩🇪 Frankfurt'), 'Frankfurt');
    expect(serverDisplayName('Tokyo 🇯🇵'), 'Tokyo 🇯🇵');
    expect(serverDisplayName('🇺🇸 → 🇯🇵'), '🇺🇸 → 🇯🇵');
    expect(serverDisplayName('🇯🇵'), '🇯🇵');
    expect(serverDisplayName('Private relay'), 'Private relay');
  });

  test('uses explicit flags, country names, and leading country codes', () {
    for (final entry in {
      '🇯🇵 Tokyo 01': '🇯🇵',
      'DE Frankfurt': '🇩🇪',
      '[US] Premium': '🇺🇸',
      'HK01': '🇭🇰',
      'UK-London': '🇬🇧',
      'Premium Netherlands 2': '🇳🇱',
      'Singapore': '🇸🇬',
      '香港 01': '🇭🇰',
      '印度尼西亚': '🇮🇩',
    }.entries) {
      expect(serverCountryFlag(entry.key), entry.value, reason: entry.key);
    }
  });

  test('unknown and ambiguous names do not invent a country', () {
    for (final name in [
      '',
      'Private relay',
      'RUSH Premium',
      'CAche',
      'Join us',
      'DE Japan',
      '🇺🇸 → 🇯🇵',
      'Germany Netherlands',
    ]) {
      expect(serverCountryFlag(name), isNull, reason: name);
    }
  });
}
