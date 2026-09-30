import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/views/about.dart';
import 'package:fl_clash/views/application_setting.dart';
import 'package:fl_clash/views/theme.dart';
import 'package:fl_clash/views/vpn_configuration.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class ToolsView extends StatelessWidget {
  const ToolsView({super.key});

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final items = <Widget>[
      const VpnConfigurationSection(),
      if (system.isAndroid)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text.vpnAndroidHelpTitle,
                style: context.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(text.vpnAndroidHelp),
            ],
          ),
        ),
      ...generateSection(
        title: text.settings,
        items: const [_LocaleItem(), _ThemeItem(), _SettingItem()],
      ),
      ...generateSection(title: text.other, items: const [_InfoItem()]),
    ];
    return CommonScaffold(
      title: text.settings,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: ListView.builder(
            key: toolsStoreKey,
            itemCount: items.length,
            itemBuilder: (_, index) => items[index],
            padding: const EdgeInsets.only(bottom: 20),
          ),
        ),
      ),
    );
  }
}

class _LocaleItem extends ConsumerWidget {
  const _LocaleItem();

  String _getLocaleString(BuildContext context, Locale? locale) =>
      locale?.label ?? context.appLocalizations.defaultText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(
      appSettingProvider.select((state) => state.locale),
    );
    final currentLocale = getLocaleForString(locale);
    return ListItem<Locale?>.options(
      leading: const Icon(Icons.language_outlined),
      title: Text(context.appLocalizations.language),
      subtitle: Text(_getLocaleString(context, currentLocale)),
      dialogTitle: context.appLocalizations.language,
      options: [null, ...AppLocalizations.delegate.supportedLocales],
      onChanged: (Locale? locale) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(locale: locale?.toString()));
      },
      textBuilder: (locale) => _getLocaleString(context, locale),
      value: currentLocale,
    );
  }
}

class _ThemeItem extends StatelessWidget {
  const _ThemeItem();

  @override
  Widget build(BuildContext context) => ListItem.open(
    leading: const Icon(Icons.style),
    title: Text(context.appLocalizations.theme),
    subtitle: Text(context.appLocalizations.themeDesc),
    widget: const ThemeView(),
  );
}

class _SettingItem extends StatelessWidget {
  const _SettingItem();

  @override
  Widget build(BuildContext context) => ListItem.open(
    leading: const Icon(Icons.settings),
    title: Text(context.appLocalizations.application),
    subtitle: Text(context.appLocalizations.applicationDesc),
    widget: const ApplicationSettingView(),
  );
}

class _InfoItem extends StatelessWidget {
  const _InfoItem();

  @override
  Widget build(BuildContext context) => ListItem.open(
    leading: const Icon(Icons.info),
    title: Text(context.appLocalizations.about),
    widget: const AboutView(),
  );
}
