// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'KAMOS';

  @override
  String get categoryNihonshu => 'Nihonshu (Sake)';

  @override
  String get categoryShochu => 'Shochu';

  @override
  String get categoryLiqueur => 'Liqueur';

  @override
  String get tabFeed => 'Feed';

  @override
  String get tabSearch => 'Search';

  @override
  String get tabCheckIn => 'Check in';

  @override
  String get tabLists => 'Lists';

  @override
  String get tabMe => 'Me';

  @override
  String get feedHeader => 'Following';

  @override
  String get feedSubheader => 'From people you follow';

  @override
  String get feedEmptyTitle => 'No check-ins yet';

  @override
  String get feedEmptyBody => 'Follow some people, or tap + to log your first.';

  @override
  String get feedMore => 'more';

  @override
  String get searchHeader => 'Discover';

  @override
  String get searchPlaceholder => 'Search breweries, beverages, prefectures.';

  @override
  String get searchNoResultsTitle => 'No results';

  @override
  String get searchNoResultsBody => 'No matches. Try a different search.';

  @override
  String get searchCategoryAll => 'All';

  @override
  String searchResultCountOne(int count) {
    return '$count result';
  }

  @override
  String searchResultCountOther(int count) {
    return '$count results';
  }

  @override
  String ratingValue(String value) {
    return '$value / 5.0';
  }

  @override
  String get ratingTapToRate => 'Tap a star to rate · half-steps allowed';

  @override
  String get ratingLabel => 'Rating';

  @override
  String get checkInTitle => 'Check in';

  @override
  String get checkInCta => 'Check in';

  @override
  String get checkInReviewLabel => 'Review · optional';

  @override
  String get checkInReviewPlaceholder => 'Pear, soft rice, a clean finish…';

  @override
  String get checkInReviewTooLong => 'Review is too long';

  @override
  String get checkInFlavorTags => 'Flavor tags';

  @override
  String get checkInPhotosLabel => 'Photos · up to 4';

  @override
  String checkInPhotoCounter(int count) {
    return '$count / 4';
  }

  @override
  String get checkInPriceLabel => 'Price · optional';

  @override
  String get checkInPurchaseType => 'Purchase type';

  @override
  String get checkInServingStyle => 'Serving style';

  @override
  String get checkInPriceServing => 'Per serving';

  @override
  String get checkInPriceBottle => 'Per bottle';

  @override
  String get checkInPurchaseOnPremise => 'On-premise';

  @override
  String get checkInPurchaseRetail => 'Retail';

  @override
  String get checkInPurchaseGift => 'Gift';

  @override
  String get checkInPurchaseOther => 'Other';

  @override
  String get checkInServingGlass => 'Glass';

  @override
  String get checkInServingCarafe => 'Carafe';

  @override
  String get checkInServingBottle => 'Bottle';

  @override
  String get checkInServingCan => 'Can';

  @override
  String get checkInServingOther => 'Other';

  @override
  String get checkInFirstToast => 'First check-in saved. Kanpai!';

  @override
  String get checkInPostFailed => 'Could not post. Tap to retry.';

  @override
  String get checkInPhotoLimitReached => 'You can attach up to 4 photos.';

  @override
  String get flavorSweetness => 'Sweetness';

  @override
  String get flavorBody => 'Body';

  @override
  String get flavorAcidity => 'Acidity';

  @override
  String get flavorCharacter => 'Character';

  @override
  String get flavorFinish => 'Finish';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authSignUp => 'Create account';

  @override
  String get authForgotTitle => 'Reset password';

  @override
  String get authForgotBody =>
      'Enter your email. We will send a reset link valid for 1 hour.';

  @override
  String get authForgotSend => 'Send reset link';

  @override
  String get authBackToSignIn => 'Back to sign in';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authOr => 'or';

  @override
  String get authContinueGoogle => 'Continue with Google';

  @override
  String get authNoAccount => 'No account yet?';

  @override
  String get authHaveAccount => 'Already have an account?';

  @override
  String get authUsernameLabel => 'Username';

  @override
  String get authUsernameHelper =>
      '3–30 chars · letters, numbers, underscores · case-insensitive';

  @override
  String get authUsernameInvalid => 'Invalid username';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordHelper => 'At least 8 characters';

  @override
  String get authPasswordTooShort => 'Too short';

  @override
  String get authTagline => 'Discover and log Nihonshu, Shochu, and Liqueur.';

  @override
  String get authVerifyTitle => 'Verify your email';

  @override
  String get authVerifySent => 'We sent a verification link to';

  @override
  String get authVerifyExpiry =>
      'The link expires in 24 hours. You can still use the app while unverified.';

  @override
  String get authVerifyContinue => 'Continue to KAMOS';

  @override
  String get authVerifyResend => 'Resend email';

  @override
  String get verifyEmailTitle => 'Verifying your email';

  @override
  String get verifyEmailLoading => 'Confirming your verification link…';

  @override
  String get verifyEmailSuccess => 'Your email is verified.';

  @override
  String get verifyEmailFailure =>
      'We could not verify this link. It may have expired.';

  @override
  String get verifyEmailBackToAuth => 'Back to sign in';

  @override
  String get profileEdit => 'Edit profile';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profilePrivate => 'Private';

  @override
  String get profileChangeAvatar => 'Change avatar';

  @override
  String get profileDisplayName => 'Display name';

  @override
  String get profileBioLabel => 'Bio';

  @override
  String get profileUsernameLocked => 'Cannot be changed.';

  @override
  String get profileStatCheckins => 'Check-ins';

  @override
  String get profileStatUnique => 'Unique';

  @override
  String get profileStatFollowers => 'Followers';

  @override
  String get profileStatFollowing => 'Following';

  @override
  String get profileRecent => 'Recent check-ins';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsEmail => 'Email';

  @override
  String get settingsEmailVerification => 'Email verification';

  @override
  String get settingsEmailVerified => 'Verified';

  @override
  String get settingsEmailPending => 'Pending';

  @override
  String get settingsPassword => 'Password';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsPrivateAccount => 'Private account';

  @override
  String get settingsPrivateBody =>
      'Approve followers individually. Check-ins are visible only to approved followers.';

  @override
  String get settingsPreferences => 'Preferences';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsDangerZone => 'Danger zone';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDeleteAccountHelper =>
      'Soft-delete · username held for 30 days before release.';

  @override
  String get settingsConfirmDelete => 'Delete account?';

  @override
  String get settingsConfirmDeleteBody =>
      'Your account will be soft-deleted. Your username will be held for 30 days before it can be claimed by someone else. Check-ins and collections will be removed from public view.';

  @override
  String get settingsVersion => 'KAMOS · v0.1.0';

  @override
  String get collectionsHeader => 'Collections';

  @override
  String get collectionsNewList => 'New list';

  @override
  String get collectionsEmptyTitle => 'No collections yet';

  @override
  String get collectionsEmptyBody => 'Tap \"New list\" to start a collection.';

  @override
  String get collectionsAddTo => 'Add to collections';

  @override
  String get collectionsCreateNew => 'Create new collection';

  @override
  String get collectionsNamePlaceholder => 'Collection name';

  @override
  String get collectionsPrivate => 'Private';

  @override
  String collectionsBottleCountOne(int count) {
    return '$count bottle';
  }

  @override
  String collectionsBottleCountOther(int count) {
    return '$count bottles';
  }

  @override
  String get collectionsRename => 'Rename';

  @override
  String get collectionsDeleteAction => 'Delete collection';

  @override
  String get collectionsEmptyEntries => 'Empty collection';

  @override
  String get collectionsEmptyEntriesBody =>
      'Add beverages from a beverage page or check-in screen.';

  @override
  String get collectionsConfirmDelete => 'Delete this collection?';

  @override
  String get collectionsConfirmDeleteBody =>
      'This removes the collection and all of its entries. The beverages themselves are unaffected.';

  @override
  String get inboxTitle => 'Follow requests';

  @override
  String get inboxApprove => 'Approve';

  @override
  String get inboxDecline => 'Decline';

  @override
  String get inboxEmptyTitle => 'No pending requests';

  @override
  String get inboxEmptyBody =>
      'Follow requests appear here while your account is private.';

  @override
  String get beverageDetailAbv => 'ABV';

  @override
  String get beverageDetailSeimai => 'Seimai';

  @override
  String get beverageDetailRegion => 'Region';

  @override
  String get beverageDetailType => 'Type';

  @override
  String get beverageDetailAddToList => 'List';

  @override
  String get beverageDetailAggregatedFlavor => 'Aggregated flavor';

  @override
  String get beverageDetailAbout => 'About the brewery';

  @override
  String get beverageDetailRecent => 'Recent check-ins';

  @override
  String get beverageNoCheckinsTitle => 'No check-ins yet';

  @override
  String get beverageNoCheckinsBody => 'Be the first to log this bottle.';

  @override
  String get breweryOverline => 'Brewery';

  @override
  String get breweryFounded => 'Founded';

  @override
  String get breweryBeverages => 'Beverages';

  @override
  String get breweryNoBeverages => 'No beverages yet';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionPost => 'Post';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionLoadingMore => 'Loading more';

  @override
  String get actionEndOfList => 'End of list';

  @override
  String get actionEndOfFeed => 'End of feed';

  @override
  String get errorGeneric => 'Could not load. Tap to retry.';

  @override
  String get errorNetwork => 'No connection. Tap to retry.';

  @override
  String get errorUnauthorized => 'Please sign in again.';

  @override
  String get loadingLabel => 'Loading';
}
