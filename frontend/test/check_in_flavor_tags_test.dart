// KAMOS — Widget test for the flavor-tag browse sheet opened from
// CheckInScreen. Asserts that tags from `flavorTagsProvider` render inside
// the browse sheet with locale-resolved labels (en in this test) — the
// inline compose row only renders the currently-selected tags now, so this
// test drives the "+ Browse" affordance to surface the full catalog.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/app/theme.dart';
import 'package:kamos/core/models/beverage.dart';
import 'package:kamos/core/models/category_label.dart';
import 'package:kamos/core/models/flavor_tag.dart';
import 'package:kamos/core/models/i18n_text.dart';
import 'package:kamos/core/models/producer.dart';
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
  producer: Producer(
    id: 'prd-1',
    name: I18nText(en: 'Test Producer'),
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
      'flavor-tag browse sheet renders all tags with locale-resolved labels',
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

    // The inline compose row only renders currently-selected tags (none
    // selected at this point) so the catalog should not appear yet.
    expect(find.text('Dry'), findsNothing);
    expect(find.text('Fruity'), findsNothing);

    // Open the browse sheet via the "+ Browse" pill.
    await tester.tap(find.text('+ Browse'));
    await tester.pumpAndSettle();

    // Both tag labels appear inside the sheet (en locale resolves `name.en`).
    expect(find.text('Dry'), findsOneWidget);
    expect(find.text('Fruity'), findsOneWidget);
  });
}
