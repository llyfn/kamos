// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appName => 'KAMOS';

  @override
  String get categoryNihonshu => '니혼슈 (사케)';

  @override
  String get categoryShochu => '쇼츄';

  @override
  String get categoryLiqueur => '리큐어';

  @override
  String get tabFeed => '피드';

  @override
  String get tabLists => '리스트';

  @override
  String get tabDiscover => '둘러보기';

  @override
  String get tabNotifications => '알림';

  @override
  String get tabMe => '나';

  @override
  String get feedHeader => '활동';

  @override
  String get feedEmptyTitle => '아직 체크인이 없습니다';

  @override
  String get feedEmptyBody => '누군가를 팔로우하거나 둘러보기에서 첫 한 잔을 찾아보세요.';

  @override
  String get feedMore => '더 보기';

  @override
  String get searchHeader => '둘러보기';

  @override
  String get searchPlaceholder => '생산자 · 술 · 지역으로 검색';

  @override
  String get searchNoResultsTitle => '결과 없음';

  @override
  String get searchNoResultsBody => '결과가 없습니다. 다른 검색어를 시도해보세요.';

  @override
  String get searchCategoryAll => '전체';

  @override
  String searchResultCountOne(int count) {
    return '$count건';
  }

  @override
  String searchResultCountOther(int count) {
    return '$count건';
  }

  @override
  String ratingValue(String value) {
    return '$value / 5.0';
  }

  @override
  String get ratingTapToRate => '별을 탭하여 평가 · 0.5 단위';

  @override
  String get ratingLabel => '평점';

  @override
  String get ratingClear => '지우기';

  @override
  String get checkInTitle => '체크인';

  @override
  String get checkInCta => '체크인';

  @override
  String get checkInEdit => '체크인 수정';

  @override
  String get checkInDelete => '체크인 삭제';

  @override
  String get checkInDeleteConfirm => '이 체크인을 삭제할까요?';

  @override
  String get checkInEditDiscardConfirm => '변경 사항을 취소할까요?';

  @override
  String get checkInReviewLabel => '리뷰';

  @override
  String get checkInReviewPlaceholder => '메모 남기기';

  @override
  String get checkInReviewTooLong => '리뷰가 너무 깁니다';

  @override
  String get checkInFlavorTags => '풍미 태그';

  @override
  String get checkInFlavorBrowse => '+ 둘러보기';

  @override
  String get checkInFlavorSheetSearch => '태그 검색';

  @override
  String get checkInFlavorSheetEmpty => '일치하는 태그가 없습니다.';

  @override
  String get checkInPhotosLabel => '사진 · 최대 4장';

  @override
  String checkInPhotoCounter(int count) {
    return '$count / 4';
  }

  @override
  String get checkInPriceLabel => '가격';

  @override
  String get checkInPurchaseType => '구매 유형';

  @override
  String get checkInPriceServing => '잔당';

  @override
  String get checkInPriceBottle => '병당';

  @override
  String get checkInPurchaseOnPremise => '매장';

  @override
  String get checkInPurchaseRetail => '소매';

  @override
  String get checkInPurchaseGift => '선물';

  @override
  String get checkInPurchaseOther => '기타';

  @override
  String get checkInFirstToast => '첫 체크인을 기록했습니다. 건배!';

  @override
  String get checkInPostFailed => '게시할 수 없습니다. 탭하여 다시 시도하세요.';

  @override
  String get checkInPhotoLimitReached => '사진은 최대 4장까지 첨부할 수 있습니다.';

  @override
  String get photoUploadDisabled => '사진 업로드를 사용할 수 없습니다 — 사진 없이 저장했습니다.';

  @override
  String get checkInWhereLabel => '위치';

  @override
  String get checkInWhereCta => '장소 추가';

  @override
  String get venuePickerSearchPlaceholder => '장소 검색';

  @override
  String get venuePickerEmptyHint => '바, 레스토랑, 주류 판매점 검색.';

  @override
  String get venuePickerNoResults => '결과 없음.';

  @override
  String get venuePickerDisabled => '장소 검색이 설정되지 않았습니다. 장소 없이 체크인할 수 있습니다.';

  @override
  String get venuePickerRateLimited => '잠시 후 다시 시도하세요.';

  @override
  String feedCardAtVenue(String name, String locality) {
    return '$locality · $name에서';
  }

  @override
  String feedCardAtVenueNoLocality(String name) {
    return '$name에서';
  }

  @override
  String get flavorSweetness => '단맛';

  @override
  String get flavorBody => '바디감';

  @override
  String get flavorAcidity => '산미';

  @override
  String get flavorCharacter => '개성';

  @override
  String get flavorFinish => '여운';

  @override
  String get authSignIn => '로그인';

  @override
  String get authSignUp => '계정 만들기';

  @override
  String get authForgotTitle => '비밀번호 재설정';

  @override
  String get authForgotBody => '이메일을 입력하세요. 1시간 동안 유효한 재설정 링크를 보내드립니다.';

  @override
  String get authForgotSend => '링크 보내기';

  @override
  String get authBackToSignIn => '로그인으로 돌아가기';

  @override
  String get authForgotPassword => '비밀번호를 잊으셨나요?';

  @override
  String get authOr => '또는';

  @override
  String get authGoogleSignInButton => 'Google로 계속하기';

  @override
  String get authGoogleDisabled => 'Google 로그인이 설정되지 않았습니다';

  @override
  String get authGoogleSignInFailed => 'Google 로그인에 실패했습니다. 다시 시도해 주세요.';

  @override
  String get authNoAccount => '계정이 없으신가요?';

  @override
  String get authHaveAccount => '이미 계정이 있으신가요?';

  @override
  String get authUsernameLabel => '사용자 이름';

  @override
  String get authUsernameHelper => '3–30자 · 영문/숫자/언더스코어 · 대소문자 구분 없음';

  @override
  String get authUsernameInvalid => '잘못된 사용자 이름';

  @override
  String get authEmailLabel => '이메일';

  @override
  String get authPasswordLabel => '비밀번호';

  @override
  String get authPasswordHelper => '8자 이상';

  @override
  String get authPasswordTooShort => '너무 짧습니다';

  @override
  String get authTagline => '한 모금의 발견.';

  @override
  String get verifyPendingTitle => '이메일을 확인하세요';

  @override
  String verifyPendingBody(String email) {
    return '$email (으)로 인증 링크를 보냈습니다. 이 기기 또는 브라우저에서 링크를 열어 계정을 인증하세요.';
  }

  @override
  String get verifyPendingResend => '인증 메일 재전송';

  @override
  String get verifyPendingResendSent => '전송되었습니다. 받은편지함을 확인하세요.';

  @override
  String get verifyPendingResendFailed => '재전송에 실패했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get verifyPendingBackToSignIn => '로그인으로 돌아가기';

  @override
  String get verifyPendingICheckedMyMail => '인증 완료';

  @override
  String get verifyPendingStatusUnverified => '아직 인증되지 않았습니다. 메일의 링크를 열어주세요.';

  @override
  String get verifyPendingStatusError => '인증 상태를 확인할 수 없습니다 (재시도합니다).';

  @override
  String get profileEdit => '프로필 편집';

  @override
  String get profileSettings => '설정';

  @override
  String get profilePrivate => '비공개';

  @override
  String get profileChangeAvatar => '아바타 변경';

  @override
  String get profileDisplayName => '표시 이름';

  @override
  String get profileBioLabel => '소개';

  @override
  String get profileUsernameLocked => '변경할 수 없습니다.';

  @override
  String get profileStatCheckins => '체크인';

  @override
  String get profileStatUnique => '종류';

  @override
  String get profileStatFollowers => '팔로워';

  @override
  String get profileStatFollowing => '팔로잉';

  @override
  String get profileRecent => '최근 체크인';

  @override
  String get profileFollow => '팔로우';

  @override
  String get profileFollowing => '팔로잉';

  @override
  String get profileFollowRequested => '요청됨';

  @override
  String get profileUnfollow => '언팔로우';

  @override
  String profileUnfollowConfirmTitle(String username) {
    return '@$username 님을 언팔로우할까요?';
  }

  @override
  String get profileUnfollowConfirmBody => '이 사용자의 체크인이 피드에 표시되지 않습니다.';

  @override
  String get userSearchTitle => '사용자 찾기';

  @override
  String get userSearchPlaceholder => '사용자 이름 또는 이름으로 검색';

  @override
  String get userSearchNoResults => '일치하는 사용자가 없습니다';

  @override
  String userCollectionsTitle(String username) {
    return '@$username · 리스트';
  }

  @override
  String get settingsAccount => '계정';

  @override
  String get settingsEmail => '이메일';

  @override
  String get settingsEmailVerification => '이메일 인증';

  @override
  String get settingsEmailVerified => '확인됨';

  @override
  String get settingsEmailPending => '미확인';

  @override
  String get settingsPassword => '비밀번호';

  @override
  String get settingsPrivacy => '개인 정보';

  @override
  String get settingsPrivateAccount => '비공개 계정';

  @override
  String get settingsPrivateBody => '팔로워를 개별 승인. 체크인은 승인된 팔로워에게만 표시.';

  @override
  String get settingsPreferences => '환경 설정';

  @override
  String get settingsLanguage => '언어';

  @override
  String get settingsDangerZone => '계정 삭제';

  @override
  String get settingsDeleteAccount => '계정 삭제';

  @override
  String get settingsConfirmDelete => '계정을 삭제하시겠습니까?';

  @override
  String get settingsConfirmDeleteBody =>
      '계정이 삭제됩니다. 사용자 이름은 30일간 보류된 후 다른 사용자가 사용할 수 있습니다. 체크인과 리스트는 다른 사용자에게 더 이상 표시되지 않습니다.';

  @override
  String get settingsSignOut => '로그아웃';

  @override
  String get settingsSignOutConfirmTitle => '로그아웃하시겠습니까?';

  @override
  String get settingsSignOutConfirmBody => '로그인 화면으로 돌아갑니다.';

  @override
  String get settingsVersion => 'KAMOS · v0.1.0';

  @override
  String get collectionsHeader => '리스트';

  @override
  String get collectionsNewList => '새 리스트';

  @override
  String get collectionsEmptyTitle => '아직 리스트가 없습니다';

  @override
  String get collectionsEmptyBody => '\"새 리스트\"를 탭하여 리스트를 만들어보세요.';

  @override
  String get collectionsAddTo => '리스트에 추가';

  @override
  String get collectionsCreateNew => '새 리스트 만들기';

  @override
  String get collectionsNamePlaceholder => '리스트 이름';

  @override
  String get collectionsPrivate => '비공개';

  @override
  String collectionsBottleCountOne(int count) {
    return '$count병';
  }

  @override
  String collectionsBottleCountOther(int count) {
    return '$count병';
  }

  @override
  String get collectionsRename => '이름 변경';

  @override
  String get collectionsDeleteAction => '리스트 삭제';

  @override
  String get collectionsEmptyEntries => '빈 리스트';

  @override
  String get collectionsEmptyEntriesBody => '제품 페이지나 체크인 화면에서 추가하세요.';

  @override
  String get collectionsConfirmDelete => '이 리스트를 삭제할까요?';

  @override
  String get collectionsConfirmDeleteBody =>
      '리스트와 모든 항목이 삭제됩니다. 제품 자체는 영향받지 않습니다.';

  @override
  String get collectionVisibilityPublicTitle => '공개 리스트';

  @override
  String get collectionVisibilityPublicSubtitle => '이 리스트는 프로필에서 누구나 볼 수 있습니다';

  @override
  String get collectionVisibilityPrivateSubtitle => '이 리스트는 본인만 볼 수 있습니다';

  @override
  String get publicCollectionsTitle => '공개 리스트';

  @override
  String get publicCollectionsEmpty => '아직 공개된 리스트가 없습니다';

  @override
  String publicCollectionsByOwner(String username) {
    return '작성: $username';
  }

  @override
  String get commentsTitle => '댓글';

  @override
  String get commentsEmpty => '아직 댓글이 없습니다';

  @override
  String get commentsComposerHint => '댓글 추가…';

  @override
  String get commentsSubmit => '게시';

  @override
  String get commentEdit => '수정';

  @override
  String get commentsDelete => '삭제';

  @override
  String get commentsDeleteConfirm => '이 댓글을 삭제하시겠어요?';

  @override
  String get editedMarker => '수정됨';

  @override
  String commentsCharCount(int count, int max) {
    return '$count / $max';
  }

  @override
  String get commentsTooLong => '댓글이 너무 깁니다 (최대 500자)';

  @override
  String get commentsInvalidBody => '댓글에 사용할 수 없는 문자가 포함되어 있습니다';

  @override
  String get commentsRateLimited => '댓글 작성이 너무 잦습니다. 잠시 후 다시 시도하세요.';

  @override
  String get commentsPostFailed => '게시하지 못했습니다. 다시 시도하세요.';

  @override
  String get commentsLoadFailed => '댓글을 불러오지 못했습니다';

  @override
  String get commentsLoadEarlier => '이전 댓글 불러오기';

  @override
  String get commentAuthorDeleted => '[삭제된 사용자]';

  @override
  String get collectionVisibilityChangeFailed =>
      '공개 설정을 변경할 수 없습니다. 이 리스트의 소유자가 아닐 수 있습니다.';

  @override
  String feedCardCommentsCountLabel(int count) {
    return '댓글 $count개';
  }

  @override
  String get inboxApprove => '수락';

  @override
  String get inboxDecline => '거절';

  @override
  String get notificationsTitle => '알림';

  @override
  String get notificationsMarkAllRead => '모두 읽음';

  @override
  String get notificationsMarkAllError => '알림을 읽음으로 표시하지 못했습니다. 다시 시도해주세요.';

  @override
  String get notificationsEnd => '모두 확인했습니다.';

  @override
  String get notificationsEmptyTitle => '새 알림이 없습니다';

  @override
  String get notificationsEmptyBody => '다른 사용자의 건배, 댓글, 팔로우가 여기에 표시됩니다.';

  @override
  String get notificationsDeletedActor => '삭제된 사용자';

  @override
  String get notificationsRequestStale => '이미 처리된 요청입니다.';

  @override
  String notificationsVerbToast(String actor) {
    return '$actor님이 회원님의 체크인에 건배했습니다.';
  }

  @override
  String notificationsVerbComment(String actor) {
    return '$actor님이 회원님의 체크인에 댓글을 남겼습니다.';
  }

  @override
  String notificationsVerbFollow(String actor) {
    return '$actor님이 회원님을 팔로우하기 시작했습니다.';
  }

  @override
  String notificationsVerbFollowRequest(String actor) {
    return '$actor님이 팔로우 요청을 보냈습니다.';
  }

  @override
  String notificationsVerbFollowApproved(String actor) {
    return '$actor님이 회원님의 팔로우 요청을 수락했습니다.';
  }

  @override
  String get beverageDetailAbv => '도수';

  @override
  String get beverageDetailSeimai => '정미율';

  @override
  String get beverageDetailRegion => '지역';

  @override
  String get beverageDetailType => '종류';

  @override
  String get beverageDetailAddToList => '리스트';

  @override
  String get beverageDetailAggregatedFlavor => '풍미 프로필';

  @override
  String get beverageDetailAbout => '생산자 소개';

  @override
  String get beverageDetailRecent => '최근 체크인';

  @override
  String get beverageNoCheckinsTitle => '아직 체크인이 없습니다';

  @override
  String get beverageNoCheckinsBody => '첫 기록을 남겨보세요.';

  @override
  String get beverageListSheetTitle => '리스트에 추가';

  @override
  String get beverageListSheetEmpty => '아직 리스트가 없습니다.';

  @override
  String get beverageListSheetSaveFailed => '업데이트에 실패했습니다. 다시 시도하세요.';

  @override
  String get producerOverline => '생산자';

  @override
  String get producerFounded => '창업';

  @override
  String get producerBeverages => '제품';

  @override
  String get producerNoBeverages => '아직 등록된 제품이 없습니다';

  @override
  String get producerImageMissing => '양조장 이미지 없음';

  @override
  String get actionSave => '저장';

  @override
  String get actionCancel => '취소';

  @override
  String get actionDelete => '삭제';

  @override
  String get actionDiscard => '취소하기';

  @override
  String get actionPost => '게시';

  @override
  String get actionRetry => '다시 시도';

  @override
  String get actionLoadingMore => '불러오는 중';

  @override
  String get actionEndOfList => '목록의 끝';

  @override
  String get actionEndOfFeed => '피드의 끝';

  @override
  String get errorGeneric => '불러올 수 없습니다. 탭하여 다시 시도하세요.';

  @override
  String get errorNetwork => '연결할 수 없습니다. 탭하여 다시 시도하세요.';

  @override
  String get errorUnauthorized => '다시 로그인하세요.';

  @override
  String get loadingLabel => '불러오는 중';

  @override
  String get settingsSuggestBeverage => '음료 제안하기';

  @override
  String get submitBeverageRequestTitle => '음료 제안';

  @override
  String get submitBeverageRequestNameLabel => '이름';

  @override
  String get submitBeverageRequestProducerLabel => '생산자';

  @override
  String get submitBeverageRequestCategoryLabel => '카테고리';

  @override
  String get submitBeverageRequestNotesLabel => '메모';

  @override
  String get submitBeverageRequestSubmitButton => '제출';

  @override
  String get submitBeverageRequestSuccessToast => '감사합니다 — 검토하겠습니다.';

  @override
  String get submitBeverageRequestErrorGeneric => '제출하지 못했습니다. 다시 시도하세요.';

  @override
  String get submitBeverageRequestNameRequired => '이름은 필수입니다.';

  @override
  String get submitBeverageRequestProducerRequired => '생산자는 필수입니다.';

  @override
  String get searchSuggestMissingCta => '찾으시는 음료가 없나요? 제안해 주세요.';

  @override
  String get profileRecentEmptyMeTitle => '아직 체크인이 없습니다';

  @override
  String get profileRecentEmptyMeBody => '첫 기록을 남기면 여기에 표시됩니다.';

  @override
  String get profileRecentEmptyOtherTitle => '아직 체크인이 없습니다';

  @override
  String get profileRecentEmptyOtherBody => '이 사용자가 기록하면 여기에 표시됩니다.';
}
