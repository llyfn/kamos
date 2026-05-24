// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'prefecture.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Prefecture {

 String get id; String get slug; I18nText get name; int get sortOrder; Region get region;
/// Create a copy of Prefecture
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PrefectureCopyWith<Prefecture> get copyWith => _$PrefectureCopyWithImpl<Prefecture>(this as Prefecture, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Prefecture&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.region, region) || other.region == region));
}


@override
int get hashCode => Object.hash(runtimeType,id,slug,name,sortOrder,region);

@override
String toString() {
  return 'Prefecture(id: $id, slug: $slug, name: $name, sortOrder: $sortOrder, region: $region)';
}


}

/// @nodoc
abstract mixin class $PrefectureCopyWith<$Res>  {
  factory $PrefectureCopyWith(Prefecture value, $Res Function(Prefecture) _then) = _$PrefectureCopyWithImpl;
@useResult
$Res call({
 String id, String slug, I18nText name, int sortOrder, Region region
});


$I18nTextCopyWith<$Res> get name;$RegionCopyWith<$Res> get region;

}
/// @nodoc
class _$PrefectureCopyWithImpl<$Res>
    implements $PrefectureCopyWith<$Res> {
  _$PrefectureCopyWithImpl(this._self, this._then);

  final Prefecture _self;
  final $Res Function(Prefecture) _then;

/// Create a copy of Prefecture
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? slug = null,Object? name = null,Object? sortOrder = null,Object? region = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as I18nText,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,region: null == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as Region,
  ));
}
/// Create a copy of Prefecture
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res> get name {
  
  return $I18nTextCopyWith<$Res>(_self.name, (value) {
    return _then(_self.copyWith(name: value));
  });
}/// Create a copy of Prefecture
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RegionCopyWith<$Res> get region {
  
  return $RegionCopyWith<$Res>(_self.region, (value) {
    return _then(_self.copyWith(region: value));
  });
}
}


/// Adds pattern-matching-related methods to [Prefecture].
extension PrefecturePatterns on Prefecture {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Prefecture value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Prefecture() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Prefecture value)  $default,){
final _that = this;
switch (_that) {
case _Prefecture():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Prefecture value)?  $default,){
final _that = this;
switch (_that) {
case _Prefecture() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String slug,  I18nText name,  int sortOrder,  Region region)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Prefecture() when $default != null:
return $default(_that.id,_that.slug,_that.name,_that.sortOrder,_that.region);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String slug,  I18nText name,  int sortOrder,  Region region)  $default,) {final _that = this;
switch (_that) {
case _Prefecture():
return $default(_that.id,_that.slug,_that.name,_that.sortOrder,_that.region);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String slug,  I18nText name,  int sortOrder,  Region region)?  $default,) {final _that = this;
switch (_that) {
case _Prefecture() when $default != null:
return $default(_that.id,_that.slug,_that.name,_that.sortOrder,_that.region);case _:
  return null;

}
}

}

/// @nodoc


class _Prefecture implements Prefecture {
  const _Prefecture({required this.id, required this.slug, required this.name, this.sortOrder = 0, required this.region});
  

@override final  String id;
@override final  String slug;
@override final  I18nText name;
@override@JsonKey() final  int sortOrder;
@override final  Region region;

/// Create a copy of Prefecture
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PrefectureCopyWith<_Prefecture> get copyWith => __$PrefectureCopyWithImpl<_Prefecture>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Prefecture&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.region, region) || other.region == region));
}


@override
int get hashCode => Object.hash(runtimeType,id,slug,name,sortOrder,region);

@override
String toString() {
  return 'Prefecture(id: $id, slug: $slug, name: $name, sortOrder: $sortOrder, region: $region)';
}


}

/// @nodoc
abstract mixin class _$PrefectureCopyWith<$Res> implements $PrefectureCopyWith<$Res> {
  factory _$PrefectureCopyWith(_Prefecture value, $Res Function(_Prefecture) _then) = __$PrefectureCopyWithImpl;
@override @useResult
$Res call({
 String id, String slug, I18nText name, int sortOrder, Region region
});


@override $I18nTextCopyWith<$Res> get name;@override $RegionCopyWith<$Res> get region;

}
/// @nodoc
class __$PrefectureCopyWithImpl<$Res>
    implements _$PrefectureCopyWith<$Res> {
  __$PrefectureCopyWithImpl(this._self, this._then);

  final _Prefecture _self;
  final $Res Function(_Prefecture) _then;

/// Create a copy of Prefecture
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? slug = null,Object? name = null,Object? sortOrder = null,Object? region = null,}) {
  return _then(_Prefecture(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as I18nText,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,region: null == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as Region,
  ));
}

/// Create a copy of Prefecture
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res> get name {
  
  return $I18nTextCopyWith<$Res>(_self.name, (value) {
    return _then(_self.copyWith(name: value));
  });
}/// Create a copy of Prefecture
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RegionCopyWith<$Res> get region {
  
  return $RegionCopyWith<$Res>(_self.region, (value) {
    return _then(_self.copyWith(region: value));
  });
}
}

// dart format on
