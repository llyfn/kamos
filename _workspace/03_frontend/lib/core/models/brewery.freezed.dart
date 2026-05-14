// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'brewery.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$Brewery {
  String get id => throw _privateConstructorUsedError;
  I18nText get name => throw _privateConstructorUsedError;
  String? get prefecture => throw _privateConstructorUsedError;
  String? get region => throw _privateConstructorUsedError;
  int? get foundedYear => throw _privateConstructorUsedError;
  String? get website => throw _privateConstructorUsedError;
  I18nText? get description => throw _privateConstructorUsedError;
  String get createdAt => throw _privateConstructorUsedError;

  /// Create a copy of Brewery
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BreweryCopyWith<Brewery> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BreweryCopyWith<$Res> {
  factory $BreweryCopyWith(Brewery value, $Res Function(Brewery) then) =
      _$BreweryCopyWithImpl<$Res, Brewery>;
  @useResult
  $Res call(
      {String id,
      I18nText name,
      String? prefecture,
      String? region,
      int? foundedYear,
      String? website,
      I18nText? description,
      String createdAt});

  $I18nTextCopyWith<$Res> get name;
  $I18nTextCopyWith<$Res>? get description;
}

/// @nodoc
class _$BreweryCopyWithImpl<$Res, $Val extends Brewery>
    implements $BreweryCopyWith<$Res> {
  _$BreweryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Brewery
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? prefecture = freezed,
    Object? region = freezed,
    Object? foundedYear = freezed,
    Object? website = freezed,
    Object? description = freezed,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as I18nText,
      prefecture: freezed == prefecture
          ? _value.prefecture
          : prefecture // ignore: cast_nullable_to_non_nullable
              as String?,
      region: freezed == region
          ? _value.region
          : region // ignore: cast_nullable_to_non_nullable
              as String?,
      foundedYear: freezed == foundedYear
          ? _value.foundedYear
          : foundedYear // ignore: cast_nullable_to_non_nullable
              as int?,
      website: freezed == website
          ? _value.website
          : website // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as I18nText?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }

  /// Create a copy of Brewery
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $I18nTextCopyWith<$Res> get name {
    return $I18nTextCopyWith<$Res>(_value.name, (value) {
      return _then(_value.copyWith(name: value) as $Val);
    });
  }

  /// Create a copy of Brewery
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $I18nTextCopyWith<$Res>? get description {
    if (_value.description == null) {
      return null;
    }

    return $I18nTextCopyWith<$Res>(_value.description!, (value) {
      return _then(_value.copyWith(description: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$BreweryImplCopyWith<$Res> implements $BreweryCopyWith<$Res> {
  factory _$$BreweryImplCopyWith(
          _$BreweryImpl value, $Res Function(_$BreweryImpl) then) =
      __$$BreweryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      I18nText name,
      String? prefecture,
      String? region,
      int? foundedYear,
      String? website,
      I18nText? description,
      String createdAt});

  @override
  $I18nTextCopyWith<$Res> get name;
  @override
  $I18nTextCopyWith<$Res>? get description;
}

/// @nodoc
class __$$BreweryImplCopyWithImpl<$Res>
    extends _$BreweryCopyWithImpl<$Res, _$BreweryImpl>
    implements _$$BreweryImplCopyWith<$Res> {
  __$$BreweryImplCopyWithImpl(
      _$BreweryImpl _value, $Res Function(_$BreweryImpl) _then)
      : super(_value, _then);

  /// Create a copy of Brewery
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? prefecture = freezed,
    Object? region = freezed,
    Object? foundedYear = freezed,
    Object? website = freezed,
    Object? description = freezed,
    Object? createdAt = null,
  }) {
    return _then(_$BreweryImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as I18nText,
      prefecture: freezed == prefecture
          ? _value.prefecture
          : prefecture // ignore: cast_nullable_to_non_nullable
              as String?,
      region: freezed == region
          ? _value.region
          : region // ignore: cast_nullable_to_non_nullable
              as String?,
      foundedYear: freezed == foundedYear
          ? _value.foundedYear
          : foundedYear // ignore: cast_nullable_to_non_nullable
              as int?,
      website: freezed == website
          ? _value.website
          : website // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as I18nText?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$BreweryImpl implements _Brewery {
  const _$BreweryImpl(
      {required this.id,
      required this.name,
      this.prefecture,
      this.region,
      this.foundedYear,
      this.website,
      this.description,
      this.createdAt = ''});

  @override
  final String id;
  @override
  final I18nText name;
  @override
  final String? prefecture;
  @override
  final String? region;
  @override
  final int? foundedYear;
  @override
  final String? website;
  @override
  final I18nText? description;
  @override
  @JsonKey()
  final String createdAt;

  @override
  String toString() {
    return 'Brewery(id: $id, name: $name, prefecture: $prefecture, region: $region, foundedYear: $foundedYear, website: $website, description: $description, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BreweryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.prefecture, prefecture) ||
                other.prefecture == prefecture) &&
            (identical(other.region, region) || other.region == region) &&
            (identical(other.foundedYear, foundedYear) ||
                other.foundedYear == foundedYear) &&
            (identical(other.website, website) || other.website == website) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, name, prefecture, region,
      foundedYear, website, description, createdAt);

  /// Create a copy of Brewery
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BreweryImplCopyWith<_$BreweryImpl> get copyWith =>
      __$$BreweryImplCopyWithImpl<_$BreweryImpl>(this, _$identity);
}

abstract class _Brewery implements Brewery {
  const factory _Brewery(
      {required final String id,
      required final I18nText name,
      final String? prefecture,
      final String? region,
      final int? foundedYear,
      final String? website,
      final I18nText? description,
      final String createdAt}) = _$BreweryImpl;

  @override
  String get id;
  @override
  I18nText get name;
  @override
  String? get prefecture;
  @override
  String? get region;
  @override
  int? get foundedYear;
  @override
  String? get website;
  @override
  I18nText? get description;
  @override
  String get createdAt;

  /// Create a copy of Brewery
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BreweryImplCopyWith<_$BreweryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$BreweryRef {
  String get id => throw _privateConstructorUsedError;
  I18nText get name => throw _privateConstructorUsedError;
  String? get region => throw _privateConstructorUsedError;

  /// Create a copy of BreweryRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BreweryRefCopyWith<BreweryRef> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BreweryRefCopyWith<$Res> {
  factory $BreweryRefCopyWith(
          BreweryRef value, $Res Function(BreweryRef) then) =
      _$BreweryRefCopyWithImpl<$Res, BreweryRef>;
  @useResult
  $Res call({String id, I18nText name, String? region});

  $I18nTextCopyWith<$Res> get name;
}

/// @nodoc
class _$BreweryRefCopyWithImpl<$Res, $Val extends BreweryRef>
    implements $BreweryRefCopyWith<$Res> {
  _$BreweryRefCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BreweryRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? region = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as I18nText,
      region: freezed == region
          ? _value.region
          : region // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  /// Create a copy of BreweryRef
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
abstract class _$$BreweryRefImplCopyWith<$Res>
    implements $BreweryRefCopyWith<$Res> {
  factory _$$BreweryRefImplCopyWith(
          _$BreweryRefImpl value, $Res Function(_$BreweryRefImpl) then) =
      __$$BreweryRefImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, I18nText name, String? region});

  @override
  $I18nTextCopyWith<$Res> get name;
}

/// @nodoc
class __$$BreweryRefImplCopyWithImpl<$Res>
    extends _$BreweryRefCopyWithImpl<$Res, _$BreweryRefImpl>
    implements _$$BreweryRefImplCopyWith<$Res> {
  __$$BreweryRefImplCopyWithImpl(
      _$BreweryRefImpl _value, $Res Function(_$BreweryRefImpl) _then)
      : super(_value, _then);

  /// Create a copy of BreweryRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? region = freezed,
  }) {
    return _then(_$BreweryRefImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as I18nText,
      region: freezed == region
          ? _value.region
          : region // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$BreweryRefImpl implements _BreweryRef {
  const _$BreweryRefImpl({required this.id, required this.name, this.region});

  @override
  final String id;
  @override
  final I18nText name;
  @override
  final String? region;

  @override
  String toString() {
    return 'BreweryRef(id: $id, name: $name, region: $region)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BreweryRefImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.region, region) || other.region == region));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, name, region);

  /// Create a copy of BreweryRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BreweryRefImplCopyWith<_$BreweryRefImpl> get copyWith =>
      __$$BreweryRefImplCopyWithImpl<_$BreweryRefImpl>(this, _$identity);
}

abstract class _BreweryRef implements BreweryRef {
  const factory _BreweryRef(
      {required final String id,
      required final I18nText name,
      final String? region}) = _$BreweryRefImpl;

  @override
  String get id;
  @override
  I18nText get name;
  @override
  String? get region;

  /// Create a copy of BreweryRef
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BreweryRefImplCopyWith<_$BreweryRefImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
