// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'i18n_text.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$I18nText {

 String get en; String? get ja; String? get ko;
/// Create a copy of I18nText
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$I18nTextCopyWith<I18nText> get copyWith => _$I18nTextCopyWithImpl<I18nText>(this as I18nText, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is I18nText&&(identical(other.en, en) || other.en == en)&&(identical(other.ja, ja) || other.ja == ja)&&(identical(other.ko, ko) || other.ko == ko));
}


@override
int get hashCode => Object.hash(runtimeType,en,ja,ko);

@override
String toString() {
  return 'I18nText(en: $en, ja: $ja, ko: $ko)';
}


}

/// @nodoc
abstract mixin class $I18nTextCopyWith<$Res>  {
  factory $I18nTextCopyWith(I18nText value, $Res Function(I18nText) _then) = _$I18nTextCopyWithImpl;
@useResult
$Res call({
 String en, String? ja, String? ko
});




}
/// @nodoc
class _$I18nTextCopyWithImpl<$Res>
    implements $I18nTextCopyWith<$Res> {
  _$I18nTextCopyWithImpl(this._self, this._then);

  final I18nText _self;
  final $Res Function(I18nText) _then;

/// Create a copy of I18nText
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? en = null,Object? ja = freezed,Object? ko = freezed,}) {
  return _then(_self.copyWith(
en: null == en ? _self.en : en // ignore: cast_nullable_to_non_nullable
as String,ja: freezed == ja ? _self.ja : ja // ignore: cast_nullable_to_non_nullable
as String?,ko: freezed == ko ? _self.ko : ko // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [I18nText].
extension I18nTextPatterns on I18nText {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _I18nText value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _I18nText() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _I18nText value)  $default,){
final _that = this;
switch (_that) {
case _I18nText():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _I18nText value)?  $default,){
final _that = this;
switch (_that) {
case _I18nText() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String en,  String? ja,  String? ko)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _I18nText() when $default != null:
return $default(_that.en,_that.ja,_that.ko);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String en,  String? ja,  String? ko)  $default,) {final _that = this;
switch (_that) {
case _I18nText():
return $default(_that.en,_that.ja,_that.ko);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String en,  String? ja,  String? ko)?  $default,) {final _that = this;
switch (_that) {
case _I18nText() when $default != null:
return $default(_that.en,_that.ja,_that.ko);case _:
  return null;

}
}

}

/// @nodoc


class _I18nText implements I18nText {
  const _I18nText({required this.en, this.ja, this.ko});
  

@override final  String en;
@override final  String? ja;
@override final  String? ko;

/// Create a copy of I18nText
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$I18nTextCopyWith<_I18nText> get copyWith => __$I18nTextCopyWithImpl<_I18nText>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _I18nText&&(identical(other.en, en) || other.en == en)&&(identical(other.ja, ja) || other.ja == ja)&&(identical(other.ko, ko) || other.ko == ko));
}


@override
int get hashCode => Object.hash(runtimeType,en,ja,ko);

@override
String toString() {
  return 'I18nText(en: $en, ja: $ja, ko: $ko)';
}


}

/// @nodoc
abstract mixin class _$I18nTextCopyWith<$Res> implements $I18nTextCopyWith<$Res> {
  factory _$I18nTextCopyWith(_I18nText value, $Res Function(_I18nText) _then) = __$I18nTextCopyWithImpl;
@override @useResult
$Res call({
 String en, String? ja, String? ko
});




}
/// @nodoc
class __$I18nTextCopyWithImpl<$Res>
    implements _$I18nTextCopyWith<$Res> {
  __$I18nTextCopyWithImpl(this._self, this._then);

  final _I18nText _self;
  final $Res Function(_I18nText) _then;

/// Create a copy of I18nText
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? en = null,Object? ja = freezed,Object? ko = freezed,}) {
  return _then(_I18nText(
en: null == en ? _self.en : en // ignore: cast_nullable_to_non_nullable
as String,ja: freezed == ja ? _self.ja : ja // ignore: cast_nullable_to_non_nullable
as String?,ko: freezed == ko ? _self.ko : ko // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
