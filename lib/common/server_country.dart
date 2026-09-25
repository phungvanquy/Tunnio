final _flagPattern = RegExp(r'[\u{1F1E6}-\u{1F1FF}]{2}', unicode: true);
final _leadingCode = RegExp(r'^\s*\[?([A-Z]{2})(?=[\s\d\]_.|/-]|$)');
final _countryNames = <String, RegExp>{
  for (final entry in _countryAliases.entries)
    entry.key: RegExp(
      '(?:^|[^a-z])(?:${entry.value})(?:\$|[^a-z])',
      caseSensitive: false,
    ),
};

const _countryAliases = {
  'US': 'united states|usa|美国|美國',
  'GB': 'united kingdom|britain|英国|英國',
  'DE': 'germany|deutschland|德国|德國',
  'NL': 'netherlands|holland|荷兰|荷蘭',
  'FR': 'france|法国|法國',
  'JP': 'japan|日本',
  'SG': 'singapore|新加坡',
  'HK': 'hong kong|香港',
  'TW': 'taiwan|台湾|台灣',
  'KR': 'south korea|韩国|韓國',
  'CA': 'canada|加拿大',
  'AU': 'australia|澳大利亚|澳大利亞',
  'NZ': 'new zealand|新西兰|紐西蘭',
  'IN': 'india|印度(?!尼)',
  'ID': 'indonesia|印度尼西亚|印尼',
  'MY': 'malaysia|马来西亚|馬來西亞',
  'TH': 'thailand|泰国|泰國',
  'VN': 'vietnam|越南',
  'PH': 'philippines|菲律宾|菲律賓',
  'RU': 'russia|россия|俄罗斯|俄羅斯',
  'UA': 'ukraine|乌克兰|烏克蘭',
  'TR': 'turkey|türkiye|土耳其',
  'CH': 'switzerland|瑞士',
  'SE': 'sweden|瑞典',
  'NO': 'norway|挪威',
  'FI': 'finland|芬兰|芬蘭',
  'DK': 'denmark|丹麦|丹麥',
  'PL': 'poland|波兰|波蘭',
  'IT': 'italy|意大利|義大利',
  'ES': 'spain|西班牙',
  'PT': 'portugal|葡萄牙',
  'IE': 'ireland|爱尔兰|愛爾蘭',
  'AT': 'austria|奥地利|奧地利',
  'BE': 'belgium|比利时|比利時',
  'BR': 'brazil|巴西',
  'AR': 'argentina|阿根廷',
  'MX': 'mexico|墨西哥',
  'ZA': 'south africa|南非',
  'AE': 'united arab emirates|阿联酋|阿聯酋',
  'IL': 'israel|以色列',
  'CN': 'china|中国|中國',
};

String? serverCountryFlag(String name) {
  final flags = _flagPattern.allMatches(name).map((m) => m.group(0)!).toSet();
  if (flags.isNotEmpty) return flags.length == 1 ? flags.single : null;
  final leading = _leadingCode.firstMatch(name)?.group(1);
  final code = leading == 'UK' ? 'GB' : leading;
  final countries = {
    if (_countryAliases.containsKey(code)) code!,
    for (final entry in _countryNames.entries)
      if (entry.value.hasMatch(name)) entry.key,
  };
  if (countries.length != 1) return null;
  return String.fromCharCodes(
    countries.single.codeUnits.map((letter) => letter + 0x1F1A5),
  );
}
