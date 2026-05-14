// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$UserStats {
  int get checkins => throw _privateConstructorUsedError;
  int get unique => throw _privateConstructorUsedError;
  int get followers => throw _privateConstructorUsedError;
  int get following => throw _privateConstructorUsedError;

  /// Create a copy of UserStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserStatsCopyWith<UserStats> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserStatsCopyWith<$Res> {
  factory $UserStatsCopyWith(UserStats value, $Res Function(UserStats) then) =
      _$UserStatsCopyWithImpl<$Res, UserStats>;
  @useResult
  $Res call({int checkins, int unique, int followers, int following});
}

/// @nodoc
class _$UserStatsCopyWithImpl<$Res, $Val extends UserStats>
    implements $UserStatsCopyWith<$Res> {
  _$UserStatsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? checkins = null,
    Object? unique = null,
    Object? followers = null,
    Object? following = null,
  }) {
    return _then(_value.copyWith(
      checkins: null == checkins
          ? _value.checkins
          : checkins // ignore: cast_nullable_to_non_nullable
              as int,
      unique: null == unique
          ? _value.unique
          : unique // ignore: cast_nullable_to_non_nullable
              as int,
      followers: null == followers
          ? _value.followers
          : followers // ignore: cast_nullable_to_non_nullable
              as int,
      following: null == following
          ? _value.following
          : following // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserStatsImplCopyWith<$Res>
    implements $UserStatsCopyWith<$Res> {
  factory _$$UserStatsImplCopyWith(
          _$UserStatsImpl value, $Res Function(_$UserStatsImpl) then) =
      __$$UserStatsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int checkins, int unique, int followers, int following});
}

/// @nodoc
class __$$UserStatsImplCopyWithImpl<$Res>
    extends _$UserStatsCopyWithImpl<$Res, _$UserStatsImpl>
    implements _$$UserStatsImplCopyWith<$Res> {
  __$$UserStatsImplCopyWithImpl(
      _$UserStatsImpl _value, $Res Function(_$UserStatsImpl) _then)
      : super(_value, _then);

  /// Create a copy of UserStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? checkins = null,
    Object? unique = null,
    Object? followers = null,
    Object? following = null,
  }) {
    return _then(_$UserStatsImpl(
      checkins: null == checkins
          ? _value.checkins
          : checkins // ignore: cast_nullable_to_non_nullable
              as int,
      unique: null == unique
          ? _value.unique
          : unique // ignore: cast_nullable_to_non_nullable
              as int,
      followers: null == followers
          ? _value.followers
          : followers // ignore: cast_nullable_to_non_nullable
              as int,
      following: null == following
          ? _value.following
          : following // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$UserStatsImpl implements _UserStats {
  const _$UserStatsImpl(
      {this.checkins = 0,
      this.unique = 0,
      this.followers = 0,
      this.following = 0});

  @override
  @JsonKey()
  final int checkins;
  @override
  @JsonKey()
  final int unique;
  @override
  @JsonKey()
  final int followers;
  @override
  @JsonKey()
  final int following;

  @override
  String toString() {
    return 'UserStats(checkins: $checkins, unique: $unique, followers: $followers, following: $following)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserStatsImpl &&
            (identical(other.checkins, checkins) ||
                other.checkins == checkins) &&
            (identical(other.unique, unique) || other.unique == unique) &&
            (identical(other.followers, followers) ||
                other.followers == followers) &&
            (identical(other.following, following) ||
                other.following == following));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, checkins, unique, followers, following);

  /// Create a copy of UserStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserStatsImplCopyWith<_$UserStatsImpl> get copyWith =>
      __$$UserStatsImplCopyWithImpl<_$UserStatsImpl>(this, _$identity);
}

abstract class _UserStats implements UserStats {
  const factory _UserStats(
      {final int checkins,
      final int unique,
      final int followers,
      final int following}) = _$UserStatsImpl;

  @override
  int get checkins;
  @override
  int get unique;
  @override
  int get followers;
  @override
  int get following;

  /// Create a copy of UserStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserStatsImplCopyWith<_$UserStatsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$User {
  String get id => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  String get displayUsername =>
      throw _privateConstructorUsedError; // Email may be absent or null on a public profile in some server builds.
  String? get email => throw _privateConstructorUsedError;
  bool get emailVerified => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String? get avatarUrl => throw _privateConstructorUsedError;
  String? get bio => throw _privateConstructorUsedError;
  String get locale => throw _privateConstructorUsedError;
  String get privacyMode => throw _privateConstructorUsedError;
  String get createdAt => throw _privateConstructorUsedError;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserCopyWith<User> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserCopyWith<$Res> {
  factory $UserCopyWith(User value, $Res Function(User) then) =
      _$UserCopyWithImpl<$Res, User>;
  @useResult
  $Res call(
      {String id,
      String username,
      String displayUsername,
      String? email,
      bool emailVerified,
      String displayName,
      String? avatarUrl,
      String? bio,
      String locale,
      String privacyMode,
      String createdAt});
}

/// @nodoc
class _$UserCopyWithImpl<$Res, $Val extends User>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? displayUsername = null,
    Object? email = freezed,
    Object? emailVerified = null,
    Object? displayName = null,
    Object? avatarUrl = freezed,
    Object? bio = freezed,
    Object? locale = null,
    Object? privacyMode = null,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      displayUsername: null == displayUsername
          ? _value.displayUsername
          : displayUsername // ignore: cast_nullable_to_non_nullable
              as String,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      emailVerified: null == emailVerified
          ? _value.emailVerified
          : emailVerified // ignore: cast_nullable_to_non_nullable
              as bool,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      bio: freezed == bio
          ? _value.bio
          : bio // ignore: cast_nullable_to_non_nullable
              as String?,
      locale: null == locale
          ? _value.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String,
      privacyMode: null == privacyMode
          ? _value.privacyMode
          : privacyMode // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserImplCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$$UserImplCopyWith(
          _$UserImpl value, $Res Function(_$UserImpl) then) =
      __$$UserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String username,
      String displayUsername,
      String? email,
      bool emailVerified,
      String displayName,
      String? avatarUrl,
      String? bio,
      String locale,
      String privacyMode,
      String createdAt});
}

/// @nodoc
class __$$UserImplCopyWithImpl<$Res>
    extends _$UserCopyWithImpl<$Res, _$UserImpl>
    implements _$$UserImplCopyWith<$Res> {
  __$$UserImplCopyWithImpl(_$UserImpl _value, $Res Function(_$UserImpl) _then)
      : super(_value, _then);

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? displayUsername = null,
    Object? email = freezed,
    Object? emailVerified = null,
    Object? displayName = null,
    Object? avatarUrl = freezed,
    Object? bio = freezed,
    Object? locale = null,
    Object? privacyMode = null,
    Object? createdAt = null,
  }) {
    return _then(_$UserImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      displayUsername: null == displayUsername
          ? _value.displayUsername
          : displayUsername // ignore: cast_nullable_to_non_nullable
              as String,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      emailVerified: null == emailVerified
          ? _value.emailVerified
          : emailVerified // ignore: cast_nullable_to_non_nullable
              as bool,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      bio: freezed == bio
          ? _value.bio
          : bio // ignore: cast_nullable_to_non_nullable
              as String?,
      locale: null == locale
          ? _value.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String,
      privacyMode: null == privacyMode
          ? _value.privacyMode
          : privacyMode // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$UserImpl implements _User {
  const _$UserImpl(
      {required this.id,
      required this.username,
      required this.displayUsername,
      this.email,
      this.emailVerified = false,
      this.displayName = '',
      this.avatarUrl,
      this.bio,
      this.locale = 'en',
      this.privacyMode = 'public',
      this.createdAt = ''});

  @override
  final String id;
  @override
  final String username;
  @override
  final String displayUsername;
// Email may be absent or null on a public profile in some server builds.
  @override
  final String? email;
  @override
  @JsonKey()
  final bool emailVerified;
  @override
  @JsonKey()
  final String displayName;
  @override
  final String? avatarUrl;
  @override
  final String? bio;
  @override
  @JsonKey()
  final String locale;
  @override
  @JsonKey()
  final String privacyMode;
  @override
  @JsonKey()
  final String createdAt;

  @override
  String toString() {
    return 'User(id: $id, username: $username, displayUsername: $displayUsername, email: $email, emailVerified: $emailVerified, displayName: $displayName, avatarUrl: $avatarUrl, bio: $bio, locale: $locale, privacyMode: $privacyMode, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.displayUsername, displayUsername) ||
                other.displayUsername == displayUsername) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.emailVerified, emailVerified) ||
                other.emailVerified == emailVerified) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.bio, bio) || other.bio == bio) &&
            (identical(other.locale, locale) || other.locale == locale) &&
            (identical(other.privacyMode, privacyMode) ||
                other.privacyMode == privacyMode) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      username,
      displayUsername,
      email,
      emailVerified,
      displayName,
      avatarUrl,
      bio,
      locale,
      privacyMode,
      createdAt);

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserImplCopyWith<_$UserImpl> get copyWith =>
      __$$UserImplCopyWithImpl<_$UserImpl>(this, _$identity);
}

abstract class _User implements User {
  const factory _User(
      {required final String id,
      required final String username,
      required final String displayUsername,
      final String? email,
      final bool emailVerified,
      final String displayName,
      final String? avatarUrl,
      final String? bio,
      final String locale,
      final String privacyMode,
      final String createdAt}) = _$UserImpl;

  @override
  String get id;
  @override
  String get username;
  @override
  String
      get displayUsername; // Email may be absent or null on a public profile in some server builds.
  @override
  String? get email;
  @override
  bool get emailVerified;
  @override
  String get displayName;
  @override
  String? get avatarUrl;
  @override
  String? get bio;
  @override
  String get locale;
  @override
  String get privacyMode;
  @override
  String get createdAt;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserImplCopyWith<_$UserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$Me {
  User get user => throw _privateConstructorUsedError;
  UserStats get stats => throw _privateConstructorUsedError;

  /// Create a copy of Me
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MeCopyWith<Me> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MeCopyWith<$Res> {
  factory $MeCopyWith(Me value, $Res Function(Me) then) =
      _$MeCopyWithImpl<$Res, Me>;
  @useResult
  $Res call({User user, UserStats stats});

  $UserCopyWith<$Res> get user;
  $UserStatsCopyWith<$Res> get stats;
}

/// @nodoc
class _$MeCopyWithImpl<$Res, $Val extends Me> implements $MeCopyWith<$Res> {
  _$MeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Me
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? user = null,
    Object? stats = null,
  }) {
    return _then(_value.copyWith(
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as User,
      stats: null == stats
          ? _value.stats
          : stats // ignore: cast_nullable_to_non_nullable
              as UserStats,
    ) as $Val);
  }

  /// Create a copy of Me
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserCopyWith<$Res> get user {
    return $UserCopyWith<$Res>(_value.user, (value) {
      return _then(_value.copyWith(user: value) as $Val);
    });
  }

  /// Create a copy of Me
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserStatsCopyWith<$Res> get stats {
    return $UserStatsCopyWith<$Res>(_value.stats, (value) {
      return _then(_value.copyWith(stats: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$MeImplCopyWith<$Res> implements $MeCopyWith<$Res> {
  factory _$$MeImplCopyWith(_$MeImpl value, $Res Function(_$MeImpl) then) =
      __$$MeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({User user, UserStats stats});

  @override
  $UserCopyWith<$Res> get user;
  @override
  $UserStatsCopyWith<$Res> get stats;
}

/// @nodoc
class __$$MeImplCopyWithImpl<$Res> extends _$MeCopyWithImpl<$Res, _$MeImpl>
    implements _$$MeImplCopyWith<$Res> {
  __$$MeImplCopyWithImpl(_$MeImpl _value, $Res Function(_$MeImpl) _then)
      : super(_value, _then);

  /// Create a copy of Me
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? user = null,
    Object? stats = null,
  }) {
    return _then(_$MeImpl(
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as User,
      stats: null == stats
          ? _value.stats
          : stats // ignore: cast_nullable_to_non_nullable
              as UserStats,
    ));
  }
}

/// @nodoc

class _$MeImpl implements _Me {
  const _$MeImpl({required this.user, required this.stats});

  @override
  final User user;
  @override
  final UserStats stats;

  @override
  String toString() {
    return 'Me(user: $user, stats: $stats)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MeImpl &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.stats, stats) || other.stats == stats));
  }

  @override
  int get hashCode => Object.hash(runtimeType, user, stats);

  /// Create a copy of Me
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MeImplCopyWith<_$MeImpl> get copyWith =>
      __$$MeImplCopyWithImpl<_$MeImpl>(this, _$identity);
}

abstract class _Me implements Me {
  const factory _Me(
      {required final User user, required final UserStats stats}) = _$MeImpl;

  @override
  User get user;
  @override
  UserStats get stats;

  /// Create a copy of Me
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MeImplCopyWith<_$MeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PublicProfile {
  User get user => throw _privateConstructorUsedError;
  UserStats get stats => throw _privateConstructorUsedError;
  String get followState => throw _privateConstructorUsedError;
  bool get restricted => throw _privateConstructorUsedError;

  /// Create a copy of PublicProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PublicProfileCopyWith<PublicProfile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PublicProfileCopyWith<$Res> {
  factory $PublicProfileCopyWith(
          PublicProfile value, $Res Function(PublicProfile) then) =
      _$PublicProfileCopyWithImpl<$Res, PublicProfile>;
  @useResult
  $Res call({User user, UserStats stats, String followState, bool restricted});

  $UserCopyWith<$Res> get user;
  $UserStatsCopyWith<$Res> get stats;
}

/// @nodoc
class _$PublicProfileCopyWithImpl<$Res, $Val extends PublicProfile>
    implements $PublicProfileCopyWith<$Res> {
  _$PublicProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PublicProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? user = null,
    Object? stats = null,
    Object? followState = null,
    Object? restricted = null,
  }) {
    return _then(_value.copyWith(
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as User,
      stats: null == stats
          ? _value.stats
          : stats // ignore: cast_nullable_to_non_nullable
              as UserStats,
      followState: null == followState
          ? _value.followState
          : followState // ignore: cast_nullable_to_non_nullable
              as String,
      restricted: null == restricted
          ? _value.restricted
          : restricted // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }

  /// Create a copy of PublicProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserCopyWith<$Res> get user {
    return $UserCopyWith<$Res>(_value.user, (value) {
      return _then(_value.copyWith(user: value) as $Val);
    });
  }

  /// Create a copy of PublicProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserStatsCopyWith<$Res> get stats {
    return $UserStatsCopyWith<$Res>(_value.stats, (value) {
      return _then(_value.copyWith(stats: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$PublicProfileImplCopyWith<$Res>
    implements $PublicProfileCopyWith<$Res> {
  factory _$$PublicProfileImplCopyWith(
          _$PublicProfileImpl value, $Res Function(_$PublicProfileImpl) then) =
      __$$PublicProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({User user, UserStats stats, String followState, bool restricted});

  @override
  $UserCopyWith<$Res> get user;
  @override
  $UserStatsCopyWith<$Res> get stats;
}

/// @nodoc
class __$$PublicProfileImplCopyWithImpl<$Res>
    extends _$PublicProfileCopyWithImpl<$Res, _$PublicProfileImpl>
    implements _$$PublicProfileImplCopyWith<$Res> {
  __$$PublicProfileImplCopyWithImpl(
      _$PublicProfileImpl _value, $Res Function(_$PublicProfileImpl) _then)
      : super(_value, _then);

  /// Create a copy of PublicProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? user = null,
    Object? stats = null,
    Object? followState = null,
    Object? restricted = null,
  }) {
    return _then(_$PublicProfileImpl(
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as User,
      stats: null == stats
          ? _value.stats
          : stats // ignore: cast_nullable_to_non_nullable
              as UserStats,
      followState: null == followState
          ? _value.followState
          : followState // ignore: cast_nullable_to_non_nullable
              as String,
      restricted: null == restricted
          ? _value.restricted
          : restricted // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$PublicProfileImpl implements _PublicProfile {
  const _$PublicProfileImpl(
      {required this.user,
      required this.stats,
      this.followState = '',
      this.restricted = false});

  @override
  final User user;
  @override
  final UserStats stats;
  @override
  @JsonKey()
  final String followState;
  @override
  @JsonKey()
  final bool restricted;

  @override
  String toString() {
    return 'PublicProfile(user: $user, stats: $stats, followState: $followState, restricted: $restricted)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PublicProfileImpl &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.stats, stats) || other.stats == stats) &&
            (identical(other.followState, followState) ||
                other.followState == followState) &&
            (identical(other.restricted, restricted) ||
                other.restricted == restricted));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, user, stats, followState, restricted);

  /// Create a copy of PublicProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PublicProfileImplCopyWith<_$PublicProfileImpl> get copyWith =>
      __$$PublicProfileImplCopyWithImpl<_$PublicProfileImpl>(this, _$identity);
}

abstract class _PublicProfile implements PublicProfile {
  const factory _PublicProfile(
      {required final User user,
      required final UserStats stats,
      final String followState,
      final bool restricted}) = _$PublicProfileImpl;

  @override
  User get user;
  @override
  UserStats get stats;
  @override
  String get followState;
  @override
  bool get restricted;

  /// Create a copy of PublicProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PublicProfileImplCopyWith<_$PublicProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
