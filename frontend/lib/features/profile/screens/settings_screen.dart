// KAMOS — Settings screen (SPEC §3.3, §5.1, §8).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/i18n/locale_provider.dart';
import '../../../core/models/user.dart';
import '../../../core/spec/spec.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/providers/auth_state.dart';
import '../providers/profile_providers.dart';
import '../repository/profile_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final async = ref.watch(meProvider);

    // The "Suggest a beverage" tile must remain reachable even if `meProvider`
    // errors — it does not depend on profile data. Render it as a top-level
    // section, OUTSIDE the `async.when` switch. Profile-dependent sections
    // (email, privacy, language, danger zone) stay gated on the data branch.
    final suggestTile = ListTile(
      title: Text(l.settingsSuggestBeverage),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/beverage-requests/new'),
    );

    // Sign-out is also session-only — it does not depend on `meProvider`
    // returning successfully (in fact, if `meProvider` is erroring on auth
    // we especially want this tile reachable). Lives just above the
    // Danger Zone so destructive options group together.
    final signOutTile = ListTile(
      leading: const Icon(Icons.logout),
      title: Text(l.settingsSignOut),
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(l.settingsSignOutConfirmTitle),
            content: Text(l.settingsSignOutConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.actionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.settingsSignOut),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await ref.read(authStateProvider.notifier).logout();
          if (context.mounted) context.go('/auth');
        }
      },
    );

    // Profile-dependent slices (account, privacy, language tile, danger zone)
    // collapse to a single status widget when `meProvider` is loading/erroring.
    final accountPrivacy = async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: LogoLoader(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: ErrorView(message: l.errorGeneric)),
      ),
      data: (me) => _AccountAndPrivacySections(me: me),
    );

    final languageTile = async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (me) => _LanguageTile(me: me),
    );

    final dangerZone = async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (_) => const _DangerZoneSection(),
    );

    final editProfileTile = ListTile(
      leading: const Icon(Icons.person_outline),
      title: Text(l.profileEdit),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/me/edit'),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.profileSettings)),
      body: ListView(
        children: [
          editProfileTile,
          accountPrivacy,
          // "Preferences" header + "Suggest a beverage" tile are reachable
          // regardless of `meProvider` state — the suggest route does not
          // depend on profile data. Language tile slots in above when data
          // is available.
          _SectionTitle(l.settingsPreferences),
          languageTile,
          suggestTile,
          signOutTile,
          dangerZone,
          const SizedBox(height: 24),
          Center(
            child: Text(
              l.settingsVersion,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                color: t.fg3,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

String _localeLabel(String code) {
  switch (code) {
    case 'ja':
      return '日本語';
    case 'ko':
      return '한국어';
    case 'en':
    default:
      return 'English';
  }
}

/// Account + Privacy sections. Renders only when `meProvider` is in the
/// data state.
class _AccountAndPrivacySections extends ConsumerWidget {
  const _AccountAndPrivacySections({required this.me});
  final Me me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(l.settingsAccount),
        _Row(label: l.settingsEmail, value: me.user.email ?? '', onTap: () {}),
        _Row(
          label: l.settingsEmailVerification,
          value: me.user.emailVerified
              ? l.settingsEmailVerified
              : l.settingsEmailPending,
        ),
        _Row(label: l.settingsPassword, value: '••••••••', onTap: () {}),
        _SectionTitle(l.settingsPrivacy),
        SwitchListTile(
          title: Text(l.settingsPrivateAccount),
          subtitle: Text(l.settingsPrivateBody),
          value: me.user.privacyMode == 'private',
          onChanged: (v) async {
            await ref
                .read(profileRepositoryProvider)
                .updateMe(privacyMode: v ? 'private' : 'public');
            ref.invalidate(meProvider);
          },
          activeThumbColor: t.ai,
        ),
      ],
    );
  }
}

/// Language picker tile. Renders only when `meProvider` is in the data state
/// (needs `me.user.locale` to show the current value).
class _LanguageTile extends ConsumerWidget {
  const _LanguageTile({required this.me});
  final Me me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return ListTile(
      title: Text(l.settingsLanguage),
      subtitle: Text(_localeLabel(me.user.locale)),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (_) => ListView(
            shrinkWrap: true,
            children: const [
              _LocaleTile(code: 'en', label: 'English'),
              _LocaleTile(code: 'ja', label: '日本語'),
              _LocaleTile(code: 'ko', label: '한국어'),
            ],
          ),
        );
        if (picked != null) {
          // Flip locally first so the UI re-renders before the network call
          // round-trips. `meProvider` invalidation refreshes the canonical
          // value from the server and the watcher in `appLocaleProvider`
          // reconciles to it.
          ref.read(appLocaleProvider.notifier).setLocale(picked);
          await ref.read(profileRepositoryProvider).updateMe(locale: picked);
          ref.invalidate(meProvider);
        }
      },
    );
  }
}

/// Danger zone (account deletion). Renders only when `meProvider` is in the
/// data state — deletion requires a confirmed session.
class _DangerZoneSection extends ConsumerWidget {
  const _DangerZoneSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(l.settingsDangerZone),
        ListTile(
          title: Text(
            l.settingsDeleteAccount,
            style: TextStyle(color: t.fgDanger, fontWeight: FontWeight.w600),
          ),
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(l.settingsConfirmDelete),
                content: Text(
                  l.settingsConfirmDeleteBody(KamosSpec.usernameHoldDays),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l.actionCancel),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: t.akane),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l.actionDelete),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await ref.read(profileRepositoryProvider).deleteMe();
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) context.go('/auth');
            }
          },
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.3,
          color: t.fg1,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, this.value, this.onTap});
  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListTile(
      title: Text(label),
      trailing: value == null
          ? null
          : Text(value!, style: TextStyle(color: t.fg2)),
      onTap: onTap,
    );
  }
}

class _LocaleTile extends StatelessWidget {
  const _LocaleTile({required this.code, required this.label});
  final String code;
  final String label;
  @override
  Widget build(BuildContext context) =>
      ListTile(title: Text(label), onTap: () => Navigator.pop(context, code));
}
