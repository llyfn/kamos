// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'flavor_tag.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FlavorTag {

 String get id; String get slug; String get dimension; I18nText get name;
/// Create a copy of FlavorTag
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FlavorTagCopyWith<FlavorTag> get copyWith => _$FlavorTagCopyWithImpl<FlavorTag>(this as FlavorTag, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FlavorTag&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.dimension, dimension) || other.dimension == dimension)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,id,slug,dimension,name);

@override
String toString() {
  return 'FlavorTag(id: $id, slug: $slug, dimension: $dimension, name: $name)';
}


}

/// @nodoc
abstract mixin class $FlavorTagCopyWith<$Res>  {
  factory $FlavorTagCopyWith(FlavorTag value, $Res Function(FlavorTag) _then) = _$FlavorTagCopyWithImpl;
@useResult
$Res call({
 String id, String slug, String dimension, I18nText name
});


$I18nTextCopyWith<$Res> get name;

}
/// @nodoc
class _$FlavorTagCopyWithImpl<$Res>
    implements $FlavorTagCopyWith<$Res> {
  _$FlavorTagCopyWithImpl(this._self, this._then);

  final FlavorTag _self;
  final $Res Function(FlavorTag) _then;

/// Create a copy of FlavorTag
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? slug = null,Object? dimension = null,Object? name = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,dimension: null == dimension ? _self.dimension : dimension // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as I18nText,
  ));
}
/// Create a copy of FlavorTag
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res> get name {
  
  return $I18nTextCopyWith<$Res>(_self.name, (value) {
    return _then(_self.copyWith(name: value));
  });
}
}


/// Adds pattern-matching-related methods to [FlavorTag].
extension FlavorTagPatterns on FlavorTag {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FlavorTag value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FlavorTag() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FlavorTag value)  $default,){
final _that = this;
switch (_that) {
case _FlavorTag():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FlavorTag value)?  $default,){
final _that = this;
switch (_that) {
case _FlavorTag() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String slug,  String dimension,  I18nText name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FlavorTag() when $default != null:
return $default(_that.id,_that.slug,_that.dimension,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String slug,  String dimension,  I18nText name)  $default,) {final _that = this;
switch (_that) {
case _FlavorTag():
return $default(_that.id,_that.slug,_that.dimension,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String slug,  String dimension,  I18nText name)?  $default,) {final _that = this;
switch (_that) {
case _FlavorTag() when $default != null:
return $default(_that.id,_that.slug,_that.dimension,_that.name);case _:
  return null;

}
}

}

/// @nodoc


class _FlavorTag implements FlavorTag {
  const _FlavorTag({required this.id, required this.slug, required this.dimension, required this.name});
  

@override final  String id;
@override final  String slug;
@override final  String dimension;
@override final  I18nText name;

/// Create a copy of FlavorTag
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FlavorTagCopyWith<_FlavorTag> get copyWith => __$FlavorTagCopyWithImpl<_FlavorTag>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FlavorTag&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.dimension, dimension) || other.dimension == dimension)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,id,slug,dimension,name);

@override
String toString() {
  return 'FlavorTag(id: $id, slug: $slug, dimension: $dimension, name: $name)';
}


}

/// @nodoc
abstract mixin class _$FlavorTagCopyWith<$Res> implements $FlavorTagCopyWith<$Res> {
  factory _$FlavorTagCopyWith(_FlavorTag value, $Res Function(_FlavorTag) _then) = __$FlavorTagCopyWithImpl;
@override @useResult
$Res call({
 String id, String slug, String dimension, I18nText name
});


@override $I18nTextCopyWith<$Res> get name;

}
/// @nodoc
class __$FlavorTagCopyWithImpl<$Res>
    implements _$FlavorTagCopyWith<$Res> {
  __$FlavorTagCopyWithImpl(this._self, this._then);

  final _FlavorTag _self;
  final $Res Function(_FlavorTag) _then;

/// Create a copy of FlavorTag
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? slug = null,Object? dimension = null,Object? name = null,}) {
  return _then(_FlavorTag(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,dimension: null == dimension ? _self.dimension : dimension // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as I18nText,
  ));
}

/// Create a copy of FlavorTag
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res> get name {
  
  return $I18nTextCopyWith<$Res>(_self.name, (value) {
    return _then(_self.copyWith(name: value));
  });
}
}

// dart format on
