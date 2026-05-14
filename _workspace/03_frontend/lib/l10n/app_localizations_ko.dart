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
  String get tabSearch => '검색';

  @override
  String get tabCheckIn => '체크인';

  @override
  String get tabLists => '리스트';

  @override
  String get tabMe => '마이';

  @override
  String get feedHeader => '팔로잉';

  @override
  String get feedSubheader => '팔로우 중인 사람들의 활동';

  @override
  String get feedEmptyTitle => '아직 체크인이 없습니다';

  @override
  String get feedEmptyBody => '누군가를 팔로우하거나 ＋ 버튼으로 첫 기록을 남겨보세요.';

  @override
  String get feedMore => '더 보기';

  @override
  String get searchHeader => '둘러보기';

  @override
  String get searchPlaceholder => '양조장 · 술 · 지역으로 검색';

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
  String get checkInTitle => '체크인';

  @override
  String get checkInCta => '체크인';

  @override
  String get checkInReviewLabel => '리뷰 · 선택';

  @override
  String get checkInReviewPlaceholder => '배, 부드러운 쌀, 깔끔한 피니시…';

  @override
  String get checkInReviewTooLong => '리뷰가 너무 깁니다';

  @override
  String get checkInFlavorTags => '풍미 태그';

  @override
  String get checkInPhotosLabel => '사진 · 최대 4장';

  @override
  String checkInPhotoCounter(int count) {
    return '$count / 4';
  }

  @override
  String get checkInPriceLabel => '가격 · 선택';

  @override
  String get checkInPurchaseType => '구매 유형';

  @override
  String get checkInServingStyle => '서빙 스타일';

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
  String get checkInServingGlass => '잔';

  @override
  String get checkInServingCarafe => '카라페';

  @override
  String get checkInServingBottle => '병';

  @override
  String get checkInServingCan => '캔';

  @override
  String get checkInServingOther => '기타';

  @override
  String get checkInFirstToast => '첫 체크인을 기록했습니다. 건배!';

  @override
  String get checkInPostFailed => '게시할 수 없습니다. 탭하여 다시 시도하세요.';

  @override
  String get checkInPhotoLimitReached => '사진은 최대 4장까지 첨부할 수 있습니다.';

  @override
  String get flavorSweetness => '단맛';

  @override
  String get flavorBody => '바디';

  @override
  String get flavorAcidity => '산미';

  @override
  String get flavorCharacter => '캐릭터';

  @override
  String get flavorFinish => '피니시';

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
  String get authContinueGoogle => 'Google로 계속하기';

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
  String get authTagline => '니혼슈, 쇼츄, 리큐어를 기록하는 앱.';

  @override
  String get authVerifyTitle => '이메일을 확인하세요';

  @override
  String get authVerifySent => '확인 링크를 보내드렸습니다:';

  @override
  String get authVerifyExpiry => '링크는 24시간 동안 유효합니다. 미확인 상태에서도 앱을 사용할 수 있습니다.';

  @override
  String get authVerifyContinue => 'KAMOS 시작하기';

  @override
  String get authVerifyResend => '이메일 다시 보내기';

  @override
  String get verifyEmailTitle => '이메일 인증 중';

  @override
  String get verifyEmailLoading => '인증 링크를 확인하고 있습니다…';

  @override
  String get verifyEmailSuccess => '이메일이 인증되었습니다.';

  @override
  String get verifyEmailFailure => '링크를 인증할 수 없습니다. 만료되었을 수 있습니다.';

  @override
  String get verifyEmailBackToAuth => '로그인으로 돌아가기';

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
  String get profileStatUnique => '유니크';

  @override
  String get profileStatFollowers => '팔로워';

  @override
  String get profileStatFollowing => '팔로잉';

  @override
  String get profileRecent => '최근 체크인';

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
  String get settingsDeleteAccountHelper => '소프트 삭제 · 사용자 이름은 30일간 보류 후 해제됩니다.';

  @override
  String get settingsConfirmDelete => '계정을 삭제하시겠습니까?';

  @override
  String get settingsConfirmDeleteBody =>
      '계정은 소프트 삭제됩니다. 사용자 이름은 30일간 보류 후 다른 사용자가 사용할 수 있습니다. 체크인과 컬렉션은 비공개 처리됩니다.';

  @override
  String get settingsVersion => 'KAMOS · v0.1.0';

  @override
  String get collectionsHeader => '컬렉션';

  @override
  String get collectionsNewList => '새 리스트';

  @override
  String get collectionsEmptyTitle => '아직 컬렉션이 없습니다';

  @override
  String get collectionsEmptyBody => '\"새 리스트\"를 탭하여 컬렉션을 만들어보세요.';

  @override
  String get collectionsAddTo => '컬렉션에 추가';

  @override
  String get collectionsCreateNew => '새 컬렉션 만들기';

  @override
  String get collectionsNamePlaceholder => '컬렉션 이름';

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
  String get collectionsDeleteAction => '컬렉션 삭제';

  @override
  String get collectionsEmptyEntries => '빈 컬렉션';

  @override
  String get collectionsEmptyEntriesBody => '제품 페이지나 체크인 화면에서 추가하세요.';

  @override
  String get collectionsConfirmDelete => '이 컬렉션을 삭제할까요?';

  @override
  String get collectionsConfirmDeleteBody =>
      '컬렉션과 모든 항목이 삭제됩니다. 제품 자체는 영향받지 않습니다.';

  @override
  String get inboxTitle => '팔로우 요청';

  @override
  String get inboxApprove => '수락';

  @override
  String get inboxDecline => '거절';

  @override
  String get inboxEmptyTitle => '대기 중인 요청이 없습니다';

  @override
  String get inboxEmptyBody => '비공개 계정일 때 팔로우 요청이 여기에 표시됩니다.';

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
  String get beverageDetailAbout => '양조장 소개';

  @override
  String get beverageDetailRecent => '최근 체크인';

  @override
  String get beverageNoCheckinsTitle => '아직 체크인이 없습니다';

  @override
  String get beverageNoCheckinsBody => '첫 기록을 남겨보세요.';

  @override
  String get breweryOverline => '양조장';

  @override
  String get breweryFounded => '창업';

  @override
  String get breweryBeverages => '제품';

  @override
  String get breweryNoBeverages => '아직 등록된 제품이 없습니다';

  @override
  String get actionSave => '저장';

  @override
  String get actionCancel => '취소';

  @override
  String get actionDelete => '삭제';

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
}
