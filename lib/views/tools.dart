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
  const ToolsView({super.key, this.isDesktop});

  final bool? isDesktop;

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
        items: [
          if (isDesktop ?? system.isDesktop) const _ConnectionModeItem(),
          const _LocaleItem(),
          const _ThemeItem(),
          const _SettingItem(),
        ],
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

class _ConnectionModeItem extends ConsumerWidget {
  const _ConnectionModeItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.appLocalizations;
    final defaultsPending = ref.watch(
      appSettingProvider.select((state) => state.vpnDefaultsPending),
    );
    final tun = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.enable),
    );
    final proxy = ref.watch(
      networkSettingProvider.select((state) => state.systemProxy),
    );
    final enableTun = defaultsPending || tun;
    final label = switch ((enableTun, proxy)) {
      (true, true) => text.vpnConnectionModeCombined,
      (true, false) => text.vpnConnectionModeTun,
      (false, true) => text.systemProxy,
      (false, false) => text.vpnConnectionModeManual,
    };
    return ListItem(
      leading: const Icon(Icons.vpn_key_outlined),
      title: Text(text.vpnConnectionMode),
      subtitle: Text(label),
      onTap: () async {
        final selected = await dialogs.showCommonDialog<bool>(
          child: CommonDialog(
            title: text.vpnConnectionMode,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: Builder(
              builder: (context) => RadioGroup<bool>(
                groupValue: enableTun ? true : (proxy ? false : null),
                onChanged: (value) => Navigator.of(context).pop(value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListItem<bool>.radio(
                      value: true,
                      onTap: () => Navigator.of(context).pop(true),
                      title: Text(text.vpnConnectionModeTun),
                      subtitle: Text(text.vpnConnectionModeTunDescription),
                    ),
                    ListItem<bool>.radio(
                      value: false,
                      onTap: () => Navigator.of(context).pop(false),
                      title: Text(text.systemProxy),
                      subtitle: Text(text.vpnConnectionModeProxyDescription),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        if (selected == null || !context.mounted) return;
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(vpnDefaultsPending: false));
        ref
            .read(networkSettingProvider.notifier)
            .update((state) => state.copyWith(systemProxy: !selected));
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith.tun(enable: selected));
      },
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
