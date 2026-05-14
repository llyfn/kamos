// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'beverage.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$Beverage {
  String get id => throw _privateConstructorUsedError;
  I18nText get name => throw _privateConstructorUsedError;
  Brewery get brewery => throw _privateConstructorUsedError;
  CategoryLabel get category => throw _privateConstructorUsedError;
  I18nText? get subcategory => throw _privateConstructorUsedError;
  double? get abv => throw _privateConstructorUsedError;
  int? get polishingRatio => throw _privateConstructorUsedError;
  String? get prefecture => throw _privateConstructorUsedError;
  String? get region => throw _privateConstructorUsedError;
  List<String> get flavorProfile => throw _privateConstructorUsedError;
  I18nText? get description => throw _privateConstructorUsedError;
  String? get labelImageUrl => throw _privateConstructorUsedError;
  double? get avgRating => throw _privateConstructorUsedError;
  int get checkInCount => throw _privateConstructorUsedError;
  String get createdAt => throw _privateConstructorUsedError;

  /// Create a copy of Beverage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BeverageCopyWith<Beverage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BeverageCopyWith<$Res> {
  factory $BeverageCopyWith(Beverage value, $Res Function(Beverage) then) =
      _$BeverageCopyWithImpl<$Res, Beverage>;
  @useResult
  $Res call(
      {String id,
      I18nText name,
      Brewery brewery,
      CategoryLabel category,
      I18nText? subcategory,
      double? abv,
      int? polishingRatio,
      String? prefecture,
      String? region,
      List<String> flavorProfile,
      I18nText? description,
      String? labelImageUrl,
      double? avgRating,
      int checkInCount,
      String createdAt});

  $I18nTextCopyWith<$Res> get name;
  $BreweryCopyWith<$Res> get brewery;
  $CategoryLabelCopyWith<$Res> get category;
  $I18nTextCopyWith<$Res>? get subcategory;
  $I18nTextCopyWith<$Res>? get description;
}

/// @nodoc
class _$BeverageCopyWithImpl<$Res, $Val extends Beverage>
    implements $BeverageCopyWith<$Res> {
  _$BeverageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Beverage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? brewery = null,
    Object? category = null,
    Object? subcategory = freezed,
    Object? abv = freezed,
    Object? polishingRatio = freezed,
    Object? prefecture = freezed,
    Object? region = freezed,
    Object? flavorProfile = null,
    Object? description = freezed,
    Object? labelImageUrl = freezed,
    Object? avgRating = freezed,
    Object? checkInCount = null,
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
      brewery: null == brewery
          ? _value.brewery
          : brewery // ignore: cast_nullable_to_non_nullable
              as Brewery,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as CategoryLabel,
      subcategory: freezed == subcategory
          ? _value.subcategory
          : subcategory // ignore: cast_nullable_to_non_nullable
              as I18nText?,
      abv: freezed == abv
          ? _value.abv
          : abv // ignore: cast_nullable_to_non_nullable
              as double?,
      polishingRatio: freezed == polishingRatio
          ? _value.polishingRatio
          : polishingRatio // ignore: cast_nullable_to_non_nullable
              as int?,
      prefecture: freezed == prefecture
          ? _value.prefecture
          : prefecture // ignore: cast_nullable_to_non_nullable
              as String?,
      region: freezed == region
          ? _value.region
          : region // ignore: cast_nullable_to_non_nullable
              as String?,
      flavorProfile: null == flavorProfile
          ? _value.flavorProfile
          : flavorProfile // ignore: cast_nullable_to_non_nullable
              as List<String>,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as I18nText?,
      labelImageUrl: freezed == labelImageUrl
          ? _value.labelImageUrl
          : labelImageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      avgRating: freezed == avgRating
          ? _value.avgRating
          : avgRating // ignore: cast_nullable_to_non_nullable
              as double?,
      checkInCount: null == checkInCount
          ? _value.checkInCount
          : checkInCount // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }

  /// Create a copy of Beverage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $I18nTextCopyWith<$Res> get name {
    return $I18nTextCopyWith<$Res>(_value.name, (value) {
      return _then(_value.copyWith(name: value) as $Val);
    });
  }

  /// Create a copy of Beverage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BreweryCopyWith<$Res> get brewery {
    return $BreweryCopyWith<$Res>(_value.brewery, (value) {
      return _then(_value.copyWith(brewery: value) as $Val);
    });
  }

  /// Create a copy of Beverage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CategoryLabelCopyWith<$Res> get category {
    return $CategoryLabelCopyWith<$Res>(_value.category, (value) {
      return _then(_value.copyWith(category: value) as $Val);
    });
  }

  /// Create a copy of Beverage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $I18nTextCopyWith<$Res>? get subcategory {
    if (_value.subcategory == null) {
      return null;
    }

    return $I18nTextCopyWith<$Res>(_value.subcategory!, (value) {
      return _then(_value.copyWith(subcategory: value) as $Val);
    });
  }

  /// Create a copy of Beverage
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
abstract class _$$BeverageImplCopyWith<$Res>
    implements $BeverageCopyWith<$Res> {
  factory _$$BeverageImplCopyWith(
          _$BeverageImpl value, $Res Function(_$BeverageImpl) then) =
      __$$BeverageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      I18nText name,
      Brewery brewery,
      CategoryLabel category,
      I18nText? subcategory,
      double? abv,
      int? polishingRatio,
      String? prefecture,
      String? region,
      List<String> flavorProfile,
      I18nText? description,
      String? labelImageUrl,
      double? avgRating,
      int checkInCount,
      String createdAt});

  @override
  $I18nTextCopyWith<$Res> get name;
  @override
  $BreweryCopyWith<$Res> get brewery;
  @override
  $CategoryLabelCopyWith<$Res> get category;
  @override
  $I18nTextCopyWith<$Res>? get subcategory;
  @override
  $I18nTextCopyWith<$Res>? get description;
}

/// @nodoc
class __$$BeverageImplCopyWithImpl<$Res>
    extends _$BeverageCopyWithImpl<$Res, _$BeverageImpl>
    implements _$$BeverageImplCopyWith<$Res> {
  __$$BeverageImplCopyWithImpl(
      _$BeverageImpl _value, $Res Function(_$BeverageImpl) _then)
      : super(_value, _then);

  /// Create a copy of Beverage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? brewery = null,
    Object? category = null,
    Object? subcategory = freezed,
    Object? abv = freezed,
    Object? polishingRatio = freezed,
    Object? prefecture = freezed,
    Object? region = freezed,
    Object? flavorProfile = null,
    Object? description = freezed,
    Object? labelImageUrl = freezed,
    Object? avgRating = freezed,
    Object? checkInCount = null,
    Object? createdAt = null,
  }) {
    return _then(_$BeverageImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as I18nText,
      brewery: null == brewery
          ? _value.brewery
          : brewery // ignore: cast_nullable_to_non_nullable
              as Brewery,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as CategoryLabel,
      subcategory: freezed == subcategory
          ? _value.subcategory
          : subcategory // ignore: cast_nullable_to_non_nullable
              as I18nText?,
      abv: freezed == abv
          ? _value.abv
          : abv // ignore: cast_nullable_to_non_nullable
              as double?,
      polishingRatio: freezed == polishingRatio
          ? _value.polishingRatio
          : polishingRatio // ignore: cast_nullable_to_non_nullable
              as int?,
      prefecture: freezed == prefecture
          ? _value.prefecture
          : prefecture // ignore: cast_nullable_to_non_nullable
              as String?,
      region: freezed == region
          ? _value.region
          : region // ignore: cast_nullable_to_non_nullable
              as String?,
      flavorProfile: null == flavorProfile
          ? _value._flavorProfile
          : flavorProfile // ignore: cast_nullable_to_non_nullable
              as List<String>,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as I18nText?,
      labelImageUrl: freezed == labelImageUrl
          ? _value.labelImageUrl
          : labelImageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      avgRating: freezed == avgRating
          ? _value.avgRating
          : avgRating // ignore: cast_nullable_to_non_nullable
              as double?,
      checkInCount: null == checkInCount
          ? _value.checkInCount
          : checkInCount // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$BeverageImpl implements _Beverage {
  const _$BeverageImpl(
      {required this.id,
      required this.name,
      required this.brewery,
      required this.category,
      this.subcategory,
      this.abv,
      this.polishingRatio,
      this.prefecture,
      this.region,
      final List<String> flavorProfile = const <String>[],
      this.description,
      this.labelImageUrl,
      this.avgRating,
      this.checkInCount = 0,
      this.createdAt = ''})
      : _flavorProfile = flavorProfile;

  @override
  final String id;
  @override
  final I18nText name;
  @override
  final Brewery brewery;
  @override
  final CategoryLabel category;
  @override
  final I18nText? subcategory;
  @override
  final double? abv;
  @override
  final int? polishingRatio;
  @override
  final String? prefecture;
  @override
  final String? region;
  final List<String> _flavorProfile;
  @override
  @JsonKey()
  List<String> get flavorProfile {
    if (_flavorProfile is EqualUnmodifiableListView) return _flavorProfile;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_flavorProfile);
  }

  @override
  final I18nText? description;
  @override
  final String? labelImageUrl;
  @override
  final double? avgRating;
  @override
  @JsonKey()
  final int checkInCount;
  @override
  @JsonKey()
  final String createdAt;

  @override
  String toString() {
    return 'Beverage(id: $id, name: $name, brewery: $brewery, category: $category, subcategory: $subcategory, abv: $abv, polishingRatio: $polishingRatio, prefecture: $prefecture, region: $region, flavorProfile: $flavorProfile, description: $description, labelImageUrl: $labelImageUrl, avgRating: $avgRating, checkInCount: $checkInCount, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BeverageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.brewery, brewery) || other.brewery == brewery) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.subcategory, subcategory) ||
                other.subcategory == subcategory) &&
            (identical(other.abv, abv) || other.abv == abv) &&
            (identical(other.polishingRatio, polishingRatio) ||
                other.polishingRatio == polishingRatio) &&
            (identical(other.prefecture, prefecture) ||
                other.prefecture == prefecture) &&
            (identical(other.region, region) || other.region == region) &&
            const DeepCollectionEquality()
                .equals(other._flavorProfile, _flavorProfile) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.labelImageUrl, labelImageUrl) ||
                other.labelImageUrl == labelImageUrl) &&
            (identical(other.avgRating, avgRating) ||
                other.avgRating == avgRating) &&
            (identical(other.checkInCount, checkInCount) ||
                other.checkInCount == checkInCount) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      brewery,
      category,
      subcategory,
      abv,
      polishingRatio,
      prefecture,
      region,
      const DeepCollectionEquality().hash(_flavorProfile),
      description,
      labelImageUrl,
      avgRating,
      checkInCount,
      createdAt);

  /// Create a copy of Beverage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BeverageImplCopyWith<_$BeverageImpl> get copyWith =>
      __$$BeverageImplCopyWithImpl<_$BeverageImpl>(this, _$identity);
}

abstract class _Beverage implements Beverage {
  const factory _Beverage(
      {required final String id,
      required final I18nText name,
      required final Brewery brewery,
      required final CategoryLabel category,
      final I18nText? subcategory,
      final double? abv,
      final int? polishingRatio,
      final String? prefecture,
      final String? region,
      final List<String> flavorProfile,
      final I18nText? description,
      final String? labelImageUrl,
      final double? avgRating,
      final int checkInCount,
      final String createdAt}) = _$BeverageImpl;

  @override
  String get id;
  @override
  I18nText get name;
  @override
  Brewery get brewery;
  @override
  CategoryLabel get category;
  @override
  I18nText? get subcategory;
  @override
  double? get abv;
  @override
  int? get polishingRatio;
  @override
  String? get prefecture;
  @override
  String? get region;
  @override
  List<String> get flavorProfile;
  @override
  I18nText? get description;
  @override
  String? get labelImageUrl;
  @override
  double? get avgRating;
  @override
  int get checkInCount;
  @override
  String get createdAt;

  /// Create a copy of Beverage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BeverageImplCopyWith<_$BeverageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$BeverageRef {
  String get id => throw _privateConstructorUsedError;
  I18nText get name => throw _privateConstructorUsedError;
  BreweryRef get brewery => throw _privateConstructorUsedError;
  CategoryLabel get category => throw _privateConstructorUsedError;
  String? get labelImageUrl => throw _privateConstructorUsedError;

  /// Create a copy of BeverageRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BeverageRefCopyWith<BeverageRef> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BeverageRefCopyWith<$Res> {
  factory $BeverageRefCopyWith(
          BeverageRef value, $Res Function(BeverageRef) then) =
      _$BeverageRefCopyWithImpl<$Res, BeverageRef>;
  @useResult
  $Res call(
      {String id,
      I18nText name,
      BreweryRef brewery,
      CategoryLabel category,
      String? labelImageUrl});

  $I18nTextCopyWith<$Res> get name;
  $BreweryRefCopyWith<$Res> get brewery;
  $CategoryLabelCopyWith<$Res> get category;
}

/// @nodoc
class _$BeverageRefCopyWithImpl<$Res, $Val extends BeverageRef>
    implements $BeverageRefCopyWith<$Res> {
  _$BeverageRefCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BeverageRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? brewery = null,
    Object? category = null,
    Object? labelImageUrl = freezed,
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
      brewery: null == brewery
          ? _value.brewery
          : brewery // ignore: cast_nullable_to_non_nullable
              as BreweryRef,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as CategoryLabel,
      labelImageUrl: freezed == labelImageUrl
          ? _value.labelImageUrl
          : labelImageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  /// Create a copy of BeverageRef
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $I18nTextCopyWith<$Res> get name {
    return $I18nTextCopyWith<$Res>(_value.name, (value) {
      return _then(_value.copyWith(name: value) as $Val);
    });
  }

  /// Create a copy of BeverageRef
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BreweryRefCopyWith<$Res> get brewery {
    return $BreweryRefCopyWith<$Res>(_value.brewery, (value) {
      return _then(_value.copyWith(brewery: value) as $Val);
    });
  }

  /// Create a copy of BeverageRef
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CategoryLabelCopyWith<$Res> get category {
    return $CategoryLabelCopyWith<$Res>(_value.category, (value) {
      return _then(_value.copyWith(category: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$BeverageRefImplCopyWith<$Res>
    implements $BeverageRefCopyWith<$Res> {
  factory _$$BeverageRefImplCopyWith(
          _$BeverageRefImpl value, $Res Function(_$BeverageRefImpl) then) =
      __$$BeverageRefImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      I18nText name,
      BreweryRef brewery,
      CategoryLabel category,
      String? labelImageUrl});

  @override
  $I18nTextCopyWith<$Res> get name;
  @override
  $BreweryRefCopyWith<$Res> get brewery;
  @override
  $CategoryLabelCopyWith<$Res> get category;
}

/// @nodoc
class __$$BeverageRefImplCopyWithImpl<$Res>
    extends _$BeverageRefCopyWithImpl<$Res, _$BeverageRefImpl>
    implements _$$BeverageRefImplCopyWith<$Res> {
  __$$BeverageRefImplCopyWithImpl(
      _$BeverageRefImpl _value, $Res Function(_$BeverageRefImpl) _then)
      : super(_value, _then);

  /// Create a copy of BeverageRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? brewery = null,
    Object? category = null,
    Object? labelImageUrl = freezed,
  }) {
    return _then(_$BeverageRefImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as I18nText,
      brewery: null == brewery
          ? _value.brewery
          : brewery // ignore: cast_nullable_to_non_nullable
              as BreweryRef,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as CategoryLabel,
      labelImageUrl: freezed == labelImageUrl
          ? _value.labelImageUrl
          : labelImageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$BeverageRefImpl implements _BeverageRef {
  const _$BeverageRefImpl(
      {required this.id,
      required this.name,
      required this.brewery,
      required this.category,
      this.labelImageUrl});

  @override
  final String id;
  @override
  final I18nText name;
  @override
  final BreweryRef brewery;
  @override
  final CategoryLabel category;
  @override
  final String? labelImageUrl;

  @override
  String toString() {
    return 'BeverageRef(id: $id, name: $name, brewery: $brewery, category: $category, labelImageUrl: $labelImageUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BeverageRefImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.brewery, brewery) || other.brewery == brewery) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.labelImageUrl, labelImageUrl) ||
                other.labelImageUrl == labelImageUrl));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, brewery, category, labelImageUrl);

  /// Create a copy of BeverageRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BeverageRefImplCopyWith<_$BeverageRefImpl> get copyWith =>
      __$$BeverageRefImplCopyWithImpl<_$BeverageRefImpl>(this, _$identity);
}

abstract class _BeverageRef implements BeverageRef {
  const factory _BeverageRef(
      {required final String id,
      required final I18nText name,
      required final BreweryRef brewery,
      required final CategoryLabel category,
      final String? labelImageUrl}) = _$BeverageRefImpl;

  @override
  String get id;
  @override
  I18nText get name;
  @override
  BreweryRef get brewery;
  @override
  CategoryLabel get category;
  @override
  String? get labelImageUrl;

  /// Create a copy of BeverageRef
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BeverageRefImplCopyWith<_$BeverageRefImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$FlavorAggregate {
  String get slug => throw _privateConstructorUsedError;
  String get dimension => throw _privateConstructorUsedError;
  I18nText get name => throw _privateConstructorUsedError;
  int get uses => throw _privateConstructorUsedError;

  /// Create a copy of FlavorAggregate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FlavorAggregateCopyWith<FlavorAggregate> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FlavorAggregateCopyWith<$Res> {
  factory $FlavorAggregateCopyWith(
          FlavorAggregate value, $Res Function(FlavorAggregate) then) =
      _$FlavorAggregateCopyWithImpl<$Res, FlavorAggregate>;
  @useResult
  $Res call({String slug, String dimension, I18nText name, int uses});

  $I18nTextCopyWith<$Res> get name;
}

/// @nodoc
class _$FlavorAggregateCopyWithImpl<$Res, $Val extends FlavorAggregate>
    implements $FlavorAggregateCopyWith<$Res> {
  _$FlavorAggregateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FlavorAggregate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? slug = null,
    Object? dimension = null,
    Object? name = null,
    Object? uses = null,
  }) {
    return _then(_value.copyWith(
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
      uses: null == uses
          ? _value.uses
          : uses // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }

  /// Create a copy of FlavorAggregate
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
abstract class _$$FlavorAggregateImplCopyWith<$Res>
    implements $FlavorAggregateCopyWith<$Res> {
  factory _$$FlavorAggregateImplCopyWith(_$FlavorAggregateImpl value,
          $Res Function(_$FlavorAggregateImpl) then) =
      __$$FlavorAggregateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String slug, String dimension, I18nText name, int uses});

  @override
  $I18nTextCopyWith<$Res> get name;
}

/// @nodoc
class __$$FlavorAggregateImplCopyWithImpl<$Res>
    extends _$FlavorAggregateCopyWithImpl<$Res, _$FlavorAggregateImpl>
    implements _$$FlavorAggregateImplCopyWith<$Res> {
  __$$FlavorAggregateImplCopyWithImpl(
      _$FlavorAggregateImpl _value, $Res Function(_$FlavorAggregateImpl) _then)
      : super(_value, _then);

  /// Create a copy of FlavorAggregate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? slug = null,
    Object? dimension = null,
    Object? name = null,
    Object? uses = null,
  }) {
    return _then(_$FlavorAggregateImpl(
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
      uses: null == uses
          ? _value.uses
          : uses // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$FlavorAggregateImpl implements _FlavorAggregate {
  const _$FlavorAggregateImpl(
      {required this.slug,
      required this.dimension,
      required this.name,
      this.uses = 0});

  @override
  final String slug;
  @override
  final String dimension;
  @override
  final I18nText name;
  @override
  @JsonKey()
  final int uses;

  @override
  String toString() {
    return 'FlavorAggregate(slug: $slug, dimension: $dimension, name: $name, uses: $uses)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlavorAggregateImpl &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.dimension, dimension) ||
                other.dimension == dimension) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.uses, uses) || other.uses == uses));
  }

  @override
  int get hashCode => Object.hash(runtimeType, slug, dimension, name, uses);

  /// Create a copy of FlavorAggregate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FlavorAggregateImplCopyWith<_$FlavorAggregateImpl> get copyWith =>
      __$$FlavorAggregateImplCopyWithImpl<_$FlavorAggregateImpl>(
          this, _$identity);
}

abstract class _FlavorAggregate implements FlavorAggregate {
  const factory _FlavorAggregate(
      {required final String slug,
      required final String dimension,
      required final I18nText name,
      final int uses}) = _$FlavorAggregateImpl;

  @override
  String get slug;
  @override
  String get dimension;
  @override
  I18nText get name;
  @override
  int get uses;

  /// Create a copy of FlavorAggregate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FlavorAggregateImplCopyWith<_$FlavorAggregateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$BeverageDetail {
  Beverage get beverage => throw _privateConstructorUsedError;
  List<FlavorAggregate> get aggregatedFlavor =>
      throw _privateConstructorUsedError;
  List<CheckinSummary> get recentCheckIns => throw _privateConstructorUsedError;

  /// Create a copy of BeverageDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BeverageDetailCopyWith<BeverageDetail> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BeverageDetailCopyWith<$Res> {
  factory $BeverageDetailCopyWith(
          BeverageDetail value, $Res Function(BeverageDetail) then) =
      _$BeverageDetailCopyWithImpl<$Res, BeverageDetail>;
  @useResult
  $Res call(
      {Beverage beverage,
      List<FlavorAggregate> aggregatedFlavor,
      List<CheckinSummary> recentCheckIns});

  $BeverageCopyWith<$Res> get beverage;
}

/// @nodoc
class _$BeverageDetailCopyWithImpl<$Res, $Val extends BeverageDetail>
    implements $BeverageDetailCopyWith<$Res> {
  _$BeverageDetailCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BeverageDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? beverage = null,
    Object? aggregatedFlavor = null,
    Object? recentCheckIns = null,
  }) {
    return _then(_value.copyWith(
      beverage: null == beverage
          ? _value.beverage
          : beverage // ignore: cast_nullable_to_non_nullable
              as Beverage,
      aggregatedFlavor: null == aggregatedFlavor
          ? _value.aggregatedFlavor
          : aggregatedFlavor // ignore: cast_nullable_to_non_nullable
              as List<FlavorAggregate>,
      recentCheckIns: null == recentCheckIns
          ? _value.recentCheckIns
          : recentCheckIns // ignore: cast_nullable_to_non_nullable
              as List<CheckinSummary>,
    ) as $Val);
  }

  /// Create a copy of BeverageDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BeverageCopyWith<$Res> get beverage {
    return $BeverageCopyWith<$Res>(_value.beverage, (value) {
      return _then(_value.copyWith(beverage: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$BeverageDetailImplCopyWith<$Res>
    implements $BeverageDetailCopyWith<$Res> {
  factory _$$BeverageDetailImplCopyWith(_$BeverageDetailImpl value,
          $Res Function(_$BeverageDetailImpl) then) =
      __$$BeverageDetailImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Beverage beverage,
      List<FlavorAggregate> aggregatedFlavor,
      List<CheckinSummary> recentCheckIns});

  @override
  $BeverageCopyWith<$Res> get beverage;
}

/// @nodoc
class __$$BeverageDetailImplCopyWithImpl<$Res>
    extends _$BeverageDetailCopyWithImpl<$Res, _$BeverageDetailImpl>
    implements _$$BeverageDetailImplCopyWith<$Res> {
  __$$BeverageDetailImplCopyWithImpl(
      _$BeverageDetailImpl _value, $Res Function(_$BeverageDetailImpl) _then)
      : super(_value, _then);

  /// Create a copy of BeverageDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? beverage = null,
    Object? aggregatedFlavor = null,
    Object? recentCheckIns = null,
  }) {
    return _then(_$BeverageDetailImpl(
      beverage: null == beverage
          ? _value.beverage
          : beverage // ignore: cast_nullable_to_non_nullable
              as Beverage,
      aggregatedFlavor: null == aggregatedFlavor
          ? _value._aggregatedFlavor
          : aggregatedFlavor // ignore: cast_nullable_to_non_nullable
              as List<FlavorAggregate>,
      recentCheckIns: null == recentCheckIns
          ? _value._recentCheckIns
          : recentCheckIns // ignore: cast_nullable_to_non_nullable
              as List<CheckinSummary>,
    ));
  }
}

/// @nodoc

class _$BeverageDetailImpl implements _BeverageDetail {
  const _$BeverageDetailImpl(
      {required this.beverage,
      final List<FlavorAggregate> aggregatedFlavor = const <FlavorAggregate>[],
      final List<CheckinSummary> recentCheckIns = const <CheckinSummary>[]})
      : _aggregatedFlavor = aggregatedFlavor,
        _recentCheckIns = recentCheckIns;

  @override
  final Beverage beverage;
  final List<FlavorAggregate> _aggregatedFlavor;
  @override
  @JsonKey()
  List<FlavorAggregate> get aggregatedFlavor {
    if (_aggregatedFlavor is EqualUnmodifiableListView)
      return _aggregatedFlavor;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_aggregatedFlavor);
  }

  final List<CheckinSummary> _recentCheckIns;
  @override
  @JsonKey()
  List<CheckinSummary> get recentCheckIns {
    if (_recentCheckIns is EqualUnmodifiableListView) return _recentCheckIns;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recentCheckIns);
  }

  @override
  String toString() {
    return 'BeverageDetail(beverage: $beverage, aggregatedFlavor: $aggregatedFlavor, recentCheckIns: $recentCheckIns)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BeverageDetailImpl &&
            (identical(other.beverage, beverage) ||
                other.beverage == beverage) &&
            const DeepCollectionEquality()
                .equals(other._aggregatedFlavor, _aggregatedFlavor) &&
            const DeepCollectionEquality()
                .equals(other._recentCheckIns, _recentCheckIns));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      beverage,
      const DeepCollectionEquality().hash(_aggregatedFlavor),
      const DeepCollectionEquality().hash(_recentCheckIns));

  /// Create a copy of BeverageDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BeverageDetailImplCopyWith<_$BeverageDetailImpl> get copyWith =>
      __$$BeverageDetailImplCopyWithImpl<_$BeverageDetailImpl>(
          this, _$identity);
}

abstract class _BeverageDetail implements BeverageDetail {
  const factory _BeverageDetail(
      {required final Beverage beverage,
      final List<FlavorAggregate> aggregatedFlavor,
      final List<CheckinSummary> recentCheckIns}) = _$BeverageDetailImpl;

  @override
  Beverage get beverage;
  @override
  List<FlavorAggregate> get aggregatedFlavor;
  @override
  List<CheckinSummary> get recentCheckIns;

  /// Create a copy of BeverageDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BeverageDetailImplCopyWith<_$BeverageDetailImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$CheckinSummary {
  String get id => throw _privateConstructorUsedError;
  CheckinUser get user => throw _privateConstructorUsedError;
  double? get rating => throw _privateConstructorUsedError;
  String? get review => throw _privateConstructorUsedError;
  String get createdAt => throw _privateConstructorUsedError;

  /// Create a copy of CheckinSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CheckinSummaryCopyWith<CheckinSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CheckinSummaryCopyWith<$Res> {
  factory $CheckinSummaryCopyWith(
          CheckinSummary value, $Res Function(CheckinSummary) then) =
      _$CheckinSummaryCopyWithImpl<$Res, CheckinSummary>;
  @useResult
  $Res call(
      {String id,
      CheckinUser user,
      double? rating,
      String? review,
      String createdAt});

  $CheckinUserCopyWith<$Res> get user;
}

/// @nodoc
class _$CheckinSummaryCopyWithImpl<$Res, $Val extends CheckinSummary>
    implements $CheckinSummaryCopyWith<$Res> {
  _$CheckinSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CheckinSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? rating = freezed,
    Object? review = freezed,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as CheckinUser,
      rating: freezed == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double?,
      review: freezed == review
          ? _value.review
          : review // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }

  /// Create a copy of CheckinSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CheckinUserCopyWith<$Res> get user {
    return $CheckinUserCopyWith<$Res>(_value.user, (value) {
      return _then(_value.copyWith(user: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$CheckinSummaryImplCopyWith<$Res>
    implements $CheckinSummaryCopyWith<$Res> {
  factory _$$CheckinSummaryImplCopyWith(_$CheckinSummaryImpl value,
          $Res Function(_$CheckinSummaryImpl) then) =
      __$$CheckinSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      CheckinUser user,
      double? rating,
      String? review,
      String createdAt});

  @override
  $CheckinUserCopyWith<$Res> get user;
}

/// @nodoc
class __$$CheckinSummaryImplCopyWithImpl<$Res>
    extends _$CheckinSummaryCopyWithImpl<$Res, _$CheckinSummaryImpl>
    implements _$$CheckinSummaryImplCopyWith<$Res> {
  __$$CheckinSummaryImplCopyWithImpl(
      _$CheckinSummaryImpl _value, $Res Function(_$CheckinSummaryImpl) _then)
      : super(_value, _then);

  /// Create a copy of CheckinSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? rating = freezed,
    Object? review = freezed,
    Object? createdAt = null,
  }) {
    return _then(_$CheckinSummaryImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as CheckinUser,
      rating: freezed == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double?,
      review: freezed == review
          ? _value.review
          : review // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$CheckinSummaryImpl implements _CheckinSummary {
  const _$CheckinSummaryImpl(
      {required this.id,
      required this.user,
      this.rating,
      this.review,
      this.createdAt = ''});

  @override
  final String id;
  @override
  final CheckinUser user;
  @override
  final double? rating;
  @override
  final String? review;
  @override
  @JsonKey()
  final String createdAt;

  @override
  String toString() {
    return 'CheckinSummary(id: $id, user: $user, rating: $rating, review: $review, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CheckinSummaryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.review, review) || other.review == review) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, user, rating, review, createdAt);

  /// Create a copy of CheckinSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CheckinSummaryImplCopyWith<_$CheckinSummaryImpl> get copyWith =>
      __$$CheckinSummaryImplCopyWithImpl<_$CheckinSummaryImpl>(
          this, _$identity);
}

abstract class _CheckinSummary implements CheckinSummary {
  const factory _CheckinSummary(
      {required final String id,
      required final CheckinUser user,
      final double? rating,
      final String? review,
      final String createdAt}) = _$CheckinSummaryImpl;

  @override
  String get id;
  @override
  CheckinUser get user;
  @override
  double? get rating;
  @override
  String? get review;
  @override
  String get createdAt;

  /// Create a copy of CheckinSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CheckinSummaryImplCopyWith<_$CheckinSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$CheckinUser {
  String get id => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  String get displayUsername => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String? get avatarUrl => throw _privateConstructorUsedError;

  /// Create a copy of CheckinUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CheckinUserCopyWith<CheckinUser> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CheckinUserCopyWith<$Res> {
  factory $CheckinUserCopyWith(
          CheckinUser value, $Res Function(CheckinUser) then) =
      _$CheckinUserCopyWithImpl<$Res, CheckinUser>;
  @useResult
  $Res call(
      {String id,
      String username,
      String displayUsername,
      String displayName,
      String? avatarUrl});
}

/// @nodoc
class _$CheckinUserCopyWithImpl<$Res, $Val extends CheckinUser>
    implements $CheckinUserCopyWith<$Res> {
  _$CheckinUserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CheckinUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? displayUsername = null,
    Object? displayName = null,
    Object? avatarUrl = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      displayUsername: null == displayUsername
          ? _value.displayUsername
          : displayUsername // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CheckinUserImplCopyWith<$Res>
    implements $CheckinUserCopyWith<$Res> {
  factory _$$CheckinUserImplCopyWith(
          _$CheckinUserImpl value, $Res Function(_$CheckinUserImpl) then) =
      __$$CheckinUserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String username,
      String displayUsername,
      String displayName,
      String? avatarUrl});
}

/// @nodoc
class __$$CheckinUserImplCopyWithImpl<$Res>
    extends _$CheckinUserCopyWithImpl<$Res, _$CheckinUserImpl>
    implements _$$CheckinUserImplCopyWith<$Res> {
  __$$CheckinUserImplCopyWithImpl(
      _$CheckinUserImpl _value, $Res Function(_$CheckinUserImpl) _then)
      : super(_value, _then);

  /// Create a copy of CheckinUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? displayUsername = null,
    Object? displayName = null,
    Object? avatarUrl = freezed,
  }) {
    return _then(_$CheckinUserImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      displayUsername: null == displayUsername
          ? _value.displayUsername
          : displayUsername // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$CheckinUserImpl implements _CheckinUser {
  const _$CheckinUserImpl(
      {required this.id,
      required this.username,
      required this.displayUsername,
      required this.displayName,
      this.avatarUrl});

  @override
  final String id;
  @override
  final String username;
  @override
  final String displayUsername;
  @override
  final String displayName;
  @override
  final String? avatarUrl;

  @override
  String toString() {
    return 'CheckinUser(id: $id, username: $username, displayUsername: $displayUsername, displayName: $displayName, avatarUrl: $avatarUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CheckinUserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.displayUsername, displayUsername) ||
                other.displayUsername == displayUsername) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, id, username, displayUsername, displayName, avatarUrl);

  /// Create a copy of CheckinUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CheckinUserImplCopyWith<_$CheckinUserImpl> get copyWith =>
      __$$CheckinUserImplCopyWithImpl<_$CheckinUserImpl>(this, _$identity);
}

abstract class _CheckinUser implements CheckinUser {
  const factory _CheckinUser(
      {required final String id,
      required final String username,
      required final String displayUsername,
      required final String displayName,
      final String? avatarUrl}) = _$CheckinUserImpl;

  @override
  String get id;
  @override
  String get username;
  @override
  String get displayUsername;
  @override
  String get displayName;
  @override
  String? get avatarUrl;

  /// Create a copy of CheckinUser
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CheckinUserImplCopyWith<_$CheckinUserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
