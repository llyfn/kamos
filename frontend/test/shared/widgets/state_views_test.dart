// KAMOS — Widget tests for LogoLoader and the AsyncWidget loading-branch
// substitution (center=true → LogoLoader, center=false → LoadingView).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/app/theme.dart';
import 'package:kamos/l10n/app_localizations.dart';
import 'package:kamos/shared/widgets/async_widget.dart';
import 'package:kamos/shared/widgets/state_views.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: buildKamosTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    );

void main() {
  group('LogoLoader', () {
    testWidgets('renders the KAMOS cheers mark, centered', (tester) async {
      await tester.pumpWidget(_wrap(const LogoLoader()));
      // Don't pumpAndSettle — the loader has an infinite-pulse controller
      // that would never settle. A single pump is enough to mount it.
      await tester.pump();

      final image = tester.widget<Image>(find.byType(Image));
      final asset = image.image as AssetImage;
      expect(asset.assetName, 'assets/images/logo_mark.png');

      // The internal Center ensures the asset sits in the middle of the
      // available space without callers needing to wrap it themselves.
      expect(find.byType(Center), findsWidgets);
    });

    testWidgets('respects the size parameter', (tester) async {
      await tester.pumpWidget(_wrap(const LogoLoader(size: 64)));
      await tester.pump();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 64);
      expect(image.height, 64);
    });
  });

  group('AsyncWidget loading branch', () {
    testWidgets('center=true → LogoLoader (full-page boot)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: _wrap(
            AsyncWidget<int>(
              value: const AsyncLoading<int>(),
              center: true,
              data: (v) => Text('$v'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(LogoLoader), findsOneWidget);
      expect(find.byType(LoadingView), findsNothing);
    });

    testWidgets('center=false → LoadingView (inline)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: _wrap(
            AsyncWidget<int>(
              value: const AsyncLoading<int>(),
              data: (v) => Text('$v'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(LoadingView), findsOneWidget);
      expect(find.byType(LogoLoader), findsNothing);
    });

    testWidgets('custom loading builder is respected (no substitution)',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: _wrap(
            AsyncWidget<int>(
              value: const AsyncLoading<int>(),
              center: true,
              loading: () => const Text('CUSTOM_LOADING'),
              data: (v) => Text('$v'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('CUSTOM_LOADING'), findsOneWidget);
      expect(find.byType(LogoLoader), findsNothing);
      expect(find.byType(LoadingView), findsNothing);
    });
  });
}
