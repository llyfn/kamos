// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'social.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$FollowRequest {
  String get userId => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  String get displayUsername => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String? get avatarUrl => throw _privateConstructorUsedError;
  String? get bio => throw _privateConstructorUsedError;
  String get createdAt => throw _privateConstructorUsedError;

  /// Create a copy of FollowRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FollowRequestCopyWith<FollowRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FollowRequestCopyWith<$Res> {
  factory $FollowRequestCopyWith(
          FollowRequest value, $Res Function(FollowRequest) then) =
      _$FollowRequestCopyWithImpl<$Res, FollowRequest>;
  @useResult
  $Res call(
      {String userId,
      String username,
      String displayUsername,
      String displayName,
      String? avatarUrl,
      String? bio,
      String createdAt});
}

/// @nodoc
class _$FollowRequestCopyWithImpl<$Res, $Val extends FollowRequest>
    implements $FollowRequestCopyWith<$Res> {
  _$FollowRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FollowRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? username = null,
    Object? displayUsername = null,
    Object? displayName = null,
    Object? avatarUrl = freezed,
    Object? bio = freezed,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      displayUsername: null == displayUsername
          ? _value.displayUsername
          : displayUsername // ignore: cast_nullable_to_non_nullable
              as String,
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
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FollowRequestImplCopyWith<$Res>
    implements $FollowRequestCopyWith<$Res> {
  factory _$$FollowRequestImplCopyWith(
          _$FollowRequestImpl value, $Res Function(_$FollowRequestImpl) then) =
      __$$FollowRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String userId,
      String username,
      String displayUsername,
      String displayName,
      String? avatarUrl,
      String? bio,
      String createdAt});
}

/// @nodoc
class __$$FollowRequestImplCopyWithImpl<$Res>
    extends _$FollowRequestCopyWithImpl<$Res, _$FollowRequestImpl>
    implements _$$FollowRequestImplCopyWith<$Res> {
  __$$FollowRequestImplCopyWithImpl(
      _$FollowRequestImpl _value, $Res Function(_$FollowRequestImpl) _then)
      : super(_value, _then);

  /// Create a copy of FollowRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? username = null,
    Object? displayUsername = null,
    Object? displayName = null,
    Object? avatarUrl = freezed,
    Object? bio = freezed,
    Object? createdAt = null,
  }) {
    return _then(_$FollowRequestImpl(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      displayUsername: null == displayUsername
          ? _value.displayUsername
          : displayUsername // ignore: cast_nullable_to_non_nullable
              as String,
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
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$FollowRequestImpl implements _FollowRequest {
  const _$FollowRequestImpl(
      {required this.userId,
      required this.username,
      required this.displayUsername,
      required this.displayName,
      this.avatarUrl,
      this.bio,
      this.createdAt = ''});

  @override
  final String userId;
  @override
  final String username;
  @override
  final String displayUsername;
  @override
  final String displayName;
  @override
  final String? avatarUrl;
  @override
  final String? bio;
  @override
  @JsonKey()
  final String createdAt;

  @override
  String toString() {
    return 'FollowRequest(userId: $userId, username: $username, displayUsername: $displayUsername, displayName: $displayName, avatarUrl: $avatarUrl, bio: $bio, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FollowRequestImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.displayUsername, displayUsername) ||
                other.displayUsername == displayUsername) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.bio, bio) || other.bio == bio) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @override
  int get hashCode => Object.hash(runtimeType, userId, username,
      displayUsername, displayName, avatarUrl, bio, createdAt);

  /// Create a copy of FollowRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FollowRequestImplCopyWith<_$FollowRequestImpl> get copyWith =>
      __$$FollowRequestImplCopyWithImpl<_$FollowRequestImpl>(this, _$identity);
}

abstract class _FollowRequest implements FollowRequest {
  const factory _FollowRequest(
      {required final String userId,
      required final String username,
      required final String displayUsername,
      required final String displayName,
      final String? avatarUrl,
      final String? bio,
      final String createdAt}) = _$FollowRequestImpl;

  @override
  String get userId;
  @override
  String get username;
  @override
  String get displayUsername;
  @override
  String get displayName;
  @override
  String? get avatarUrl;
  @override
  String? get bio;
  @override
  String get createdAt;

  /// Create a copy of FollowRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FollowRequestImplCopyWith<_$FollowRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$FollowResult {
  String get status => throw _privateConstructorUsedError;

  /// Create a copy of FollowResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FollowResultCopyWith<FollowResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FollowResultCopyWith<$Res> {
  factory $FollowResultCopyWith(
          FollowResult value, $Res Function(FollowResult) then) =
      _$FollowResultCopyWithImpl<$Res, FollowResult>;
  @useResult
  $Res call({String status});
}

/// @nodoc
class _$FollowResultCopyWithImpl<$Res, $Val extends FollowResult>
    implements $FollowResultCopyWith<$Res> {
  _$FollowResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FollowResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
  }) {
    return _then(_value.copyWith(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FollowResultImplCopyWith<$Res>
    implements $FollowResultCopyWith<$Res> {
  factory _$$FollowResultImplCopyWith(
          _$FollowResultImpl value, $Res Function(_$FollowResultImpl) then) =
      __$$FollowResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String status});
}

/// @nodoc
class __$$FollowResultImplCopyWithImpl<$Res>
    extends _$FollowResultCopyWithImpl<$Res, _$FollowResultImpl>
    implements _$$FollowResultImplCopyWith<$Res> {
  __$$FollowResultImplCopyWithImpl(
      _$FollowResultImpl _value, $Res Function(_$FollowResultImpl) _then)
      : super(_value, _then);

  /// Create a copy of FollowResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
  }) {
    return _then(_$FollowResultImpl(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$FollowResultImpl implements _FollowResult {
  const _$FollowResultImpl({this.status = ''});

  @override
  @JsonKey()
  final String status;

  @override
  String toString() {
    return 'FollowResult(status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FollowResultImpl &&
            (identical(other.status, status) || other.status == status));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status);

  /// Create a copy of FollowResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FollowResultImplCopyWith<_$FollowResultImpl> get copyWith =>
      __$$FollowResultImplCopyWithImpl<_$FollowResultImpl>(this, _$identity);
}

abstract class _FollowResult implements FollowResult {
  const factory _FollowResult({final String status}) = _$FollowResultImpl;

  @override
  String get status;

  /// Create a copy of FollowResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FollowResultImplCopyWith<_$FollowResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$SocialUser {
  String get id => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  String get displayUsername => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String? get avatarUrl => throw _privateConstructorUsedError;
  String get followedAt => throw _privateConstructorUsedError;

  /// Create a copy of SocialUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SocialUserCopyWith<SocialUser> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SocialUserCopyWith<$Res> {
  factory $SocialUserCopyWith(
          SocialUser value, $Res Function(SocialUser) then) =
      _$SocialUserCopyWithImpl<$Res, SocialUser>;
  @useResult
  $Res call(
      {String id,
      String username,
      String displayUsername,
      String displayName,
      String? avatarUrl,
      String followedAt});
}

/// @nodoc
class _$SocialUserCopyWithImpl<$Res, $Val extends SocialUser>
    implements $SocialUserCopyWith<$Res> {
  _$SocialUserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SocialUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? displayUsername = null,
    Object? displayName = null,
    Object? avatarUrl = freezed,
    Object? followedAt = null,
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
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      followedAt: null == followedAt
          ? _value.followedAt
          : followedAt // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SocialUserImplCopyWith<$Res>
    implements $SocialUserCopyWith<$Res> {
  factory _$$SocialUserImplCopyWith(
          _$SocialUserImpl value, $Res Function(_$SocialUserImpl) then) =
      __$$SocialUserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String username,
      String displayUsername,
      String displayName,
      String? avatarUrl,
      String followedAt});
}

/// @nodoc
class __$$SocialUserImplCopyWithImpl<$Res>
    extends _$SocialUserCopyWithImpl<$Res, _$SocialUserImpl>
    implements _$$SocialUserImplCopyWith<$Res> {
  __$$SocialUserImplCopyWithImpl(
      _$SocialUserImpl _value, $Res Function(_$SocialUserImpl) _then)
      : super(_value, _then);

  /// Create a copy of SocialUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? displayUsername = null,
    Object? displayName = null,
    Object? avatarUrl = freezed,
    Object? followedAt = null,
  }) {
    return _then(_$SocialUserImpl(
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
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      followedAt: null == followedAt
          ? _value.followedAt
          : followedAt // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$SocialUserImpl implements _SocialUser {
  const _$SocialUserImpl(
      {required this.id,
      required this.username,
      required this.displayUsername,
      required this.displayName,
      this.avatarUrl,
      this.followedAt = ''});

  @override
  final String id;
  @override
  final String username;
  @override
  final String displayUsername;
  @override
  final String displayName;
  @override
  final String? avatarUrl;
  @override
  @JsonKey()
  final String followedAt;

  @override
  String toString() {
    return 'SocialUser(id: $id, username: $username, displayUsername: $displayUsername, displayName: $displayName, avatarUrl: $avatarUrl, followedAt: $followedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SocialUserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.displayUsername, displayUsername) ||
                other.displayUsername == displayUsername) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.followedAt, followedAt) ||
                other.followedAt == followedAt));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, username, displayUsername,
      displayName, avatarUrl, followedAt);

  /// Create a copy of SocialUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SocialUserImplCopyWith<_$SocialUserImpl> get copyWith =>
      __$$SocialUserImplCopyWithImpl<_$SocialUserImpl>(this, _$identity);
}

abstract class _SocialUser implements SocialUser {
  const factory _SocialUser(
      {required final String id,
      required final String username,
      required final String displayUsername,
      required final String displayName,
      final String? avatarUrl,
      final String followedAt}) = _$SocialUserImpl;

  @override
  String get id;
  @override
  String get username;
  @override
  String get displayUsername;
  @override
  String get displayName;
  @override
  String? get avatarUrl;
  @override
  String get followedAt;

  /// Create a copy of SocialUser
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SocialUserImplCopyWith<_$SocialUserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
