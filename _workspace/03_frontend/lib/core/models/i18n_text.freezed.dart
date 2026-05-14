// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'i18n_text.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$I18nText {
  String get en => throw _privateConstructorUsedError;
  String? get ja => throw _privateConstructorUsedError;
  String? get ko => throw _privateConstructorUsedError;

  /// Create a copy of I18nText
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $I18nTextCopyWith<I18nText> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $I18nTextCopyWith<$Res> {
  factory $I18nTextCopyWith(I18nText value, $Res Function(I18nText) then) =
      _$I18nTextCopyWithImpl<$Res, I18nText>;
  @useResult
  $Res call({String en, String? ja, String? ko});
}

/// @nodoc
class _$I18nTextCopyWithImpl<$Res, $Val extends I18nText>
    implements $I18nTextCopyWith<$Res> {
  _$I18nTextCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of I18nText
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? en = null,
    Object? ja = freezed,
    Object? ko = freezed,
  }) {
    return _then(_value.copyWith(
      en: null == en
          ? _value.en
          : en // ignore: cast_nullable_to_non_nullable
              as String,
      ja: freezed == ja
          ? _value.ja
          : ja // ignore: cast_nullable_to_non_nullable
              as String?,
      ko: freezed == ko
          ? _value.ko
          : ko // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$I18nTextImplCopyWith<$Res>
    implements $I18nTextCopyWith<$Res> {
  factory _$$I18nTextImplCopyWith(
          _$I18nTextImpl value, $Res Function(_$I18nTextImpl) then) =
      __$$I18nTextImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String en, String? ja, String? ko});
}

/// @nodoc
class __$$I18nTextImplCopyWithImpl<$Res>
    extends _$I18nTextCopyWithImpl<$Res, _$I18nTextImpl>
    implements _$$I18nTextImplCopyWith<$Res> {
  __$$I18nTextImplCopyWithImpl(
      _$I18nTextImpl _value, $Res Function(_$I18nTextImpl) _then)
      : super(_value, _then);

  /// Create a copy of I18nText
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? en = null,
    Object? ja = freezed,
    Object? ko = freezed,
  }) {
    return _then(_$I18nTextImpl(
      en: null == en
          ? _value.en
          : en // ignore: cast_nullable_to_non_nullable
              as String,
      ja: freezed == ja
          ? _value.ja
          : ja // ignore: cast_nullable_to_non_nullable
              as String?,
      ko: freezed == ko
          ? _value.ko
          : ko // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$I18nTextImpl implements _I18nText {
  const _$I18nTextImpl({required this.en, this.ja, this.ko});

  @override
  final String en;
  @override
  final String? ja;
  @override
  final String? ko;

  @override
  String toString() {
    return 'I18nText(en: $en, ja: $ja, ko: $ko)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$I18nTextImpl &&
            (identical(other.en, en) || other.en == en) &&
            (identical(other.ja, ja) || other.ja == ja) &&
            (identical(other.ko, ko) || other.ko == ko));
  }

  @override
  int get hashCode => Object.hash(runtimeType, en, ja, ko);

  /// Create a copy of I18nText
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$I18nTextImplCopyWith<_$I18nTextImpl> get copyWith =>
      __$$I18nTextImplCopyWithImpl<_$I18nTextImpl>(this, _$identity);
}

abstract class _I18nText implements I18nText {
  const factory _I18nText(
      {required final String en,
      final String? ja,
      final String? ko}) = _$I18nTextImpl;

  @override
  String get en;
  @override
  String? get ja;
  @override
  String? get ko;

  /// Create a copy of I18nText
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$I18nTextImplCopyWith<_$I18nTextImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
