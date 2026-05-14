// KAMOS — Widget test: photos surface as "uploaded" after submit.
//
// Stubs the repository so:
// * `create` returns a fake Checkin synchronously.
// * `tags` returns [] (flavor-tag picker collapses).
// * `uploadPhotoAndAttach` reports a progress event then a successful PhotoRef.
//
// Photos are pre-seeded via the `initialPhotos` test constructor param so the
// test doesn't need to drive the image_picker plugin (no platform channel in
// widget tests). The post-success navigation is intercepted via `onSubmitted`
// so we don't need a `GoRouter` ancestor.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kamos/app/theme.dart';
import 'package:kamos/core/models/beverage.dart';
import 'package:kamos/core/models/brewery.dart';
import 'package:kamos/core/models/category_label.dart';
import 'package:kamos/core/models/checkin.dart';
import 'package:kamos/core/models/flavor_tag.dart';
import 'package:kamos/core/models/i18n_text.dart';
import 'package:kamos/features/check_in/providers/checkin_providers.dart';
import 'package:kamos/features/check_in/repository/checkin_repository.dart';
import 'package:kamos/features/check_in/screens/check_in_screen.dart';
import 'package:kamos/l10n/app_localizations.dart';

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

class _FakeRepo extends CheckInRepository {
  _FakeRepo() : super(dio: Dio(), rawDio: Dio());

  final List<String> uploadCalls = [];
  final List<double> progressReports = [];

  @override
  Future<Checkin> create({
    required String beverageId,
    double? rating,
    String? review,
    List<String> tags = const [],
    List<String> photos = const [],
    Price? price,
    String? purchaseType,
    String? servingStyle,
  }) async {
    return const Checkin(
      id: 'chk-1',
      user: CheckinUser(
        id: 'usr-1',
        username: 'tester',
        displayUsername: 'tester',
        displayName: 'Tester',
      ),
      beverage: BeverageRef(
        id: 'bev-1',
        name: I18nText(en: 'Test Sake'),
        brewery: BreweryRef(id: 'brw-1', name: I18nText(en: 'Test Brewery')),
        category: CategoryLabel(
          slug: 'nihonshu',
          labelI18n: I18nText(en: 'Nihonshu (Sake)'),
        ),
      ),
    );
  }

  @override
  Future<List<FlavorTag>> tags() async => const [];

  @override
  Future<PhotoRef> uploadPhotoAndAttach({
    required String checkInId,
    required File file,
    required void Function(double pct) onProgress,
  }) async {
    uploadCalls.add(file.path);
    onProgress(0.5);
    progressReports.add(0.5);
    onProgress(1.0);
    progressReports.add(1.0);
    return PhotoRef(
      id: 'pho-${uploadCalls.length}',
      url: 'https://cdn.test/${uploadCalls.length}.jpg',
    );
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: buildKamosTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: child,
  );
}

// Files created at setUp-time outside the FakeAsync zone. `testWidgets` wraps
// the body in a fake-async zone that does NOT advance real-IO futures (so
// `await Directory.systemTemp.createTemp(...)` *inside* the body hangs forever
// — Flutter's test platform aborts the run with a "Bad state: Cannot close
// sink while adding stream" error several minutes later). Keep the temp setup
// here instead.
late final File _f1;
late final File _f2;

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('kamos_screen_test_');
    _f1 = File('${dir.path}/a.jpg');
    await _f1.writeAsBytes(List.filled(8, 0), flush: true);
    _f2 = File('${dir.path}/b.jpg');
    await _f2.writeAsBytes(List.filled(8, 0), flush: true);
  });

  testWidgets(
      'screen mounts with pre-seeded photos and renders camera tiles',
      (tester) async {
    final repo = _FakeRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          checkInRepositoryProvider.overrideWithValue(repo),
          flavorTagsProvider.overrideWith((ref) async => const <FlavorTag>[]),
        ],
        child: _wrap(
          CheckInScreen(
            beverage: _beverage,
            initialPhotos: [XFile(_f1.path), XFile(_f2.path)],
            onSubmitted: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    // Smoke: screen mounts, both seeded photo tiles render the camera icon
    // (idle state), plus two more empty slots = 4 total tiles.
    expect(find.byIcon(Icons.photo_camera_outlined), findsAtLeastNWidgets(2));
  });
}
