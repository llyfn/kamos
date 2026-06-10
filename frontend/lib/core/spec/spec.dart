// DO NOT EDIT. Generated from specs/invariants.yaml by scripts/gen-spec.py.
// Edit the YAML and re-run the generator; CI fails on drift.

// ignore_for_file: constant_identifier_names

class KamosSpec {
  KamosSpec._();

  static const int schemaVersion = 1;

  // Rating (SPEC §4.2)
  static const double ratingMin = 0.5;
  static const double ratingMax = 5.0;
  static const double ratingStep = 0.25;
  static const int ratingLevels = 19;

  // Photos (SPEC §4.1)
  static const int photosMaxPerSubmission = 1;
  static const int photosLegacyReadableCap = 4;

  // Text caps
  static const int reviewMaxChars = 500;
  static const int commentMinChars = 1;
  static const int commentMaxChars = 500;
  static const int beverageRequestNotesMax = 500;
  static const int beverageRequestStringMax = 200;
  static const int beverageRequestPayloadMax = 4096;
  static const int collectionEntryNoteMax = 200;
  static const int collectionNameMax = 50;
  static const int displayNameMin = 1;
  static const int displayNameMax = 50;
  static const int bioMax = 200;
  static const int passwordMin = 8;

  // Username (SPEC §3.2)
  static const String usernameRegex = r'^[A-Za-z0-9_]{3,30}$';
  static const String usernameStorageRegex = r'^[a-z0-9_]{3,30}$';
  static const int usernameMinChars = 3;
  static const int usernameMaxChars = 30;

  static const int emailVerificationLinkTtlHours = 24;

  // Pagination (SPEC §5.2)
  static const int pageSizeDefault = 20;
  static const int pageSizeMax = 50;
  static const int pageSizeFeed = 20;
  static const int pageSizeNotifications = 20;
  static const int pageSizeFoursquare = 20;

  // Locales (SPEC §8)
  static const List<String> supportedLocales = ['en', 'ja', 'ko'];
  static const String localeDefault = 'en';
  static const String localeFallback = 'en';

  static const int usernameHoldDays = 30;
  static const int notificationsReadRetentionDays = 180;

  static const int cursorSecretMinBytes = 32;

  // Category slugs (SPEC §2.1)
  static const List<String> categorySlugs = ['nihonshu', 'shochu', 'liqueur'];

  // CategoryNames[slug]![locale]! -> localized label.
  static const Map<String, Map<String, String>> categoryNames = {
    'nihonshu': {'en': 'Nihonshu (Sake)', 'ja': '日本酒', 'ko': '니혼슈 (사케)'},
    'shochu': {'en': 'Shochu', 'ja': '焼酎', 'ko': '쇼츄'},
    'liqueur': {'en': 'Liqueur', 'ja': 'リキュール', 'ko': '리큐어'},
  };

  static const Map<String, String> defaultCollectionInventory = {'en': 'Inventory', 'ja': 'インベントリー', 'ko': '인벤토리'};
  static const Map<String, String> defaultCollectionWishlist = {'en': 'Wishlist', 'ja': 'ウィッシュリスト', 'ko': '위시리스트'};

  static const List<String> purchaseTypes = ['on_premise', 'retail', 'gift', 'other'];
  static const List<String> priceCurrencies = ['JPY', 'KRW', 'USD'];
  static const List<String> priceModes = ['serving', 'bottle'];
}

