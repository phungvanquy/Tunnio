import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/vpn_import.dart';
import 'package:fl_clash/widgets/vpn_import_progress.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class VpnApplySettings extends ConsumerStatefulWidget {
  const VpnApplySettings({super.key});

  @override
  ConsumerState<VpnApplySettings> createState() => _VpnApplySettingsState();
}

class _VpnApplySettingsState extends ConsumerState<VpnApplySettings> {
  late final VpnAction _action;
  int? _request;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _action = ref.read(vpnActionProvider.notifier);
  }

  @override
  void dispose() {
    if (_request case final request?) _action.cancelIfCurrent(request);
    super.dispose();
  }

  Future<void> _apply(Profile profile) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final operation = _action.edit(profile, expected: profile);
      _request = _action.requestRevision;
      final result = await operation;
      if (!mounted) return;
      if (result.outcome != VpnImportOutcome.success) {
        setState(
          () => _error = result.outcome == VpnImportOutcome.recoveryRequired
              ? context.appLocalizations.vpnRecoveryRequired
              : context.appLocalizations.vpnDraftSaveFailed,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.appLocalizations.vpnDraftSaveFailed);
      }
    } finally {
      _request = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final text = context.appLocalizations;
    return Column(
      children: [
        if (_busy) const LinearProgressIndicator(),
        ListItem(
          key: const Key('vpn-apply-settings'),
          leading: const Icon(Icons.fact_check_outlined),
          title: Text(text.vpnApplySettings),
          subtitle: Text(text.vpnApplySettingsDescription),
          onTap: _busy || profile?.snapshot.generation == null
              ? null
              : () => _apply(profile!),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              liveRegion: true,
              child: SelectableText(
                _error!,
                style: TextStyle(color: context.colorScheme.error),
              ),
            ),
          ),
      ],
    );
  }
}

class VpnConfigurationSection extends ConsumerStatefulWidget {
  const VpnConfigurationSection({super.key});

  @override
  ConsumerState<VpnConfigurationSection> createState() =>
      _VpnConfigurationSectionState();
}

class _VpnConfigurationSectionState
    extends ConsumerState<VpnConfigurationSection> {
  bool _busy = false;
  String? _error;
  VpnImportProgress? _progress;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = context.appLocalizations.vpnSettingsActionFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _recover() async {
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      await ref.read(coreActionProvider.notifier).startCore();
    }
    final action = ref.read(vpnActionProvider.notifier);
    await action.recover();
    if (ref.read(vpnMigrationStateProvider)?.complete != true) {
      final result = await action.initialize();
      if (!result.complete) throw StateError('Recovery incomplete');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final profile = ref.watch(currentProfileProvider);
    final migration = ref.watch(vpnMigrationStateProvider);
    final recovery =
        ref.watch(vpnFailureProvider) == 'recovery_required' ||
        migration?.error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListHeader(title: text.vpnConfiguration),
        if (_busy)
          _progress == null
              ? const LinearProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: VpnImportProgressView(progress: _progress),
                ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              liveRegion: true,
              child: SelectableText(
                _error!,
                style: TextStyle(color: context.colorScheme.error),
              ),
            ),
          ),
        if (recovery)
          ListItem(
            leading: const Icon(Icons.restore),
            title: Text(text.vpnRetry),
            subtitle: Text(text.vpnRecoveryRequired),
            onTap: _busy ? null : () => _run(_recover),
          ),
        ListItem(
          leading: const Icon(Icons.sync_alt),
          title: Text(profile == null ? text.vpnImportTitle : text.vpnReplace),
          onTap: _busy
              ? null
              : () =>
                    showVpnImportDialog(context, replacement: profile != null),
        ),
        if (profile != null) ...[
          if (profile.type == ProfileType.url)
            ListItem(
              leading: const Icon(Icons.refresh),
              title: Text(text.update),
              onTap: _busy
                  ? null
                  : () => _run(() async {
                      final action = ref.read(vpnActionProvider.notifier);
                      final result = await action.refresh(
                        profile,
                        onProgress: (value) {
                          if (mounted && _busy) {
                            setState(() => _progress = value);
                          }
                        },
                      );
                      if (!mounted) return;
                      setState(
                        () => _error = switch (result.outcome) {
                          VpnImportOutcome.success ||
                          VpnImportOutcome.cancelled => null,
                          VpnImportOutcome.recoveryRequired =>
                            text.vpnRecoveryRequired,
                          VpnImportOutcome.failed => vpnImportFailureMessage(
                            result,
                            text,
                          ),
                        },
                      );
                    }),
            ),
        ],
      ],
    );
  }
}
