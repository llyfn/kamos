// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'beverage_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BeverageRequest {

 String get name; String get breweryName; String get categorySlug; String? get notes;
/// Create a copy of BeverageRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BeverageRequestCopyWith<BeverageRequest> get copyWith => _$BeverageRequestCopyWithImpl<BeverageRequest>(this as BeverageRequest, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BeverageRequest&&(identical(other.name, name) || other.name == name)&&(identical(other.breweryName, breweryName) || other.breweryName == breweryName)&&(identical(other.categorySlug, categorySlug) || other.categorySlug == categorySlug)&&(identical(other.notes, notes) || other.notes == notes));
}


@override
int get hashCode => Object.hash(runtimeType,name,breweryName,categorySlug,notes);

@override
String toString() {
  return 'BeverageRequest(name: $name, breweryName: $breweryName, categorySlug: $categorySlug, notes: $notes)';
}


}

/// @nodoc
abstract mixin class $BeverageRequestCopyWith<$Res>  {
  factory $BeverageRequestCopyWith(BeverageRequest value, $Res Function(BeverageRequest) _then) = _$BeverageRequestCopyWithImpl;
@useResult
$Res call({
 String name, String breweryName, String categorySlug, String? notes
});




}
/// @nodoc
class _$BeverageRequestCopyWithImpl<$Res>
    implements $BeverageRequestCopyWith<$Res> {
  _$BeverageRequestCopyWithImpl(this._self, this._then);

  final BeverageRequest _self;
  final $Res Function(BeverageRequest) _then;

/// Create a copy of BeverageRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? breweryName = null,Object? categorySlug = null,Object? notes = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,breweryName: null == breweryName ? _self.breweryName : breweryName // ignore: cast_nullable_to_non_nullable
as String,categorySlug: null == categorySlug ? _self.categorySlug : categorySlug // ignore: cast_nullable_to_non_nullable
as String,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [BeverageRequest].
extension BeverageRequestPatterns on BeverageRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BeverageRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BeverageRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BeverageRequest value)  $default,){
final _that = this;
switch (_that) {
case _BeverageRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BeverageRequest value)?  $default,){
final _that = this;
switch (_that) {
case _BeverageRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String breweryName,  String categorySlug,  String? notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BeverageRequest() when $default != null:
return $default(_that.name,_that.breweryName,_that.categorySlug,_that.notes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String breweryName,  String categorySlug,  String? notes)  $default,) {final _that = this;
switch (_that) {
case _BeverageRequest():
return $default(_that.name,_that.breweryName,_that.categorySlug,_that.notes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String breweryName,  String categorySlug,  String? notes)?  $default,) {final _that = this;
switch (_that) {
case _BeverageRequest() when $default != null:
return $default(_that.name,_that.breweryName,_that.categorySlug,_that.notes);case _:
  return null;

}
}

}

/// @nodoc


class _BeverageRequest extends BeverageRequest {
  const _BeverageRequest({required this.name, required this.breweryName, required this.categorySlug, this.notes}): super._();
  

@override final  String name;
@override final  String breweryName;
@override final  String categorySlug;
@override final  String? notes;

/// Create a copy of BeverageRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BeverageRequestCopyWith<_BeverageRequest> get copyWith => __$BeverageRequestCopyWithImpl<_BeverageRequest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BeverageRequest&&(identical(other.name, name) || other.name == name)&&(identical(other.breweryName, breweryName) || other.breweryName == breweryName)&&(identical(other.categorySlug, categorySlug) || other.categorySlug == categorySlug)&&(identical(other.notes, notes) || other.notes == notes));
}


@override
int get hashCode => Object.hash(runtimeType,name,breweryName,categorySlug,notes);

@override
String toString() {
  return 'BeverageRequest(name: $name, breweryName: $breweryName, categorySlug: $categorySlug, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$BeverageRequestCopyWith<$Res> implements $BeverageRequestCopyWith<$Res> {
  factory _$BeverageRequestCopyWith(_BeverageRequest value, $Res Function(_BeverageRequest) _then) = __$BeverageRequestCopyWithImpl;
@override @useResult
$Res call({
 String name, String breweryName, String categorySlug, String? notes
});




}
/// @nodoc
class __$BeverageRequestCopyWithImpl<$Res>
    implements _$BeverageRequestCopyWith<$Res> {
  __$BeverageRequestCopyWithImpl(this._self, this._then);

  final _BeverageRequest _self;
  final $Res Function(_BeverageRequest) _then;

/// Create a copy of BeverageRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? breweryName = null,Object? categorySlug = null,Object? notes = freezed,}) {
  return _then(_BeverageRequest(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,breweryName: null == breweryName ? _self.breweryName : breweryName // ignore: cast_nullable_to_non_nullable
as String,categorySlug: null == categorySlug ? _self.categorySlug : categorySlug // ignore: cast_nullable_to_non_nullable
as String,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
