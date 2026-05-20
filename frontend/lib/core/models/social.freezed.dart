// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'social.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FollowRequest {

 String get userId; String get username; String get displayUsername; String get displayName; String? get avatarUrl; String? get bio; String get createdAt;
/// Create a copy of FollowRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FollowRequestCopyWith<FollowRequest> get copyWith => _$FollowRequestCopyWithImpl<FollowRequest>(this as FollowRequest, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FollowRequest&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayUsername, displayUsername) || other.displayUsername == displayUsername)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,userId,username,displayUsername,displayName,avatarUrl,bio,createdAt);

@override
String toString() {
  return 'FollowRequest(userId: $userId, username: $username, displayUsername: $displayUsername, displayName: $displayName, avatarUrl: $avatarUrl, bio: $bio, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $FollowRequestCopyWith<$Res>  {
  factory $FollowRequestCopyWith(FollowRequest value, $Res Function(FollowRequest) _then) = _$FollowRequestCopyWithImpl;
@useResult
$Res call({
 String userId, String username, String displayUsername, String displayName, String? avatarUrl, String? bio, String createdAt
});




}
/// @nodoc
class _$FollowRequestCopyWithImpl<$Res>
    implements $FollowRequestCopyWith<$Res> {
  _$FollowRequestCopyWithImpl(this._self, this._then);

  final FollowRequest _self;
  final $Res Function(FollowRequest) _then;

/// Create a copy of FollowRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? username = null,Object? displayUsername = null,Object? displayName = null,Object? avatarUrl = freezed,Object? bio = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayUsername: null == displayUsername ? _self.displayUsername : displayUsername // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [FollowRequest].
extension FollowRequestPatterns on FollowRequest {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FollowRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FollowRequest() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FollowRequest value)  $default,){
final _that = this;
switch (_that) {
case _FollowRequest():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FollowRequest value)?  $default,){
final _that = this;
switch (_that) {
case _FollowRequest() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userId,  String username,  String displayUsername,  String displayName,  String? avatarUrl,  String? bio,  String createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FollowRequest() when $default != null:
return $default(_that.userId,_that.username,_that.displayUsername,_that.displayName,_that.avatarUrl,_that.bio,_that.createdAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userId,  String username,  String displayUsername,  String displayName,  String? avatarUrl,  String? bio,  String createdAt)  $default,) {final _that = this;
switch (_that) {
case _FollowRequest():
return $default(_that.userId,_that.username,_that.displayUsername,_that.displayName,_that.avatarUrl,_that.bio,_that.createdAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userId,  String username,  String displayUsername,  String displayName,  String? avatarUrl,  String? bio,  String createdAt)?  $default,) {final _that = this;
switch (_that) {
case _FollowRequest() when $default != null:
return $default(_that.userId,_that.username,_that.displayUsername,_that.displayName,_that.avatarUrl,_that.bio,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _FollowRequest implements FollowRequest {
  const _FollowRequest({required this.userId, required this.username, required this.displayUsername, required this.displayName, this.avatarUrl, this.bio, this.createdAt = ''});
  

@override final  String userId;
@override final  String username;
@override final  String displayUsername;
@override final  String displayName;
@override final  String? avatarUrl;
@override final  String? bio;
@override@JsonKey() final  String createdAt;

/// Create a copy of FollowRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FollowRequestCopyWith<_FollowRequest> get copyWith => __$FollowRequestCopyWithImpl<_FollowRequest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FollowRequest&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayUsername, displayUsername) || other.displayUsername == displayUsername)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,userId,username,displayUsername,displayName,avatarUrl,bio,createdAt);

@override
String toString() {
  return 'FollowRequest(userId: $userId, username: $username, displayUsername: $displayUsername, displayName: $displayName, avatarUrl: $avatarUrl, bio: $bio, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$FollowRequestCopyWith<$Res> implements $FollowRequestCopyWith<$Res> {
  factory _$FollowRequestCopyWith(_FollowRequest value, $Res Function(_FollowRequest) _then) = __$FollowRequestCopyWithImpl;
@override @useResult
$Res call({
 String userId, String username, String displayUsername, String displayName, String? avatarUrl, String? bio, String createdAt
});




}
/// @nodoc
class __$FollowRequestCopyWithImpl<$Res>
    implements _$FollowRequestCopyWith<$Res> {
  __$FollowRequestCopyWithImpl(this._self, this._then);

  final _FollowRequest _self;
  final $Res Function(_FollowRequest) _then;

/// Create a copy of FollowRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? username = null,Object? displayUsername = null,Object? displayName = null,Object? avatarUrl = freezed,Object? bio = freezed,Object? createdAt = null,}) {
  return _then(_FollowRequest(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayUsername: null == displayUsername ? _self.displayUsername : displayUsername // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$FollowResult {

 String get status;
/// Create a copy of FollowResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FollowResultCopyWith<FollowResult> get copyWith => _$FollowResultCopyWithImpl<FollowResult>(this as FollowResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FollowResult&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode => Object.hash(runtimeType,status);

@override
String toString() {
  return 'FollowResult(status: $status)';
}


}

/// @nodoc
abstract mixin class $FollowResultCopyWith<$Res>  {
  factory $FollowResultCopyWith(FollowResult value, $Res Function(FollowResult) _then) = _$FollowResultCopyWithImpl;
@useResult
$Res call({
 String status
});




}
/// @nodoc
class _$FollowResultCopyWithImpl<$Res>
    implements $FollowResultCopyWith<$Res> {
  _$FollowResultCopyWithImpl(this._self, this._then);

  final FollowResult _self;
  final $Res Function(FollowResult) _then;

/// Create a copy of FollowResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [FollowResult].
extension FollowResultPatterns on FollowResult {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FollowResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FollowResult() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FollowResult value)  $default,){
final _that = this;
switch (_that) {
case _FollowResult():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FollowResult value)?  $default,){
final _that = this;
switch (_that) {
case _FollowResult() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FollowResult() when $default != null:
return $default(_that.status);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String status)  $default,) {final _that = this;
switch (_that) {
case _FollowResult():
return $default(_that.status);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String status)?  $default,) {final _that = this;
switch (_that) {
case _FollowResult() when $default != null:
return $default(_that.status);case _:
  return null;

}
}

}

/// @nodoc


class _FollowResult implements FollowResult {
  const _FollowResult({this.status = ''});
  

@override@JsonKey() final  String status;

/// Create a copy of FollowResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FollowResultCopyWith<_FollowResult> get copyWith => __$FollowResultCopyWithImpl<_FollowResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FollowResult&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode => Object.hash(runtimeType,status);

@override
String toString() {
  return 'FollowResult(status: $status)';
}


}

/// @nodoc
abstract mixin class _$FollowResultCopyWith<$Res> implements $FollowResultCopyWith<$Res> {
  factory _$FollowResultCopyWith(_FollowResult value, $Res Function(_FollowResult) _then) = __$FollowResultCopyWithImpl;
@override @useResult
$Res call({
 String status
});




}
/// @nodoc
class __$FollowResultCopyWithImpl<$Res>
    implements _$FollowResultCopyWith<$Res> {
  __$FollowResultCopyWithImpl(this._self, this._then);

  final _FollowResult _self;
  final $Res Function(_FollowResult) _then;

/// Create a copy of FollowResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,}) {
  return _then(_FollowResult(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$SocialUser {

 String get id; String get username; String get displayUsername; String get displayName; String? get avatarUrl; String get followedAt;
/// Create a copy of SocialUser
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SocialUserCopyWith<SocialUser> get copyWith => _$SocialUserCopyWithImpl<SocialUser>(this as SocialUser, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SocialUser&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayUsername, displayUsername) || other.displayUsername == displayUsername)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.followedAt, followedAt) || other.followedAt == followedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,username,displayUsername,displayName,avatarUrl,followedAt);

@override
String toString() {
  return 'SocialUser(id: $id, username: $username, displayUsername: $displayUsername, displayName: $displayName, avatarUrl: $avatarUrl, followedAt: $followedAt)';
}


}

/// @nodoc
abstract mixin class $SocialUserCopyWith<$Res>  {
  factory $SocialUserCopyWith(SocialUser value, $Res Function(SocialUser) _then) = _$SocialUserCopyWithImpl;
@useResult
$Res call({
 String id, String username, String displayUsername, String displayName, String? avatarUrl, String followedAt
});




}
/// @nodoc
class _$SocialUserCopyWithImpl<$Res>
    implements $SocialUserCopyWith<$Res> {
  _$SocialUserCopyWithImpl(this._self, this._then);

  final SocialUser _self;
  final $Res Function(SocialUser) _then;

/// Create a copy of SocialUser
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? username = null,Object? displayUsername = null,Object? displayName = null,Object? avatarUrl = freezed,Object? followedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayUsername: null == displayUsername ? _self.displayUsername : displayUsername // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,followedAt: null == followedAt ? _self.followedAt : followedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SocialUser].
extension SocialUserPatterns on SocialUser {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SocialUser value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SocialUser() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SocialUser value)  $default,){
final _that = this;
switch (_that) {
case _SocialUser():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SocialUser value)?  $default,){
final _that = this;
switch (_that) {
case _SocialUser() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String username,  String displayUsername,  String displayName,  String? avatarUrl,  String followedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SocialUser() when $default != null:
return $default(_that.id,_that.username,_that.displayUsername,_that.displayName,_that.avatarUrl,_that.followedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String username,  String displayUsername,  String displayName,  String? avatarUrl,  String followedAt)  $default,) {final _that = this;
switch (_that) {
case _SocialUser():
return $default(_that.id,_that.username,_that.displayUsername,_that.displayName,_that.avatarUrl,_that.followedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String username,  String displayUsername,  String displayName,  String? avatarUrl,  String followedAt)?  $default,) {final _that = this;
switch (_that) {
case _SocialUser() when $default != null:
return $default(_that.id,_that.username,_that.displayUsername,_that.displayName,_that.avatarUrl,_that.followedAt);case _:
  return null;

}
}

}

/// @nodoc


class _SocialUser implements SocialUser {
  const _SocialUser({required this.id, required this.username, required this.displayUsername, required this.displayName, this.avatarUrl, this.followedAt = ''});
  

@override final  String id;
@override final  String username;
@override final  String displayUsername;
@override final  String displayName;
@override final  String? avatarUrl;
@override@JsonKey() final  String followedAt;

/// Create a copy of SocialUser
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SocialUserCopyWith<_SocialUser> get copyWith => __$SocialUserCopyWithImpl<_SocialUser>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SocialUser&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayUsername, displayUsername) || other.displayUsername == displayUsername)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.followedAt, followedAt) || other.followedAt == followedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,username,displayUsername,displayName,avatarUrl,followedAt);

@override
String toString() {
  return 'SocialUser(id: $id, username: $username, displayUsername: $displayUsername, displayName: $displayName, avatarUrl: $avatarUrl, followedAt: $followedAt)';
}


}

/// @nodoc
abstract mixin class _$SocialUserCopyWith<$Res> implements $SocialUserCopyWith<$Res> {
  factory _$SocialUserCopyWith(_SocialUser value, $Res Function(_SocialUser) _then) = __$SocialUserCopyWithImpl;
@override @useResult
$Res call({
 String id, String username, String displayUsername, String displayName, String? avatarUrl, String followedAt
});




}
/// @nodoc
class __$SocialUserCopyWithImpl<$Res>
    implements _$SocialUserCopyWith<$Res> {
  __$SocialUserCopyWithImpl(this._self, this._then);

  final _SocialUser _self;
  final $Res Function(_SocialUser) _then;

/// Create a copy of SocialUser
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? username = null,Object? displayUsername = null,Object? displayName = null,Object? avatarUrl = freezed,Object? followedAt = null,}) {
  return _then(_SocialUser(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayUsername: null == displayUsername ? _self.displayUsername : displayUsername // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,followedAt: null == followedAt ? _self.followedAt : followedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
