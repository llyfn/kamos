// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'KAMOS';

  @override
  String get categoryNihonshu => '日本酒';

  @override
  String get categoryShochu => '焼酎';

  @override
  String get categoryLiqueur => 'リキュール';

  @override
  String get tabFeed => 'フィード';

  @override
  String get tabSearch => '探す';

  @override
  String get tabCheckIn => 'チェックイン';

  @override
  String get tabLists => 'リスト';

  @override
  String get tabMe => 'マイページ';

  @override
  String get feedHeader => 'フォロー中';

  @override
  String get feedSubheader => 'フォロー中の人から';

  @override
  String get feedEmptyTitle => 'まだチェックインがありません';

  @override
  String get feedEmptyBody => '誰かをフォローするか、＋から最初の一杯を記録しましょう。';

  @override
  String get feedMore => 'もっと見る';

  @override
  String get searchHeader => '探す';

  @override
  String get searchPlaceholder => '蔵元・銘柄・都道府県で検索';

  @override
  String get searchNoResultsTitle => '該当なし';

  @override
  String get searchNoResultsBody => '該当なし。別の言葉で試してください。';

  @override
  String get searchCategoryAll => 'すべて';

  @override
  String searchResultCountOne(int count) {
    return '$count件';
  }

  @override
  String searchResultCountOther(int count) {
    return '$count件';
  }

  @override
  String ratingValue(String value) {
    return '$value / 5.0';
  }

  @override
  String get ratingTapToRate => 'スターをタップ · 0.5刻みで評価';

  @override
  String get ratingLabel => '評価';

  @override
  String get checkInTitle => 'チェックイン';

  @override
  String get checkInCta => 'チェックイン';

  @override
  String get checkInReviewLabel => 'レビュー · 任意';

  @override
  String get checkInReviewPlaceholder => '梨、柔らかな米、クリアな余韻…';

  @override
  String get checkInReviewTooLong => 'レビューが長すぎます';

  @override
  String get checkInFlavorTags => 'フレーバータグ';

  @override
  String get checkInPhotosLabel => '写真 · 4枚まで';

  @override
  String checkInPhotoCounter(int count) {
    return '$count / 4';
  }

  @override
  String get checkInPriceLabel => '価格 · 任意';

  @override
  String get checkInPurchaseType => '購入種別';

  @override
  String get checkInServingStyle => '提供スタイル';

  @override
  String get checkInPriceServing => '一杯';

  @override
  String get checkInPriceBottle => '一本';

  @override
  String get checkInPurchaseOnPremise => '店舗';

  @override
  String get checkInPurchaseRetail => '小売';

  @override
  String get checkInPurchaseGift => '贈物';

  @override
  String get checkInPurchaseOther => 'その他';

  @override
  String get checkInServingGlass => 'グラス';

  @override
  String get checkInServingCarafe => '徳利';

  @override
  String get checkInServingBottle => '瓶';

  @override
  String get checkInServingCan => '缶';

  @override
  String get checkInServingOther => 'その他';

  @override
  String get checkInFirstToast => '最初のチェックイン。乾杯！';

  @override
  String get checkInPostFailed => '投稿できませんでした。タップしてやり直し。';

  @override
  String get checkInPhotoLimitReached => '写真は4枚までです。';

  @override
  String get photoUploadDisabled => '写真のアップロードは利用できません — 写真なしで保存しました。';

  @override
  String get photoUploadFailed => '写真をアップロードできませんでした。タップしてやり直し。';

  @override
  String get checkInWhereLabel => 'どこで？';

  @override
  String get checkInWhereCta => '場所を追加';

  @override
  String get venuePickerSearchPlaceholder => '場所を検索';

  @override
  String get venuePickerEmptyHint => 'バー、レストラン、酒販店を検索。';

  @override
  String get venuePickerNoResults => '該当なし。';

  @override
  String get venuePickerDisabled => '場所検索は未設定。場所なしでチェックインできます。';

  @override
  String get venuePickerRateLimited => '少しお待ちください。';

  @override
  String feedCardAtVenue(String name, String locality) {
    return '$name · $localityにて';
  }

  @override
  String feedCardAtVenueNoLocality(String name) {
    return '$nameにて';
  }

  @override
  String get flavorSweetness => '甘味';

  @override
  String get flavorBody => 'ボディ';

  @override
  String get flavorAcidity => '酸味';

  @override
  String get flavorCharacter => '個性';

  @override
  String get flavorFinish => '余韻';

  @override
  String get authSignIn => 'サインイン';

  @override
  String get authSignUp => 'アカウント作成';

  @override
  String get authForgotTitle => 'パスワードを再設定';

  @override
  String get authForgotBody => 'メールアドレスを入力してください。1時間有効な再設定リンクを送信します。';

  @override
  String get authForgotSend => 'リンクを送る';

  @override
  String get authBackToSignIn => 'サインインに戻る';

  @override
  String get authForgotPassword => 'パスワードを忘れた';

  @override
  String get authOr => 'または';

  @override
  String get authContinueGoogle => 'Googleで続行';

  @override
  String get authGoogleSignInButton => 'Googleで続行';

  @override
  String get authGoogleDisabled => 'Googleサインインは未設定';

  @override
  String get authGoogleSignInFailed => 'Googleサインインに失敗しました。もう一度お試しください。';

  @override
  String get authNoAccount => 'アカウントがない？';

  @override
  String get authHaveAccount => 'すでにアカウントをお持ち？';

  @override
  String get authUsernameLabel => 'ユーザー名';

  @override
  String get authUsernameHelper => '3–30文字 · 英数字とアンダースコア · 大文字小文字を区別しない';

  @override
  String get authUsernameInvalid => 'ユーザー名が無効';

  @override
  String get authEmailLabel => 'メール';

  @override
  String get authPasswordLabel => 'パスワード';

  @override
  String get authPasswordHelper => '8文字以上';

  @override
  String get authPasswordTooShort => '短すぎます';

  @override
  String get authTagline => '日本酒、焼酎、リキュールを記録するアプリ。';

  @override
  String get authVerifyTitle => 'メールを確認';

  @override
  String get authVerifySent => '確認リンクをお送りしました：';

  @override
  String get authVerifyExpiry => 'リンクは24時間有効です。未確認でもアプリは利用できます。';

  @override
  String get authVerifyContinue => 'KAMOSを始める';

  @override
  String get authVerifyResend => 'メールを再送';

  @override
  String get verifyEmailTitle => 'メールを認証中';

  @override
  String get verifyEmailLoading => '認証リンクを確認しています…';

  @override
  String get verifyEmailSuccess => 'メールが認証されました。';

  @override
  String get verifyEmailFailure => 'リンクを認証できませんでした。期限切れの可能性があります。';

  @override
  String get verifyEmailBackToAuth => 'サインインに戻る';

  @override
  String get profileEdit => 'プロフィール編集';

  @override
  String get profileSettings => '設定';

  @override
  String get profilePrivate => '非公開';

  @override
  String get profileChangeAvatar => 'アバターを変更';

  @override
  String get profileDisplayName => '表示名';

  @override
  String get profileBioLabel => '自己紹介';

  @override
  String get profileUsernameLocked => '変更できません。';

  @override
  String get profileStatCheckins => 'チェックイン';

  @override
  String get profileStatUnique => 'ユニーク';

  @override
  String get profileStatFollowers => 'フォロワー';

  @override
  String get profileStatFollowing => 'フォロー中';

  @override
  String get profileRecent => '最近のチェックイン';

  @override
  String get settingsAccount => 'アカウント';

  @override
  String get settingsEmail => 'メール';

  @override
  String get settingsEmailVerification => 'メール確認';

  @override
  String get settingsEmailVerified => '確認済み';

  @override
  String get settingsEmailPending => '未確認';

  @override
  String get settingsPassword => 'パスワード';

  @override
  String get settingsPrivacy => 'プライバシー';

  @override
  String get settingsPrivateAccount => '非公開アカウント';

  @override
  String get settingsPrivateBody => 'フォロワーを個別に承認。チェックインは承認済みフォロワーのみに表示。';

  @override
  String get settingsPreferences => '環境設定';

  @override
  String get settingsLanguage => '言語';

  @override
  String get settingsDangerZone => '危険な操作';

  @override
  String get settingsDeleteAccount => 'アカウントを削除';

  @override
  String get settingsDeleteAccountHelper => '論理削除 · ユーザー名は30日間保留されます。';

  @override
  String get settingsConfirmDelete => 'アカウントを削除しますか？';

  @override
  String get settingsConfirmDeleteBody =>
      'アカウントは論理削除されます。ユーザー名は30日間保留され、その後再利用可能になります。チェックインとコレクションは非表示となります。';

  @override
  String get settingsVersion => 'KAMOS · v0.1.0';

  @override
  String get collectionsHeader => 'コレクション';

  @override
  String get collectionsNewList => '新しいリスト';

  @override
  String get collectionsEmptyTitle => 'まだコレクションがありません';

  @override
  String get collectionsEmptyBody => '「新しいリスト」からコレクションを作成。';

  @override
  String get collectionsAddTo => 'コレクションに追加';

  @override
  String get collectionsCreateNew => '新しいコレクション';

  @override
  String get collectionsNamePlaceholder => 'コレクション名';

  @override
  String get collectionsPrivate => '非公開';

  @override
  String collectionsBottleCountOne(int count) {
    return '$count本';
  }

  @override
  String collectionsBottleCountOther(int count) {
    return '$count本';
  }

  @override
  String get collectionsRename => '名前を変更';

  @override
  String get collectionsDeleteAction => 'コレクションを削除';

  @override
  String get collectionsEmptyEntries => '空のコレクション';

  @override
  String get collectionsEmptyEntriesBody => '銘柄詳細やチェックイン画面から追加できます。';

  @override
  String get collectionsConfirmDelete => 'このコレクションを削除？';

  @override
  String get collectionsConfirmDeleteBody =>
      'コレクションとそのすべてのエントリが削除されます。銘柄自体には影響しません。';

  @override
  String get inboxTitle => 'フォローリクエスト';

  @override
  String get inboxApprove => '承認';

  @override
  String get inboxDecline => '辞退';

  @override
  String get inboxEmptyTitle => '保留中のリクエストはありません';

  @override
  String get inboxEmptyBody => 'アカウントが非公開の間、リクエストはここに表示されます。';

  @override
  String get beverageDetailAbv => '度数';

  @override
  String get beverageDetailSeimai => '精米歩合';

  @override
  String get beverageDetailRegion => '地域';

  @override
  String get beverageDetailType => '種類';

  @override
  String get beverageDetailAddToList => 'リスト';

  @override
  String get beverageDetailAggregatedFlavor => 'フレーバー傾向';

  @override
  String get beverageDetailAbout => '蔵元について';

  @override
  String get beverageDetailRecent => '最近のチェックイン';

  @override
  String get beverageNoCheckinsTitle => 'まだチェックインがありません';

  @override
  String get beverageNoCheckinsBody => '最初の一本を記録しましょう。';

  @override
  String get breweryOverline => '蔵元';

  @override
  String get breweryFounded => '創業';

  @override
  String get breweryBeverages => '銘柄';

  @override
  String get breweryNoBeverages => 'まだ銘柄がありません';

  @override
  String get actionSave => '保存';

  @override
  String get actionCancel => 'キャンセル';

  @override
  String get actionDelete => '削除';

  @override
  String get actionPost => '投稿';

  @override
  String get actionRetry => '再試行';

  @override
  String get actionLoadingMore => '読み込み中';

  @override
  String get actionEndOfList => 'リストの終わり';

  @override
  String get actionEndOfFeed => 'フィードの終わり';

  @override
  String get errorGeneric => '読み込めませんでした。タップしてやり直し。';

  @override
  String get errorNetwork => '接続できません。タップしてやり直し。';

  @override
  String get errorUnauthorized => 'もう一度サインインしてください。';

  @override
  String get loadingLabel => '読み込み中';

  @override
  String get submitBeverageRequestTitle => '飲料を提案';

  @override
  String get submitBeverageRequestNameLabel => '名称';

  @override
  String get submitBeverageRequestBreweryLabel => '蔵元';

  @override
  String get submitBeverageRequestCategoryLabel => 'カテゴリー';

  @override
  String get submitBeverageRequestNotesLabel => '備考（任意）';

  @override
  String get submitBeverageRequestSubmitButton => '送信';

  @override
  String get submitBeverageRequestSuccessToast => 'ご提案ありがとうございます。確認いたします。';

  @override
  String get submitBeverageRequestErrorGeneric => '送信できませんでした。再試行してください。';

  @override
  String get submitBeverageRequestNameRequired => '名称は必須です。';

  @override
  String get submitBeverageRequestBreweryRequired => '蔵元は必須です。';

  @override
  String get searchSuggestMissingCta => '見つからない場合は提案';
}
