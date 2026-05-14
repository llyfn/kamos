// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'category_label.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CategoryLabel {

 String get slug; I18nText get labelI18n;
/// Create a copy of CategoryLabel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CategoryLabelCopyWith<CategoryLabel> get copyWith => _$CategoryLabelCopyWithImpl<CategoryLabel>(this as CategoryLabel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CategoryLabel&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.labelI18n, labelI18n) || other.labelI18n == labelI18n));
}


@override
int get hashCode => Object.hash(runtimeType,slug,labelI18n);

@override
String toString() {
  return 'CategoryLabel(slug: $slug, labelI18n: $labelI18n)';
}


}

/// @nodoc
abstract mixin class $CategoryLabelCopyWith<$Res>  {
  factory $CategoryLabelCopyWith(CategoryLabel value, $Res Function(CategoryLabel) _then) = _$CategoryLabelCopyWithImpl;
@useResult
$Res call({
 String slug, I18nText labelI18n
});


$I18nTextCopyWith<$Res> get labelI18n;

}
/// @nodoc
class _$CategoryLabelCopyWithImpl<$Res>
    implements $CategoryLabelCopyWith<$Res> {
  _$CategoryLabelCopyWithImpl(this._self, this._then);

  final CategoryLabel _self;
  final $Res Function(CategoryLabel) _then;

/// Create a copy of CategoryLabel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? slug = null,Object? labelI18n = null,}) {
  return _then(_self.copyWith(
slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,labelI18n: null == labelI18n ? _self.labelI18n : labelI18n // ignore: cast_nullable_to_non_nullable
as I18nText,
  ));
}
/// Create a copy of CategoryLabel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res> get labelI18n {
  
  return $I18nTextCopyWith<$Res>(_self.labelI18n, (value) {
    return _then(_self.copyWith(labelI18n: value));
  });
}
}


/// Adds pattern-matching-related methods to [CategoryLabel].
extension CategoryLabelPatterns on CategoryLabel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CategoryLabel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CategoryLabel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CategoryLabel value)  $default,){
final _that = this;
switch (_that) {
case _CategoryLabel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CategoryLabel value)?  $default,){
final _that = this;
switch (_that) {
case _CategoryLabel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String slug,  I18nText labelI18n)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CategoryLabel() when $default != null:
return $default(_that.slug,_that.labelI18n);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String slug,  I18nText labelI18n)  $default,) {final _that = this;
switch (_that) {
case _CategoryLabel():
return $default(_that.slug,_that.labelI18n);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String slug,  I18nText labelI18n)?  $default,) {final _that = this;
switch (_that) {
case _CategoryLabel() when $default != null:
return $default(_that.slug,_that.labelI18n);case _:
  return null;

}
}

}

/// @nodoc


class _CategoryLabel implements CategoryLabel {
  const _CategoryLabel({required this.slug, required this.labelI18n});
  

@override final  String slug;
@override final  I18nText labelI18n;

/// Create a copy of CategoryLabel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CategoryLabelCopyWith<_CategoryLabel> get copyWith => __$CategoryLabelCopyWithImpl<_CategoryLabel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CategoryLabel&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.labelI18n, labelI18n) || other.labelI18n == labelI18n));
}


@override
int get hashCode => Object.hash(runtimeType,slug,labelI18n);

@override
String toString() {
  return 'CategoryLabel(slug: $slug, labelI18n: $labelI18n)';
}


}

/// @nodoc
abstract mixin class _$CategoryLabelCopyWith<$Res> implements $CategoryLabelCopyWith<$Res> {
  factory _$CategoryLabelCopyWith(_CategoryLabel value, $Res Function(_CategoryLabel) _then) = __$CategoryLabelCopyWithImpl;
@override @useResult
$Res call({
 String slug, I18nText labelI18n
});


@override $I18nTextCopyWith<$Res> get labelI18n;

}
/// @nodoc
class __$CategoryLabelCopyWithImpl<$Res>
    implements _$CategoryLabelCopyWith<$Res> {
  __$CategoryLabelCopyWithImpl(this._self, this._then);

  final _CategoryLabel _self;
  final $Res Function(_CategoryLabel) _then;

/// Create a copy of CategoryLabel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? slug = null,Object? labelI18n = null,}) {
  return _then(_CategoryLabel(
slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,labelI18n: null == labelI18n ? _self.labelI18n : labelI18n // ignore: cast_nullable_to_non_nullable
as I18nText,
  ));
}

/// Create a copy of CategoryLabel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res> get labelI18n {
  
  return $I18nTextCopyWith<$Res>(_self.labelI18n, (value) {
    return _then(_self.copyWith(labelI18n: value));
  });
}
}

// dart format on
