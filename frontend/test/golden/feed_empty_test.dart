// KAMOS — Golden: empty feed renders the empty-state copy.
//
// Deferred per CONTRIBUTING.md "Golden baselines": baselines are captured
// on CI's Linux runner, not on a developer laptop. Run
// `flutter test --update-goldens test/golden/feed_empty_test.dart` from
// the Linux CI image, commit the resulting `goldens/feed_empty.png`, then
// remove the `@Skip` annotation.

@Skip('golden baselines pending CI Linux capture')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/app/theme.dart';
import 'package:kamos/features/feed/screens/feed_screen.dart';
import 'package:kamos/l10n/app_localizations.dart';

void main() {
  testWidgets('empty feed golden', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(extensions: const [KamosTokens.light]),
          home: const FeedScreen(),
        ),
      ),
    );
    await expectLater(
      find.byType(FeedScreen),
      matchesGoldenFile('goldens/feed_empty.png'),
    );
  });
}
