// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'flavor_tag.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$FlavorTag {
  String get id => throw _privateConstructorUsedError;
  String get slug => throw _privateConstructorUsedError;
  String get dimension => throw _privateConstructorUsedError;
  I18nText get name => throw _privateConstructorUsedError;

  /// Create a copy of FlavorTag
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FlavorTagCopyWith<FlavorTag> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FlavorTagCopyWith<$Res> {
  factory $FlavorTagCopyWith(FlavorTag value, $Res Function(FlavorTag) then) =
      _$FlavorTagCopyWithImpl<$Res, FlavorTag>;
  @useResult
  $Res call({String id, String slug, String dimension, I18nText name});

  $I18nTextCopyWith<$Res> get name;
}

/// @nodoc
class _$FlavorTagCopyWithImpl<$Res, $Val extends FlavorTag>
    implements $FlavorTagCopyWith<$Res> {
  _$FlavorTagCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FlavorTag
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? slug = null,
    Object? dimension = null,
    Object? name = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      slug: null == slug
          ? _value.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String,
      dimension: null == dimension
          ? _value.dimension
          : dimension // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as I18nText,
    ) as $Val);
  }

  /// Create a copy of FlavorTag
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $I18nTextCopyWith<$Res> get name {
    return $I18nTextCopyWith<$Res>(_value.name, (value) {
      return _then(_value.copyWith(name: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$FlavorTagImplCopyWith<$Res>
    implements $FlavorTagCopyWith<$Res> {
  factory _$$FlavorTagImplCopyWith(
          _$FlavorTagImpl value, $Res Function(_$FlavorTagImpl) then) =
      __$$FlavorTagImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String slug, String dimension, I18nText name});

  @override
  $I18nTextCopyWith<$Res> get name;
}

/// @nodoc
class __$$FlavorTagImplCopyWithImpl<$Res>
    extends _$FlavorTagCopyWithImpl<$Res, _$FlavorTagImpl>
    implements _$$FlavorTagImplCopyWith<$Res> {
  __$$FlavorTagImplCopyWithImpl(
      _$FlavorTagImpl _value, $Res Function(_$FlavorTagImpl) _then)
      : super(_value, _then);

  /// Create a copy of FlavorTag
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? slug = null,
    Object? dimension = null,
    Object? name = null,
  }) {
    return _then(_$FlavorTagImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      slug: null == slug
          ? _value.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String,
      dimension: null == dimension
          ? _value.dimension
          : dimension // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as I18nText,
    ));
  }
}

/// @nodoc

class _$FlavorTagImpl implements _FlavorTag {
  const _$FlavorTagImpl(
      {required this.id,
      required this.slug,
      required this.dimension,
      required this.name});

  @override
  final String id;
  @override
  final String slug;
  @override
  final String dimension;
  @override
  final I18nText name;

  @override
  String toString() {
    return 'FlavorTag(id: $id, slug: $slug, dimension: $dimension, name: $name)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlavorTagImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.dimension, dimension) ||
                other.dimension == dimension) &&
            (identical(other.name, name) || other.name == name));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, slug, dimension, name);

  /// Create a copy of FlavorTag
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FlavorTagImplCopyWith<_$FlavorTagImpl> get copyWith =>
      __$$FlavorTagImplCopyWithImpl<_$FlavorTagImpl>(this, _$identity);
}

abstract class _FlavorTag implements FlavorTag {
  const factory _FlavorTag(
      {required final String id,
      required final String slug,
      required final String dimension,
      required final I18nText name}) = _$FlavorTagImpl;

  @override
  String get id;
  @override
  String get slug;
  @override
  String get dimension;
  @override
  I18nText get name;

  /// Create a copy of FlavorTag
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FlavorTagImplCopyWith<_$FlavorTagImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
