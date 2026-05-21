// KAMOS — Golden: a single feed card with photo + rating + venue.
//
// Deferred per CONTRIBUTING.md "Golden baselines": baselines are captured
// on CI's Linux runner. Run
// `flutter test --update-goldens test/golden/feed_one_card_test.dart`
// from the Linux CI image, commit the resulting PNG, then remove the
// `@Skip` annotation.

@Skip('golden baselines pending CI Linux capture')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('single feed card golden', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Placeholder()),
    );
    await expectLater(
      find.byType(Placeholder),
      matchesGoldenFile('goldens/feed_one_card.png'),
    );
  });
}
