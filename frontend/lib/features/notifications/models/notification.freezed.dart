// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$KamosNotification {

 String get id; NotificationType get type; CheckinUser? get actor; String? get checkInId; String? get commentId; String? get readAt; String get createdAt;
/// Create a copy of KamosNotification
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KamosNotificationCopyWith<KamosNotification> get copyWith => _$KamosNotificationCopyWithImpl<KamosNotification>(this as KamosNotification, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KamosNotification&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.actor, actor) || other.actor == actor)&&(identical(other.checkInId, checkInId) || other.checkInId == checkInId)&&(identical(other.commentId, commentId) || other.commentId == commentId)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,type,actor,checkInId,commentId,readAt,createdAt);

@override
String toString() {
  return 'KamosNotification(id: $id, type: $type, actor: $actor, checkInId: $checkInId, commentId: $commentId, readAt: $readAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $KamosNotificationCopyWith<$Res>  {
  factory $KamosNotificationCopyWith(KamosNotification value, $Res Function(KamosNotification) _then) = _$KamosNotificationCopyWithImpl;
@useResult
$Res call({
 String id, NotificationType type, CheckinUser? actor, String? checkInId, String? commentId, String? readAt, String createdAt
});


$CheckinUserCopyWith<$Res>? get actor;

}
/// @nodoc
class _$KamosNotificationCopyWithImpl<$Res>
    implements $KamosNotificationCopyWith<$Res> {
  _$KamosNotificationCopyWithImpl(this._self, this._then);

  final KamosNotification _self;
  final $Res Function(KamosNotification) _then;

/// Create a copy of KamosNotification
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? actor = freezed,Object? checkInId = freezed,Object? commentId = freezed,Object? readAt = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as NotificationType,actor: freezed == actor ? _self.actor : actor // ignore: cast_nullable_to_non_nullable
as CheckinUser?,checkInId: freezed == checkInId ? _self.checkInId : checkInId // ignore: cast_nullable_to_non_nullable
as String?,commentId: freezed == commentId ? _self.commentId : commentId // ignore: cast_nullable_to_non_nullable
as String?,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of KamosNotification
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CheckinUserCopyWith<$Res>? get actor {
    if (_self.actor == null) {
    return null;
  }

  return $CheckinUserCopyWith<$Res>(_self.actor!, (value) {
    return _then(_self.copyWith(actor: value));
  });
}
}


/// Adds pattern-matching-related methods to [KamosNotification].
extension KamosNotificationPatterns on KamosNotification {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KamosNotification value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KamosNotification() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KamosNotification value)  $default,){
final _that = this;
switch (_that) {
case _KamosNotification():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KamosNotification value)?  $default,){
final _that = this;
switch (_that) {
case _KamosNotification() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  NotificationType type,  CheckinUser? actor,  String? checkInId,  String? commentId,  String? readAt,  String createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KamosNotification() when $default != null:
return $default(_that.id,_that.type,_that.actor,_that.checkInId,_that.commentId,_that.readAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  NotificationType type,  CheckinUser? actor,  String? checkInId,  String? commentId,  String? readAt,  String createdAt)  $default,) {final _that = this;
switch (_that) {
case _KamosNotification():
return $default(_that.id,_that.type,_that.actor,_that.checkInId,_that.commentId,_that.readAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  NotificationType type,  CheckinUser? actor,  String? checkInId,  String? commentId,  String? readAt,  String createdAt)?  $default,) {final _that = this;
switch (_that) {
case _KamosNotification() when $default != null:
return $default(_that.id,_that.type,_that.actor,_that.checkInId,_that.commentId,_that.readAt,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _KamosNotification implements KamosNotification {
  const _KamosNotification({required this.id, required this.type, this.actor, this.checkInId, this.commentId, this.readAt, this.createdAt = ''});
  

@override final  String id;
@override final  NotificationType type;
@override final  CheckinUser? actor;
@override final  String? checkInId;
@override final  String? commentId;
@override final  String? readAt;
@override@JsonKey() final  String createdAt;

/// Create a copy of KamosNotification
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KamosNotificationCopyWith<_KamosNotification> get copyWith => __$KamosNotificationCopyWithImpl<_KamosNotification>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KamosNotification&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.actor, actor) || other.actor == actor)&&(identical(other.checkInId, checkInId) || other.checkInId == checkInId)&&(identical(other.commentId, commentId) || other.commentId == commentId)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,type,actor,checkInId,commentId,readAt,createdAt);

@override
String toString() {
  return 'KamosNotification(id: $id, type: $type, actor: $actor, checkInId: $checkInId, commentId: $commentId, readAt: $readAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$KamosNotificationCopyWith<$Res> implements $KamosNotificationCopyWith<$Res> {
  factory _$KamosNotificationCopyWith(_KamosNotification value, $Res Function(_KamosNotification) _then) = __$KamosNotificationCopyWithImpl;
@override @useResult
$Res call({
 String id, NotificationType type, CheckinUser? actor, String? checkInId, String? commentId, String? readAt, String createdAt
});


@override $CheckinUserCopyWith<$Res>? get actor;

}
/// @nodoc
class __$KamosNotificationCopyWithImpl<$Res>
    implements _$KamosNotificationCopyWith<$Res> {
  __$KamosNotificationCopyWithImpl(this._self, this._then);

  final _KamosNotification _self;
  final $Res Function(_KamosNotification) _then;

/// Create a copy of KamosNotification
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? actor = freezed,Object? checkInId = freezed,Object? commentId = freezed,Object? readAt = freezed,Object? createdAt = null,}) {
  return _then(_KamosNotification(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as NotificationType,actor: freezed == actor ? _self.actor : actor // ignore: cast_nullable_to_non_nullable
as CheckinUser?,checkInId: freezed == checkInId ? _self.checkInId : checkInId // ignore: cast_nullable_to_non_nullable
as String?,commentId: freezed == commentId ? _self.commentId : commentId // ignore: cast_nullable_to_non_nullable
as String?,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of KamosNotification
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CheckinUserCopyWith<$Res>? get actor {
    if (_self.actor == null) {
    return null;
  }

  return $CheckinUserCopyWith<$Res>(_self.actor!, (value) {
    return _then(_self.copyWith(actor: value));
  });
}
}

// dart format on
