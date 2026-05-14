// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'category_label.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$CategoryLabel {
  String get slug => throw _privateConstructorUsedError;
  I18nText get labelI18n => throw _privateConstructorUsedError;

  /// Create a copy of CategoryLabel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CategoryLabelCopyWith<CategoryLabel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CategoryLabelCopyWith<$Res> {
  factory $CategoryLabelCopyWith(
          CategoryLabel value, $Res Function(CategoryLabel) then) =
      _$CategoryLabelCopyWithImpl<$Res, CategoryLabel>;
  @useResult
  $Res call({String slug, I18nText labelI18n});

  $I18nTextCopyWith<$Res> get labelI18n;
}

/// @nodoc
class _$CategoryLabelCopyWithImpl<$Res, $Val extends CategoryLabel>
    implements $CategoryLabelCopyWith<$Res> {
  _$CategoryLabelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CategoryLabel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? slug = null,
    Object? labelI18n = null,
  }) {
    return _then(_value.copyWith(
      slug: null == slug
          ? _value.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String,
      labelI18n: null == labelI18n
          ? _value.labelI18n
          : labelI18n // ignore: cast_nullable_to_non_nullable
              as I18nText,
    ) as $Val);
  }

  /// Create a copy of CategoryLabel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $I18nTextCopyWith<$Res> get labelI18n {
    return $I18nTextCopyWith<$Res>(_value.labelI18n, (value) {
      return _then(_value.copyWith(labelI18n: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$CategoryLabelImplCopyWith<$Res>
    implements $CategoryLabelCopyWith<$Res> {
  factory _$$CategoryLabelImplCopyWith(
          _$CategoryLabelImpl value, $Res Function(_$CategoryLabelImpl) then) =
      __$$CategoryLabelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String slug, I18nText labelI18n});

  @override
  $I18nTextCopyWith<$Res> get labelI18n;
}

/// @nodoc
class __$$CategoryLabelImplCopyWithImpl<$Res>
    extends _$CategoryLabelCopyWithImpl<$Res, _$CategoryLabelImpl>
    implements _$$CategoryLabelImplCopyWith<$Res> {
  __$$CategoryLabelImplCopyWithImpl(
      _$CategoryLabelImpl _value, $Res Function(_$CategoryLabelImpl) _then)
      : super(_value, _then);

  /// Create a copy of CategoryLabel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? slug = null,
    Object? labelI18n = null,
  }) {
    return _then(_$CategoryLabelImpl(
      slug: null == slug
          ? _value.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String,
      labelI18n: null == labelI18n
          ? _value.labelI18n
          : labelI18n // ignore: cast_nullable_to_non_nullable
              as I18nText,
    ));
  }
}

/// @nodoc

class _$CategoryLabelImpl implements _CategoryLabel {
  const _$CategoryLabelImpl({required this.slug, required this.labelI18n});

  @override
  final String slug;
  @override
  final I18nText labelI18n;

  @override
  String toString() {
    return 'CategoryLabel(slug: $slug, labelI18n: $labelI18n)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CategoryLabelImpl &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.labelI18n, labelI18n) ||
                other.labelI18n == labelI18n));
  }

  @override
  int get hashCode => Object.hash(runtimeType, slug, labelI18n);

  /// Create a copy of CategoryLabel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CategoryLabelImplCopyWith<_$CategoryLabelImpl> get copyWith =>
      __$$CategoryLabelImplCopyWithImpl<_$CategoryLabelImpl>(this, _$identity);
}

abstract class _CategoryLabel implements CategoryLabel {
  const factory _CategoryLabel(
      {required final String slug,
      required final I18nText labelI18n}) = _$CategoryLabelImpl;

  @override
  String get slug;
  @override
  I18nText get labelI18n;

  /// Create a copy of CategoryLabel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CategoryLabelImplCopyWith<_$CategoryLabelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
