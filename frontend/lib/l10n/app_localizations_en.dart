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
  String get tabLists => 'Lists';

  @override
  String get tabDiscover => 'Discover';

  @override
  String get tabNotifications => 'Notifications';

  @override
  String get tabMe => 'Me';

  @override
  String get feedHeader => 'Activities';

  @override
  String get feedEmptyTitle => 'No check-ins yet';

  @override
  String get feedEmptyBody =>
      'Follow some people, or head to Discover to find your first.';

  @override
  String get feedMore => 'more';

  @override
  String get searchHeader => 'Discover';

  @override
  String get searchPlaceholder => 'Search producers, beverages, prefectures.';

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
  String get ratingClear => 'Clear';

  @override
  String get checkInTitle => 'Check-in';

  @override
  String get checkInCta => 'Check-in';

  @override
  String get checkInEdit => 'Edit check-in';

  @override
  String get checkInDelete => 'Delete check-in';

  @override
  String get checkInDeleteConfirm => 'Delete this check-in?';

  @override
  String get checkInEditDiscardConfirm => 'Discard your changes?';

  @override
  String get checkInReviewLabel => 'Review';

  @override
  String get checkInReviewPlaceholder => 'Leave a note';

  @override
  String get checkInReviewTooLong => 'Review is too long';

  @override
  String get checkInFlavorTags => 'Flavor Profiles';

  @override
  String get checkInFlavorBrowse => '+ Browse';

  @override
  String get checkInFlavorSheetSearch => 'Search tags';

  @override
  String get checkInFlavorSheetEmpty => 'No matching tags.';

  @override
  String get checkInPhotosLabel => 'Photos · up to 4';

  @override
  String checkInPhotoCounter(int count) {
    return '$count / 4';
  }

  @override
  String get checkInPriceLabel => 'Price';

  @override
  String get checkInPurchaseType => 'Purchase type';

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
  String get checkInFirstToast => 'First check-in saved. Kanpai!';

  @override
  String get checkInPostFailed => 'Could not post. Tap to retry.';

  @override
  String get checkInPhotoLimitReached => 'You can attach up to 4 photos.';

  @override
  String get photoUploadDisabled =>
      'Photo upload is not available — saved without photos.';

  @override
  String get checkInWhereLabel => 'Location';

  @override
  String get checkInWhereCta => 'Add a location';

  @override
  String get venuePickerSearchPlaceholder => 'Search for a venue';

  @override
  String get venuePickerEmptyHint => 'Search for a bar, restaurant, or shop.';

  @override
  String get venuePickerNoResults => 'No venues found.';

  @override
  String get venuePickerDisabled =>
      'Venue search is not configured. You can still check-in without a venue.';

  @override
  String get venuePickerRateLimited => 'Slow down — try again in a moment.';

  @override
  String feedCardAtVenue(String name, String locality) {
    return 'at $name · $locality';
  }

  @override
  String feedCardAtVenueNoLocality(String name) {
    return 'at $name';
  }

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
  String get authGoogleSignInButton => 'Continue with Google';

  @override
  String get authGoogleDisabled => 'Google sign-in not configured';

  @override
  String get authGoogleSignInFailed => 'Google sign-in failed. Try again.';

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
  String get authTagline => 'Explore the craft, share the memories.';

  @override
  String get verifyPendingTitle => 'Check your email';

  @override
  String verifyPendingBody(String email) {
    return 'We sent a verification link to $email. Open it on this device or any browser to verify your account.';
  }

  @override
  String get verifyPendingResend => 'Resend verification email';

  @override
  String get verifyPendingResendSent => 'Sent. Check your inbox.';

  @override
  String get verifyPendingResendFailed =>
      'Couldn\'t resend. Try again in a moment.';

  @override
  String get verifyPendingBackToSignIn => 'Back to sign-in';

  @override
  String get verifyPendingICheckedMyMail => 'I\'ve verified';

  @override
  String get verifyPendingStatusUnverified =>
      'Not verified yet. Open the link in your email.';

  @override
  String get verifyPendingStatusError =>
      'Couldn\'t check verification (will retry).';

  @override
  String get profileEdit => 'Edit profile';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profilePrivate => 'Private';

  @override
  String get profileAvatarPickGallery => 'Choose from gallery';

  @override
  String get profileAvatarPickCamera => 'Take a photo';

  @override
  String get profileDisplayName => 'Display name';

  @override
  String get profileBioLabel => 'Bio';

  @override
  String get profileUsernameLocked => 'Cannot be changed.';

  @override
  String get profileStatCheckins => 'Check-ins';

  @override
  String get profileStatUnique => 'Uniques';

  @override
  String get profileStatFollowers => 'Followers';

  @override
  String get profileStatFollowing => 'Following';

  @override
  String get profileRecent => 'Recent check-ins';

  @override
  String get profileFollow => 'Follow';

  @override
  String get profileFollowing => 'Following';

  @override
  String get profileFollowRequested => 'Requested';

  @override
  String get profileUnfollow => 'Unfollow';

  @override
  String profileUnfollowConfirmTitle(String username) {
    return 'Unfollow @$username?';
  }

  @override
  String get profileUnfollowConfirmBody =>
      'You won\'t see their check-ins in your feed.';

  @override
  String get userSearchTitle => 'Find people';

  @override
  String get userSearchPlaceholder => 'Search by username or name';

  @override
  String get userSearchNoResults => 'No matching users';

  @override
  String userCollectionsTitle(String username) {
    return '@$username · Lists';
  }

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
  String get settingsConfirmDelete => 'Delete account?';

  @override
  String get settingsConfirmDeleteBody =>
      'Your account will be deleted. Your username will be held for 30 days before it can be claimed by someone else. Your check-ins and collections will no longer be visible to other users.';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsSignOutConfirmTitle => 'Sign out?';

  @override
  String get settingsSignOutConfirmBody =>
      'You\'ll be returned to the sign-in screen.';

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
  String get collectionVisibilityPublicTitle => 'Public collection';

  @override
  String get collectionVisibilityPublicSubtitle =>
      'Anyone can see this collection on your profile';

  @override
  String get collectionVisibilityPrivateSubtitle =>
      'Only you can see this collection';

  @override
  String get publicCollectionsTitle => 'Public collections';

  @override
  String get publicCollectionsEmpty => 'No public collections yet';

  @override
  String publicCollectionsByOwner(String username) {
    return 'by $username';
  }

  @override
  String get commentsTitle => 'Comments';

  @override
  String get commentsEmpty => 'No comments yet';

  @override
  String get commentsComposerHint => 'Add a comment…';

  @override
  String get commentsSubmit => 'Post';

  @override
  String get commentEdit => 'Edit';

  @override
  String get commentsDelete => 'Delete';

  @override
  String get commentsDeleteConfirm => 'Delete this comment?';

  @override
  String get editedMarker => 'edited';

  @override
  String commentsCharCount(int count, int max) {
    return '$count / $max';
  }

  @override
  String get commentsTooLong => 'Comment too long (max 500 chars)';

  @override
  String get commentsInvalidBody => 'Comment contains invalid characters';

  @override
  String get commentsRateLimited =>
      'You\'re commenting too fast. Try again in a moment.';

  @override
  String get commentsPostFailed => 'Could not post. Try again.';

  @override
  String get commentsLoadFailed => 'Could not load comments';

  @override
  String get commentsLoadEarlier => 'Load earlier comments';

  @override
  String get commentAuthorDeleted => '[deleted user]';

  @override
  String get collectionVisibilityChangeFailed =>
      'Could not change visibility. You may not own this collection.';

  @override
  String feedCardCommentsCountLabel(int count) {
    return '$count comments';
  }

  @override
  String get inboxApprove => 'Approve';

  @override
  String get inboxDecline => 'Decline';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsMarkAllRead => 'Mark all read';

  @override
  String get notificationsMarkAllError =>
      'Couldn\'t mark notifications as read. Try again.';

  @override
  String get notificationsEnd => 'You\'re all caught up.';

  @override
  String get notificationsEmptyTitle => 'Nothing new';

  @override
  String get notificationsEmptyBody =>
      'Toasts, comments, and follows from other people show up here.';

  @override
  String get notificationsDeletedActor => 'Deleted user';

  @override
  String get notificationsRequestStale => 'Request no longer pending.';

  @override
  String notificationsVerbToast(String actor) {
    return '$actor toasted your check-in.';
  }

  @override
  String notificationsVerbComment(String actor) {
    return '$actor commented on your check-in.';
  }

  @override
  String notificationsVerbFollow(String actor) {
    return '$actor started following you.';
  }

  @override
  String notificationsVerbFollowRequest(String actor) {
    return '$actor requested to follow you.';
  }

  @override
  String notificationsVerbFollowApproved(String actor) {
    return '$actor approved your follow request.';
  }

  @override
  String get beverageDetailAbv => 'ABV';

  @override
  String get beverageDetailSeimai => 'Polishing Ratio';

  @override
  String get beverageDetailRegion => 'Region';

  @override
  String get beverageDetailType => 'Type';

  @override
  String get beverageDetailAddToList => 'List';

  @override
  String get beverageDetailAggregatedFlavor => 'Flavor Profile';

  @override
  String get beverageDetailAbout => 'About the producer';

  @override
  String get beverageDetailRecent => 'Recent check-ins';

  @override
  String get beverageNoCheckinsTitle => 'No check-ins yet';

  @override
  String get beverageNoCheckinsBody => 'Be the first to log this bottle.';

  @override
  String get beverageListSheetTitle => 'Add to list';

  @override
  String get beverageListSheetEmpty => 'You have no lists yet.';

  @override
  String get beverageListSheetSaveFailed => 'Couldn\'t update. Try again.';

  @override
  String get producerOverline => 'Producer';

  @override
  String get producerFounded => 'Founded';

  @override
  String get producerBeverages => 'Beverages';

  @override
  String get producerNoBeverages => 'No beverages yet';

  @override
  String get producerImageMissing => 'No producer image';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionDiscard => 'Discard';

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

  @override
  String get settingsSuggestBeverage => 'Suggest a beverage';

  @override
  String get submitBeverageRequestTitle => 'Suggest a beverage';

  @override
  String get submitBeverageRequestNameLabel => 'Name';

  @override
  String get submitBeverageRequestProducerLabel => 'Producer';

  @override
  String get submitBeverageRequestCategoryLabel => 'Category';

  @override
  String get submitBeverageRequestNotesLabel => 'Notes';

  @override
  String get submitBeverageRequestSubmitButton => 'Submit';

  @override
  String get submitBeverageRequestSuccessToast =>
      'Thanks — we\'ll review your suggestion.';

  @override
  String get submitBeverageRequestErrorGeneric =>
      'Could not submit. Try again.';

  @override
  String get submitBeverageRequestNameRequired => 'Name is required.';

  @override
  String get submitBeverageRequestProducerRequired => 'Producer is required.';

  @override
  String get searchSuggestMissingCta => 'Can\'t find it? Suggest it.';

  @override
  String get profileRecentEmptyMeTitle => 'No check-ins yet';

  @override
  String get profileRecentEmptyMeBody =>
      'Log your first bottle to see it here.';

  @override
  String get profileRecentEmptyOtherTitle => 'No check-ins yet';

  @override
  String get profileRecentEmptyOtherBody =>
      'When they log a bottle, it will show up here.';

  @override
  String get userBeveragesTitle => 'Beverages';

  @override
  String get userBeveragesEmpty => 'No check-ins yet — try one!';

  @override
  String get userBeveragesYourAvg => 'Your avg';

  @override
  String get userBeveragesGlobalAvg => 'Global avg';

  @override
  String userBeveragesCheckinCount(int count) {
    return '$count check-ins';
  }

  @override
  String get userBeveragesSort => 'Sort';

  @override
  String get userBeveragesSortRating => 'Rating';

  @override
  String get userBeveragesSortLastCheckin => 'Last check-in';

  @override
  String get userBeveragesSortProducer => 'Producer';

  @override
  String get userBeveragesSortCategory => 'Category';

  @override
  String get userBeveragesMinRating => 'Min rating';

  @override
  String get userBeveragesAllCategories => 'All';

  @override
  String get socialFollowersTitle => 'Followers';

  @override
  String get socialFollowingTitle => 'Following';

  @override
  String get socialSearchHint => 'Search by username or name';

  @override
  String get socialEmptyFollowers => 'No followers yet';

  @override
  String get socialEmptyFollowing => 'Not following anyone yet';

  @override
  String get socialSearchNoMatch => 'No matches';
}
