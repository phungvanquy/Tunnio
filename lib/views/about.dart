import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AboutView extends ConsumerWidget {
  const AboutView({super.key});

  Future<void> _checkUpdate(BuildContext context, WidgetRef ref) async {
    final commonAction = ref.read(commonActionProvider.notifier);
    final data = await globalState.safeRun<Map<String, dynamic>?>(
      request.checkForUpdate,
      title: context.appLocalizations.checkUpdate,
    );
    unawaited(commonAction.checkUpdateResultHandle(data: data, isUser: true));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final textTheme = context.textTheme;
    return BaseScaffold(
      title: appLocalizations.about,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            children: [
              _DeveloperModeDetector(
                onEnterDeveloperMode: () {
                  ref
                      .read(appSettingProvider.notifier)
                      .update((state) => state.copyWith(developerMode: true));
                  context.showNotifier(
                    appLocalizations.developerModeEnableTip,
                    level: MessageLevel.success,
                  );
                },
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/icon.png',
                      width: 128,
                      height: 128,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      appName,
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: ShapeDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        shape: AppShape.full,
                      ),
                      child: Text(
                        globalState.packageInfo.version,
                        textAlign: TextAlign.center,
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                appLocalizations.desc,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.tonalIcon(
                onPressed: () => _checkUpdate(context, ref),
                icon: const Icon(Icons.system_update_alt_rounded),
                label: Text(
                  appLocalizations.checkUpdate,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeveloperModeDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onEnterDeveloperMode;

  const _DeveloperModeDetector({
    required this.child,
    required this.onEnterDeveloperMode,
  });

  @override
  State<_DeveloperModeDetector> createState() => _DeveloperModeDetectorState();
}

class _DeveloperModeDetectorState extends State<_DeveloperModeDetector> {
  int _counter = 0;
  Timer? _timer;

  void _handleTap() {
    _counter++;
    if (_counter >= 5) {
      widget.onEnterDeveloperMode();
      _resetCounter();
    } else {
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 1), _resetCounter);
    }
  }

  void _resetCounter() {
    _counter = 0;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: _handleTap, child: widget.child);
  }
}
