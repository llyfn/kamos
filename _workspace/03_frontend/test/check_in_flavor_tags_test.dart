// KAMOS — Widget test for the flavor-tag chip picker on CheckInScreen.
// Asserts that tags from `flavorTagsProvider` render with locale-resolved
// labels (en in this test) instead of the previously-hardcoded English strings.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/app/theme.dart';
import 'package:kamos/core/models/beverage.dart';
import 'package:kamos/core/models/brewery.dart';
import 'package:kamos/core/models/category_label.dart';
import 'package:kamos/core/models/flavor_tag.dart';
import 'package:kamos/core/models/i18n_text.dart';
import 'package:kamos/features/check_in/providers/checkin_providers.dart';
import 'package:kamos/features/check_in/screens/check_in_screen.dart';
import 'package:kamos/l10n/app_localizations.dart';

const _fakeTags = <FlavorTag>[
  FlavorTag(
    id: '00000000-0000-0000-0000-000000000001',
    slug: 'dry',
    dimension: 'sweetness',
    name: I18nText(en: 'Dry', ja: '辛口', ko: '드라이'),
  ),
  FlavorTag(
    id: '00000000-0000-0000-0000-000000000002',
    slug: 'fruity',
    dimension: 'character',
    name: I18nText(en: 'Fruity', ja: 'フルーティ', ko: '과일향'),
  ),
];

const _beverage = Beverage(
  id: 'bev-1',
  name: I18nText(en: 'Test Sake', ja: 'テスト酒'),
  brewery: Brewery(
    id: 'brw-1',
    name: I18nText(en: 'Test Brewery'),
  ),
  category: CategoryLabel(
    slug: 'nihonshu',
    labelI18n: I18nText(en: 'Nihonshu (Sake)'),
  ),
);

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: buildKamosTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: child,
  );
}

void main() {
  testWidgets(
      'flavor-tag chips render with locale-resolved labels from the provider',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          flavorTagsProvider.overrideWith((ref) async => _fakeTags),
        ],
        child: _wrap(const CheckInScreen(beverage: _beverage)),
      ),
    );

    // Let the FutureProvider resolve and the screen rebuild with data.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Both tag labels appear (en locale resolves `name.en`).
    expect(find.text('Dry'), findsOneWidget);
    expect(find.text('Fruity'), findsOneWidget);
  });
}
