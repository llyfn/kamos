import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'KAMOS'**
  String get appName;

  /// No description provided for @categoryNihonshu.
  ///
  /// In en, this message translates to:
  /// **'Nihonshu (Sake)'**
  String get categoryNihonshu;

  /// No description provided for @categoryShochu.
  ///
  /// In en, this message translates to:
  /// **'Shochu'**
  String get categoryShochu;

  /// No description provided for @categoryLiqueur.
  ///
  /// In en, this message translates to:
  /// **'Liqueur'**
  String get categoryLiqueur;

  /// No description provided for @tabFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get tabFeed;

  /// No description provided for @tabSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get tabSearch;

  /// No description provided for @tabCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get tabCheckIn;

  /// No description provided for @tabLists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get tabLists;

  /// No description provided for @tabMe.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get tabMe;

  /// No description provided for @feedHeader.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get feedHeader;

  /// No description provided for @feedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No check-ins yet'**
  String get feedEmptyTitle;

  /// No description provided for @feedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Follow some people, or tap + to log your first.'**
  String get feedEmptyBody;

  /// No description provided for @feedMore.
  ///
  /// In en, this message translates to:
  /// **'more'**
  String get feedMore;

  /// No description provided for @searchHeader.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get searchHeader;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search breweries, beverages, prefectures.'**
  String get searchPlaceholder;

  /// No description provided for @searchNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get searchNoResultsTitle;

  /// No description provided for @searchNoResultsBody.
  ///
  /// In en, this message translates to:
  /// **'No matches. Try a different search.'**
  String get searchNoResultsBody;

  /// No description provided for @searchCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get searchCategoryAll;

  /// No description provided for @searchResultCountOne.
  ///
  /// In en, this message translates to:
  /// **'{count} result'**
  String searchResultCountOne(int count);

  /// No description provided for @searchResultCountOther.
  ///
  /// In en, this message translates to:
  /// **'{count} results'**
  String searchResultCountOther(int count);

  /// No description provided for @ratingValue.
  ///
  /// In en, this message translates to:
  /// **'{value} / 5.0'**
  String ratingValue(String value);

  /// No description provided for @ratingTapToRate.
  ///
  /// In en, this message translates to:
  /// **'Tap a star to rate · half-steps allowed'**
  String get ratingTapToRate;

  /// No description provided for @ratingLabel.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get ratingLabel;

  /// No description provided for @checkInTitle.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get checkInTitle;

  /// No description provided for @checkInCta.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get checkInCta;

  /// No description provided for @checkInReviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get checkInReviewLabel;

  /// No description provided for @checkInReviewPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Pear, soft rice, a clean finish…'**
  String get checkInReviewPlaceholder;

  /// No description provided for @checkInReviewTooLong.
  ///
  /// In en, this message translates to:
  /// **'Review is too long'**
  String get checkInReviewTooLong;

  /// No description provided for @checkInFlavorTags.
  ///
  /// In en, this message translates to:
  /// **'Flavor tags'**
  String get checkInFlavorTags;

  /// No description provided for @checkInPhotosLabel.
  ///
  /// In en, this message translates to:
  /// **'Photos · up to 4'**
  String get checkInPhotosLabel;

  /// No description provided for @checkInPhotoCounter.
  ///
  /// In en, this message translates to:
  /// **'{count} / 4'**
  String checkInPhotoCounter(int count);

  /// No description provided for @checkInPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get checkInPriceLabel;

  /// No description provided for @checkInPurchaseType.
  ///
  /// In en, this message translates to:
  /// **'Purchase type'**
  String get checkInPurchaseType;

  /// No description provided for @checkInServingStyle.
  ///
  /// In en, this message translates to:
  /// **'Serving style'**
  String get checkInServingStyle;

  /// No description provided for @checkInPriceServing.
  ///
  /// In en, this message translates to:
  /// **'Per serving'**
  String get checkInPriceServing;

  /// No description provided for @checkInPriceBottle.
  ///
  /// In en, this message translates to:
  /// **'Per bottle'**
  String get checkInPriceBottle;

  /// No description provided for @checkInPurchaseOnPremise.
  ///
  /// In en, this message translates to:
  /// **'On-premise'**
  String get checkInPurchaseOnPremise;

  /// No description provided for @checkInPurchaseRetail.
  ///
  /// In en, this message translates to:
  /// **'Retail'**
  String get checkInPurchaseRetail;

  /// No description provided for @checkInPurchaseGift.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get checkInPurchaseGift;

  /// No description provided for @checkInPurchaseOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get checkInPurchaseOther;

  /// No description provided for @checkInServingGlass.
  ///
  /// In en, this message translates to:
  /// **'Glass'**
  String get checkInServingGlass;

  /// No description provided for @checkInServingCarafe.
  ///
  /// In en, this message translates to:
  /// **'Carafe'**
  String get checkInServingCarafe;

  /// No description provided for @checkInServingBottle.
  ///
  /// In en, this message translates to:
  /// **'Bottle'**
  String get checkInServingBottle;

  /// No description provided for @checkInServingCan.
  ///
  /// In en, this message translates to:
  /// **'Can'**
  String get checkInServingCan;

  /// No description provided for @checkInServingOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get checkInServingOther;

  /// No description provided for @checkInFirstToast.
  ///
  /// In en, this message translates to:
  /// **'First check-in saved. Kanpai!'**
  String get checkInFirstToast;

  /// No description provided for @checkInPostFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not post. Tap to retry.'**
  String get checkInPostFailed;

  /// No description provided for @checkInPhotoLimitReached.
  ///
  /// In en, this message translates to:
  /// **'You can attach up to 4 photos.'**
  String get checkInPhotoLimitReached;

  /// No description provided for @photoUploadDisabled.
  ///
  /// In en, this message translates to:
  /// **'Photo upload is not available — saved without photos.'**
  String get photoUploadDisabled;

  /// No description provided for @checkInWhereLabel.
  ///
  /// In en, this message translates to:
  /// **'Where?'**
  String get checkInWhereLabel;

  /// No description provided for @checkInWhereCta.
  ///
  /// In en, this message translates to:
  /// **'Add a venue'**
  String get checkInWhereCta;

  /// No description provided for @venuePickerSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search for a venue'**
  String get venuePickerSearchPlaceholder;

  /// No description provided for @venuePickerEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Search for a bar, restaurant, or shop.'**
  String get venuePickerEmptyHint;

  /// No description provided for @venuePickerNoResults.
  ///
  /// In en, this message translates to:
  /// **'No venues found.'**
  String get venuePickerNoResults;

  /// No description provided for @venuePickerDisabled.
  ///
  /// In en, this message translates to:
  /// **'Venue search is not configured. You can still check-in without a venue.'**
  String get venuePickerDisabled;

  /// No description provided for @venuePickerRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Slow down — try again in a moment.'**
  String get venuePickerRateLimited;

  /// Feed card venue footer. Word order varies — placeholder order in the format string may differ between locales; method signature is positional (name, locality).
  ///
  /// In en, this message translates to:
  /// **'at {name} · {locality}'**
  String feedCardAtVenue(String name, String locality);

  /// No description provided for @feedCardAtVenueNoLocality.
  ///
  /// In en, this message translates to:
  /// **'at {name}'**
  String feedCardAtVenueNoLocality(String name);

  /// No description provided for @flavorSweetness.
  ///
  /// In en, this message translates to:
  /// **'Sweetness'**
  String get flavorSweetness;

  /// No description provided for @flavorBody.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get flavorBody;

  /// No description provided for @flavorAcidity.
  ///
  /// In en, this message translates to:
  /// **'Acidity'**
  String get flavorAcidity;

  /// No description provided for @flavorCharacter.
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get flavorCharacter;

  /// No description provided for @flavorFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get flavorFinish;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authSignUp;

  /// No description provided for @authForgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get authForgotTitle;

  /// No description provided for @authForgotBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your email. We will send a reset link valid for 1 hour.'**
  String get authForgotBody;

  /// No description provided for @authForgotSend.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get authForgotSend;

  /// No description provided for @authBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get authBackToSignIn;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOr;

  /// No description provided for @authGoogleSignInButton.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authGoogleSignInButton;

  /// No description provided for @authGoogleDisabled.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in not configured'**
  String get authGoogleDisabled;

  /// No description provided for @authGoogleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed. Try again.'**
  String get authGoogleSignInFailed;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No account yet?'**
  String get authNoAccount;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get authHaveAccount;

  /// No description provided for @authUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get authUsernameLabel;

  /// No description provided for @authUsernameHelper.
  ///
  /// In en, this message translates to:
  /// **'3–30 chars · letters, numbers, underscores · case-insensitive'**
  String get authUsernameHelper;

  /// No description provided for @authUsernameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid username'**
  String get authUsernameInvalid;

  /// No description provided for @authEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// No description provided for @authPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get authPasswordHelper;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Too short'**
  String get authPasswordTooShort;

  /// No description provided for @authTagline.
  ///
  /// In en, this message translates to:
  /// **'Discover and log Nihonshu, Shochu, and Liqueur.'**
  String get authTagline;

  /// No description provided for @verifyPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get verifyPendingTitle;

  /// No description provided for @verifyPendingBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to {email}. Open it on this device or any browser to verify your account.'**
  String verifyPendingBody(String email);

  /// No description provided for @verifyPendingResend.
  ///
  /// In en, this message translates to:
  /// **'Resend verification email'**
  String get verifyPendingResend;

  /// No description provided for @verifyPendingResendSent.
  ///
  /// In en, this message translates to:
  /// **'Sent. Check your inbox.'**
  String get verifyPendingResendSent;

  /// No description provided for @verifyPendingResendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t resend. Try again in a moment.'**
  String get verifyPendingResendFailed;

  /// No description provided for @verifyPendingBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign-in'**
  String get verifyPendingBackToSignIn;

  /// No description provided for @verifyPendingICheckedMyMail.
  ///
  /// In en, this message translates to:
  /// **'I\'ve verified'**
  String get verifyPendingICheckedMyMail;

  /// No description provided for @verifyPendingStatusUnverified.
  ///
  /// In en, this message translates to:
  /// **'Not verified yet. Open the link in your email.'**
  String get verifyPendingStatusUnverified;

  /// No description provided for @verifyPendingStatusError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check verification (will retry).'**
  String get verifyPendingStatusError;

  /// No description provided for @profileEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEdit;

  /// No description provided for @profileSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettings;

  /// No description provided for @profilePrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get profilePrivate;

  /// No description provided for @profileChangeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Change avatar'**
  String get profileChangeAvatar;

  /// No description provided for @profileDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get profileDisplayName;

  /// No description provided for @profileBioLabel.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get profileBioLabel;

  /// No description provided for @profileUsernameLocked.
  ///
  /// In en, this message translates to:
  /// **'Cannot be changed.'**
  String get profileUsernameLocked;

  /// No description provided for @profileStatCheckins.
  ///
  /// In en, this message translates to:
  /// **'Check-ins'**
  String get profileStatCheckins;

  /// No description provided for @profileStatUnique.
  ///
  /// In en, this message translates to:
  /// **'Uniques'**
  String get profileStatUnique;

  /// No description provided for @profileStatFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get profileStatFollowers;

  /// No description provided for @profileStatFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get profileStatFollowing;

  /// No description provided for @profileRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent check-ins'**
  String get profileRecent;

  /// No description provided for @profileFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get profileFollow;

  /// No description provided for @profileFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get profileFollowing;

  /// No description provided for @profileFollowRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get profileFollowRequested;

  /// No description provided for @profileUnfollow.
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get profileUnfollow;

  /// No description provided for @profileUnfollowConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Unfollow @{username}?'**
  String profileUnfollowConfirmTitle(String username);

  /// No description provided for @profileUnfollowConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You won\'t see their check-ins in your feed.'**
  String get profileUnfollowConfirmBody;

  /// No description provided for @userSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Find people'**
  String get userSearchTitle;

  /// No description provided for @userSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search by username or name'**
  String get userSearchPlaceholder;

  /// No description provided for @userSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching users'**
  String get userSearchNoResults;

  /// No description provided for @userCollectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'@{username} · Lists'**
  String userCollectionsTitle(String username);

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get settingsEmail;

  /// No description provided for @settingsEmailVerification.
  ///
  /// In en, this message translates to:
  /// **'Email verification'**
  String get settingsEmailVerification;

  /// No description provided for @settingsEmailVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get settingsEmailVerified;

  /// No description provided for @settingsEmailPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get settingsEmailPending;

  /// No description provided for @settingsPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get settingsPassword;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsPrivateAccount.
  ///
  /// In en, this message translates to:
  /// **'Private account'**
  String get settingsPrivateAccount;

  /// No description provided for @settingsPrivateBody.
  ///
  /// In en, this message translates to:
  /// **'Approve followers individually. Check-ins are visible only to approved followers.'**
  String get settingsPrivateBody;

  /// No description provided for @settingsPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsPreferences;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get settingsDangerZone;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsConfirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get settingsConfirmDelete;

  /// No description provided for @settingsConfirmDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Your account will be deleted. Your username will be held for 30 days before it can be claimed by someone else. Your check-ins and collections will no longer be visible to other users.'**
  String get settingsConfirmDeleteBody;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsSignOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get settingsSignOutConfirmTitle;

  /// No description provided for @settingsSignOutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be returned to the sign-in screen.'**
  String get settingsSignOutConfirmBody;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'KAMOS · v0.1.0'**
  String get settingsVersion;

  /// No description provided for @collectionsHeader.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get collectionsHeader;

  /// No description provided for @collectionsNewList.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get collectionsNewList;

  /// No description provided for @collectionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No collections yet'**
  String get collectionsEmptyTitle;

  /// No description provided for @collectionsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap \"New list\" to start a collection.'**
  String get collectionsEmptyBody;

  /// No description provided for @collectionsAddTo.
  ///
  /// In en, this message translates to:
  /// **'Add to collections'**
  String get collectionsAddTo;

  /// No description provided for @collectionsCreateNew.
  ///
  /// In en, this message translates to:
  /// **'Create new collection'**
  String get collectionsCreateNew;

  /// No description provided for @collectionsNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Collection name'**
  String get collectionsNamePlaceholder;

  /// No description provided for @collectionsPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get collectionsPrivate;

  /// No description provided for @collectionsBottleCountOne.
  ///
  /// In en, this message translates to:
  /// **'{count} bottle'**
  String collectionsBottleCountOne(int count);

  /// No description provided for @collectionsBottleCountOther.
  ///
  /// In en, this message translates to:
  /// **'{count} bottles'**
  String collectionsBottleCountOther(int count);

  /// No description provided for @collectionsRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get collectionsRename;

  /// No description provided for @collectionsDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete collection'**
  String get collectionsDeleteAction;

  /// No description provided for @collectionsEmptyEntries.
  ///
  /// In en, this message translates to:
  /// **'Empty collection'**
  String get collectionsEmptyEntries;

  /// No description provided for @collectionsEmptyEntriesBody.
  ///
  /// In en, this message translates to:
  /// **'Add beverages from a beverage page or check-in screen.'**
  String get collectionsEmptyEntriesBody;

  /// No description provided for @collectionsConfirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete this collection?'**
  String get collectionsConfirmDelete;

  /// No description provided for @collectionsConfirmDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the collection and all of its entries. The beverages themselves are unaffected.'**
  String get collectionsConfirmDeleteBody;

  /// No description provided for @collectionVisibilityPublicTitle.
  ///
  /// In en, this message translates to:
  /// **'Public collection'**
  String get collectionVisibilityPublicTitle;

  /// No description provided for @collectionVisibilityPublicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Anyone can see this collection on the discover tab'**
  String get collectionVisibilityPublicSubtitle;

  /// No description provided for @collectionVisibilityPrivateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only you can see this collection'**
  String get collectionVisibilityPrivateSubtitle;

  /// No description provided for @publicCollectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Public collections'**
  String get publicCollectionsTitle;

  /// No description provided for @publicCollectionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No public collections yet'**
  String get publicCollectionsEmpty;

  /// No description provided for @publicCollectionsByOwner.
  ///
  /// In en, this message translates to:
  /// **'by {username}'**
  String publicCollectionsByOwner(String username);

  /// No description provided for @commentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commentsTitle;

  /// No description provided for @commentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get commentsEmpty;

  /// No description provided for @commentsComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Add a comment…'**
  String get commentsComposerHint;

  /// No description provided for @commentsSubmit.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get commentsSubmit;

  /// No description provided for @commentsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commentsDelete;

  /// No description provided for @commentsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this comment?'**
  String get commentsDeleteConfirm;

  /// No description provided for @commentsCharCount.
  ///
  /// In en, this message translates to:
  /// **'{count} / {max}'**
  String commentsCharCount(int count, int max);

  /// No description provided for @commentsTooLong.
  ///
  /// In en, this message translates to:
  /// **'Comment too long (max 500 chars)'**
  String get commentsTooLong;

  /// No description provided for @commentsInvalidBody.
  ///
  /// In en, this message translates to:
  /// **'Comment contains invalid characters'**
  String get commentsInvalidBody;

  /// No description provided for @commentsRateLimited.
  ///
  /// In en, this message translates to:
  /// **'You\'re commenting too fast. Try again in a moment.'**
  String get commentsRateLimited;

  /// No description provided for @commentsPostFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not post. Try again.'**
  String get commentsPostFailed;

  /// No description provided for @commentsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load comments'**
  String get commentsLoadFailed;

  /// No description provided for @commentsLoadEarlier.
  ///
  /// In en, this message translates to:
  /// **'Load earlier comments'**
  String get commentsLoadEarlier;

  /// No description provided for @commentAuthorDeleted.
  ///
  /// In en, this message translates to:
  /// **'[deleted user]'**
  String get commentAuthorDeleted;

  /// No description provided for @collectionVisibilityChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change visibility. You may not own this collection.'**
  String get collectionVisibilityChangeFailed;

  /// No description provided for @feedCardCommentsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} comments'**
  String feedCardCommentsCountLabel(int count);

  /// No description provided for @inboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Follow requests'**
  String get inboxTitle;

  /// No description provided for @inboxApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get inboxApprove;

  /// No description provided for @inboxDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get inboxDecline;

  /// No description provided for @inboxEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No pending requests'**
  String get inboxEmptyTitle;

  /// No description provided for @inboxEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Follow requests appear here while your account is private.'**
  String get inboxEmptyBody;

  /// No description provided for @beverageDetailAbv.
  ///
  /// In en, this message translates to:
  /// **'ABV'**
  String get beverageDetailAbv;

  /// No description provided for @beverageDetailSeimai.
  ///
  /// In en, this message translates to:
  /// **'Seimai'**
  String get beverageDetailSeimai;

  /// No description provided for @beverageDetailRegion.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get beverageDetailRegion;

  /// No description provided for @beverageDetailType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get beverageDetailType;

  /// No description provided for @beverageDetailAddToList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get beverageDetailAddToList;

  /// No description provided for @beverageDetailAggregatedFlavor.
  ///
  /// In en, this message translates to:
  /// **'Aggregated flavor'**
  String get beverageDetailAggregatedFlavor;

  /// No description provided for @beverageDetailAbout.
  ///
  /// In en, this message translates to:
  /// **'About the brewery'**
  String get beverageDetailAbout;

  /// No description provided for @beverageDetailRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent check-ins'**
  String get beverageDetailRecent;

  /// No description provided for @beverageNoCheckinsTitle.
  ///
  /// In en, this message translates to:
  /// **'No check-ins yet'**
  String get beverageNoCheckinsTitle;

  /// No description provided for @beverageNoCheckinsBody.
  ///
  /// In en, this message translates to:
  /// **'Be the first to log this bottle.'**
  String get beverageNoCheckinsBody;

  /// No description provided for @beverageListSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to list'**
  String get beverageListSheetTitle;

  /// No description provided for @beverageListSheetEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have no lists yet.'**
  String get beverageListSheetEmpty;

  /// No description provided for @beverageListSheetSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update. Try again.'**
  String get beverageListSheetSaveFailed;

  /// No description provided for @breweryOverline.
  ///
  /// In en, this message translates to:
  /// **'Brewery'**
  String get breweryOverline;

  /// No description provided for @breweryFounded.
  ///
  /// In en, this message translates to:
  /// **'Founded'**
  String get breweryFounded;

  /// No description provided for @breweryBeverages.
  ///
  /// In en, this message translates to:
  /// **'Beverages'**
  String get breweryBeverages;

  /// No description provided for @breweryNoBeverages.
  ///
  /// In en, this message translates to:
  /// **'No beverages yet'**
  String get breweryNoBeverages;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionPost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get actionPost;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionLoadingMore.
  ///
  /// In en, this message translates to:
  /// **'Loading more'**
  String get actionLoadingMore;

  /// No description provided for @actionEndOfList.
  ///
  /// In en, this message translates to:
  /// **'End of list'**
  String get actionEndOfList;

  /// No description provided for @actionEndOfFeed.
  ///
  /// In en, this message translates to:
  /// **'End of feed'**
  String get actionEndOfFeed;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not load. Tap to retry.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Tap to retry.'**
  String get errorNetwork;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again.'**
  String get errorUnauthorized;

  /// No description provided for @loadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loadingLabel;

  /// No description provided for @settingsSuggestBeverage.
  ///
  /// In en, this message translates to:
  /// **'Suggest a beverage'**
  String get settingsSuggestBeverage;

  /// No description provided for @submitBeverageRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggest a beverage'**
  String get submitBeverageRequestTitle;

  /// No description provided for @submitBeverageRequestNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get submitBeverageRequestNameLabel;

  /// No description provided for @submitBeverageRequestBreweryLabel.
  ///
  /// In en, this message translates to:
  /// **'Brewery'**
  String get submitBeverageRequestBreweryLabel;

  /// No description provided for @submitBeverageRequestCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get submitBeverageRequestCategoryLabel;

  /// No description provided for @submitBeverageRequestNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get submitBeverageRequestNotesLabel;

  /// No description provided for @submitBeverageRequestSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submitBeverageRequestSubmitButton;

  /// No description provided for @submitBeverageRequestSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'Thanks — we\'ll review your suggestion.'**
  String get submitBeverageRequestSuccessToast;

  /// No description provided for @submitBeverageRequestErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not submit. Try again.'**
  String get submitBeverageRequestErrorGeneric;

  /// No description provided for @submitBeverageRequestNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required.'**
  String get submitBeverageRequestNameRequired;

  /// No description provided for @submitBeverageRequestBreweryRequired.
  ///
  /// In en, this message translates to:
  /// **'Brewery is required.'**
  String get submitBeverageRequestBreweryRequired;

  /// No description provided for @searchSuggestMissingCta.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find it? Suggest it.'**
  String get searchSuggestMissingCta;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
