// KAMOS — Active UI locale, fed into MaterialApp.locale.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/providers/profile_providers.dart';

/// Resolves the locale MaterialApp should render in:
/// 1. an in-process override set by the Settings picker (instant flip), or
/// 2. the signed-in user's stored `locale` from `meProvider`, or
/// 3. null — fall through to the platform locale resolution callback.
///
/// Persistence rides on `meProvider`: the picker writes to `/v1/users/me`,
/// invalidates `meProvider`, and on next app start the locale is read back
/// from the user record.
final appLocaleProvider =
    NotifierProvider<AppLocaleNotifier, Locale?>(AppLocaleNotifier.new);

class AppLocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    final me = ref.watch(meProvider);
    return me.maybeWhen(
      data: (me) => _supported(me.user.locale),
      orElse: () => _override,
    );
  }

  Locale? _override;

  /// Applied immediately so the Settings screen flips before the server
  /// round-trip and the subsequent `meProvider` refresh land.
  void setLocale(String code) {
    _override = _supported(code);
    state = _override;
  }
}

Locale? _supported(String? code) {
  switch (code) {
    case 'en':
    case 'ja':
    case 'ko':
      return Locale(code!);
    default:
      return null;
  }
}
