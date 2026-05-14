// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'checkin.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$PhotoRef {
  String get url => throw _privateConstructorUsedError;
  int get sortOrder => throw _privateConstructorUsedError;

  /// Create a copy of PhotoRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PhotoRefCopyWith<PhotoRef> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PhotoRefCopyWith<$Res> {
  factory $PhotoRefCopyWith(PhotoRef value, $Res Function(PhotoRef) then) =
      _$PhotoRefCopyWithImpl<$Res, PhotoRef>;
  @useResult
  $Res call({String url, int sortOrder});
}

/// @nodoc
class _$PhotoRefCopyWithImpl<$Res, $Val extends PhotoRef>
    implements $PhotoRefCopyWith<$Res> {
  _$PhotoRefCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PhotoRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? sortOrder = null,
  }) {
    return _then(_value.copyWith(
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      sortOrder: null == sortOrder
          ? _value.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PhotoRefImplCopyWith<$Res>
    implements $PhotoRefCopyWith<$Res> {
  factory _$$PhotoRefImplCopyWith(
          _$PhotoRefImpl value, $Res Function(_$PhotoRefImpl) then) =
      __$$PhotoRefImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String url, int sortOrder});
}

/// @nodoc
class __$$PhotoRefImplCopyWithImpl<$Res>
    extends _$PhotoRefCopyWithImpl<$Res, _$PhotoRefImpl>
    implements _$$PhotoRefImplCopyWith<$Res> {
  __$$PhotoRefImplCopyWithImpl(
      _$PhotoRefImpl _value, $Res Function(_$PhotoRefImpl) _then)
      : super(_value, _then);

  /// Create a copy of PhotoRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? sortOrder = null,
  }) {
    return _then(_$PhotoRefImpl(
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      sortOrder: null == sortOrder
          ? _value.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$PhotoRefImpl implements _PhotoRef {
  const _$PhotoRefImpl({required this.url, this.sortOrder = 0});

  @override
  final String url;
  @override
  @JsonKey()
  final int sortOrder;

  @override
  String toString() {
    return 'PhotoRef(url: $url, sortOrder: $sortOrder)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PhotoRefImpl &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder));
  }

  @override
  int get hashCode => Object.hash(runtimeType, url, sortOrder);

  /// Create a copy of PhotoRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PhotoRefImplCopyWith<_$PhotoRefImpl> get copyWith =>
      __$$PhotoRefImplCopyWithImpl<_$PhotoRefImpl>(this, _$identity);
}

abstract class _PhotoRef implements PhotoRef {
  const factory _PhotoRef({required final String url, final int sortOrder}) =
      _$PhotoRefImpl;

  @override
  String get url;
  @override
  int get sortOrder;

  /// Create a copy of PhotoRef
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PhotoRefImplCopyWith<_$PhotoRefImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$Price {
  double get amount => throw _privateConstructorUsedError;
  String get currency => throw _privateConstructorUsedError;
  String get mode => throw _privateConstructorUsedError;

  /// Create a copy of Price
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PriceCopyWith<Price> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PriceCopyWith<$Res> {
  factory $PriceCopyWith(Price value, $Res Function(Price) then) =
      _$PriceCopyWithImpl<$Res, Price>;
  @useResult
  $Res call({double amount, String currency, String mode});
}

/// @nodoc
class _$PriceCopyWithImpl<$Res, $Val extends Price>
    implements $PriceCopyWith<$Res> {
  _$PriceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Price
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? amount = null,
    Object? currency = null,
    Object? mode = null,
  }) {
    return _then(_value.copyWith(
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      currency: null == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      mode: null == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PriceImplCopyWith<$Res> implements $PriceCopyWith<$Res> {
  factory _$$PriceImplCopyWith(
          _$PriceImpl value, $Res Function(_$PriceImpl) then) =
      __$$PriceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({double amount, String currency, String mode});
}

/// @nodoc
class __$$PriceImplCopyWithImpl<$Res>
    extends _$PriceCopyWithImpl<$Res, _$PriceImpl>
    implements _$$PriceImplCopyWith<$Res> {
  __$$PriceImplCopyWithImpl(
      _$PriceImpl _value, $Res Function(_$PriceImpl) _then)
      : super(_value, _then);

  /// Create a copy of Price
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? amount = null,
    Object? currency = null,
    Object? mode = null,
  }) {
    return _then(_$PriceImpl(
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      currency: null == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      mode: null == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$PriceImpl extends _Price {
  const _$PriceImpl(
      {required this.amount, required this.currency, required this.mode})
      : super._();

  @override
  final double amount;
  @override
  final String currency;
  @override
  final String mode;

  @override
  String toString() {
    return 'Price(amount: $amount, currency: $currency, mode: $mode)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PriceImpl &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.mode, mode) || other.mode == mode));
  }

  @override
  int get hashCode => Object.hash(runtimeType, amount, currency, mode);

  /// Create a copy of Price
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PriceImplCopyWith<_$PriceImpl> get copyWith =>
      __$$PriceImplCopyWithImpl<_$PriceImpl>(this, _$identity);
}

abstract class _Price extends Price {
  const factory _Price(
      {required final double amount,
      required final String currency,
      required final String mode}) = _$PriceImpl;
  const _Price._() : super._();

  @override
  double get amount;
  @override
  String get currency;
  @override
  String get mode;

  /// Create a copy of Price
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PriceImplCopyWith<_$PriceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$Checkin {
  String get id => throw _privateConstructorUsedError;
  CheckinUser get user => throw _privateConstructorUsedError;
  BeverageRef get beverage => throw _privateConstructorUsedError;
  double? get rating => throw _privateConstructorUsedError;
  String? get review => throw _privateConstructorUsedError;
  List<FlavorTag> get tags => throw _privateConstructorUsedError;
  List<PhotoRef> get photos => throw _privateConstructorUsedError;
  Price? get price => throw _privateConstructorUsedError;
  String? get purchaseType => throw _privateConstructorUsedError;
  String? get servingStyle => throw _privateConstructorUsedError;
  int get toasts => throw _privateConstructorUsedError;
  bool get youToasted => throw _privateConstructorUsedError;
  String get createdAt => throw _privateConstructorUsedError;
  String get updatedAt => throw _privateConstructorUsedError;

  /// Create a copy of Checkin
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CheckinCopyWith<Checkin> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CheckinCopyWith<$Res> {
  factory $CheckinCopyWith(Checkin value, $Res Function(Checkin) then) =
      _$CheckinCopyWithImpl<$Res, Checkin>;
  @useResult
  $Res call(
      {String id,
      CheckinUser user,
      BeverageRef beverage,
      double? rating,
      String? review,
      List<FlavorTag> tags,
      List<PhotoRef> photos,
      Price? price,
      String? purchaseType,
      String? servingStyle,
      int toasts,
      bool youToasted,
      String createdAt,
      String updatedAt});

  $CheckinUserCopyWith<$Res> get user;
  $BeverageRefCopyWith<$Res> get beverage;
  $PriceCopyWith<$Res>? get price;
}

/// @nodoc
class _$CheckinCopyWithImpl<$Res, $Val extends Checkin>
    implements $CheckinCopyWith<$Res> {
  _$CheckinCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Checkin
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? beverage = null,
    Object? rating = freezed,
    Object? review = freezed,
    Object? tags = null,
    Object? photos = null,
    Object? price = freezed,
    Object? purchaseType = freezed,
    Object? servingStyle = freezed,
    Object? toasts = null,
    Object? youToasted = null,
    Object? createdAt = null,
    Object? updatedAt = null,
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
      beverage: null == beverage
          ? _value.beverage
          : beverage // ignore: cast_nullable_to_non_nullable
              as BeverageRef,
      rating: freezed == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double?,
      review: freezed == review
          ? _value.review
          : review // ignore: cast_nullable_to_non_nullable
              as String?,
      tags: null == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<FlavorTag>,
      photos: null == photos
          ? _value.photos
          : photos // ignore: cast_nullable_to_non_nullable
              as List<PhotoRef>,
      price: freezed == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as Price?,
      purchaseType: freezed == purchaseType
          ? _value.purchaseType
          : purchaseType // ignore: cast_nullable_to_non_nullable
              as String?,
      servingStyle: freezed == servingStyle
          ? _value.servingStyle
          : servingStyle // ignore: cast_nullable_to_non_nullable
              as String?,
      toasts: null == toasts
          ? _value.toasts
          : toasts // ignore: cast_nullable_to_non_nullable
              as int,
      youToasted: null == youToasted
          ? _value.youToasted
          : youToasted // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }

  /// Create a copy of Checkin
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CheckinUserCopyWith<$Res> get user {
    return $CheckinUserCopyWith<$Res>(_value.user, (value) {
      return _then(_value.copyWith(user: value) as $Val);
    });
  }

  /// Create a copy of Checkin
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BeverageRefCopyWith<$Res> get beverage {
    return $BeverageRefCopyWith<$Res>(_value.beverage, (value) {
      return _then(_value.copyWith(beverage: value) as $Val);
    });
  }

  /// Create a copy of Checkin
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res>? get price {
    if (_value.price == null) {
      return null;
    }

    return $PriceCopyWith<$Res>(_value.price!, (value) {
      return _then(_value.copyWith(price: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$CheckinImplCopyWith<$Res> implements $CheckinCopyWith<$Res> {
  factory _$$CheckinImplCopyWith(
          _$CheckinImpl value, $Res Function(_$CheckinImpl) then) =
      __$$CheckinImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      CheckinUser user,
      BeverageRef beverage,
      double? rating,
      String? review,
      List<FlavorTag> tags,
      List<PhotoRef> photos,
      Price? price,
      String? purchaseType,
      String? servingStyle,
      int toasts,
      bool youToasted,
      String createdAt,
      String updatedAt});

  @override
  $CheckinUserCopyWith<$Res> get user;
  @override
  $BeverageRefCopyWith<$Res> get beverage;
  @override
  $PriceCopyWith<$Res>? get price;
}

/// @nodoc
class __$$CheckinImplCopyWithImpl<$Res>
    extends _$CheckinCopyWithImpl<$Res, _$CheckinImpl>
    implements _$$CheckinImplCopyWith<$Res> {
  __$$CheckinImplCopyWithImpl(
      _$CheckinImpl _value, $Res Function(_$CheckinImpl) _then)
      : super(_value, _then);

  /// Create a copy of Checkin
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? beverage = null,
    Object? rating = freezed,
    Object? review = freezed,
    Object? tags = null,
    Object? photos = null,
    Object? price = freezed,
    Object? purchaseType = freezed,
    Object? servingStyle = freezed,
    Object? toasts = null,
    Object? youToasted = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$CheckinImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as CheckinUser,
      beverage: null == beverage
          ? _value.beverage
          : beverage // ignore: cast_nullable_to_non_nullable
              as BeverageRef,
      rating: freezed == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double?,
      review: freezed == review
          ? _value.review
          : review // ignore: cast_nullable_to_non_nullable
              as String?,
      tags: null == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<FlavorTag>,
      photos: null == photos
          ? _value._photos
          : photos // ignore: cast_nullable_to_non_nullable
              as List<PhotoRef>,
      price: freezed == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as Price?,
      purchaseType: freezed == purchaseType
          ? _value.purchaseType
          : purchaseType // ignore: cast_nullable_to_non_nullable
              as String?,
      servingStyle: freezed == servingStyle
          ? _value.servingStyle
          : servingStyle // ignore: cast_nullable_to_non_nullable
              as String?,
      toasts: null == toasts
          ? _value.toasts
          : toasts // ignore: cast_nullable_to_non_nullable
              as int,
      youToasted: null == youToasted
          ? _value.youToasted
          : youToasted // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$CheckinImpl implements _Checkin {
  const _$CheckinImpl(
      {required this.id,
      required this.user,
      required this.beverage,
      this.rating,
      this.review,
      final List<FlavorTag> tags = const <FlavorTag>[],
      final List<PhotoRef> photos = const <PhotoRef>[],
      this.price,
      this.purchaseType,
      this.servingStyle,
      this.toasts = 0,
      this.youToasted = false,
      this.createdAt = '',
      this.updatedAt = ''})
      : _tags = tags,
        _photos = photos;

  @override
  final String id;
  @override
  final CheckinUser user;
  @override
  final BeverageRef beverage;
  @override
  final double? rating;
  @override
  final String? review;
  final List<FlavorTag> _tags;
  @override
  @JsonKey()
  List<FlavorTag> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  final List<PhotoRef> _photos;
  @override
  @JsonKey()
  List<PhotoRef> get photos {
    if (_photos is EqualUnmodifiableListView) return _photos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_photos);
  }

  @override
  final Price? price;
  @override
  final String? purchaseType;
  @override
  final String? servingStyle;
  @override
  @JsonKey()
  final int toasts;
  @override
  @JsonKey()
  final bool youToasted;
  @override
  @JsonKey()
  final String createdAt;
  @override
  @JsonKey()
  final String updatedAt;

  @override
  String toString() {
    return 'Checkin(id: $id, user: $user, beverage: $beverage, rating: $rating, review: $review, tags: $tags, photos: $photos, price: $price, purchaseType: $purchaseType, servingStyle: $servingStyle, toasts: $toasts, youToasted: $youToasted, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CheckinImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.beverage, beverage) ||
                other.beverage == beverage) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.review, review) || other.review == review) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            const DeepCollectionEquality().equals(other._photos, _photos) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.purchaseType, purchaseType) ||
                other.purchaseType == purchaseType) &&
            (identical(other.servingStyle, servingStyle) ||
                other.servingStyle == servingStyle) &&
            (identical(other.toasts, toasts) || other.toasts == toasts) &&
            (identical(other.youToasted, youToasted) ||
                other.youToasted == youToasted) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      user,
      beverage,
      rating,
      review,
      const DeepCollectionEquality().hash(_tags),
      const DeepCollectionEquality().hash(_photos),
      price,
      purchaseType,
      servingStyle,
      toasts,
      youToasted,
      createdAt,
      updatedAt);

  /// Create a copy of Checkin
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CheckinImplCopyWith<_$CheckinImpl> get copyWith =>
      __$$CheckinImplCopyWithImpl<_$CheckinImpl>(this, _$identity);
}

abstract class _Checkin implements Checkin {
  const factory _Checkin(
      {required final String id,
      required final CheckinUser user,
      required final BeverageRef beverage,
      final double? rating,
      final String? review,
      final List<FlavorTag> tags,
      final List<PhotoRef> photos,
      final Price? price,
      final String? purchaseType,
      final String? servingStyle,
      final int toasts,
      final bool youToasted,
      final String createdAt,
      final String updatedAt}) = _$CheckinImpl;

  @override
  String get id;
  @override
  CheckinUser get user;
  @override
  BeverageRef get beverage;
  @override
  double? get rating;
  @override
  String? get review;
  @override
  List<FlavorTag> get tags;
  @override
  List<PhotoRef> get photos;
  @override
  Price? get price;
  @override
  String? get purchaseType;
  @override
  String? get servingStyle;
  @override
  int get toasts;
  @override
  bool get youToasted;
  @override
  String get createdAt;
  @override
  String get updatedAt;

  /// Create a copy of Checkin
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CheckinImplCopyWith<_$CheckinImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$FeedItem {
  String get id => throw _privateConstructorUsedError;
  CheckinUser get user => throw _privateConstructorUsedError;
  BeverageRef get beverage => throw _privateConstructorUsedError;
  double? get rating => throw _privateConstructorUsedError;
  String? get review => throw _privateConstructorUsedError;
  List<FlavorTag> get tags => throw _privateConstructorUsedError;
  int get toasts => throw _privateConstructorUsedError;
  bool get youToasted => throw _privateConstructorUsedError;
  int get photoCount => throw _privateConstructorUsedError;
  String get createdAt => throw _privateConstructorUsedError;

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FeedItemCopyWith<FeedItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FeedItemCopyWith<$Res> {
  factory $FeedItemCopyWith(FeedItem value, $Res Function(FeedItem) then) =
      _$FeedItemCopyWithImpl<$Res, FeedItem>;
  @useResult
  $Res call(
      {String id,
      CheckinUser user,
      BeverageRef beverage,
      double? rating,
      String? review,
      List<FlavorTag> tags,
      int toasts,
      bool youToasted,
      int photoCount,
      String createdAt});

  $CheckinUserCopyWith<$Res> get user;
  $BeverageRefCopyWith<$Res> get beverage;
}

/// @nodoc
class _$FeedItemCopyWithImpl<$Res, $Val extends FeedItem>
    implements $FeedItemCopyWith<$Res> {
  _$FeedItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? beverage = null,
    Object? rating = freezed,
    Object? review = freezed,
    Object? tags = null,
    Object? toasts = null,
    Object? youToasted = null,
    Object? photoCount = null,
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
      beverage: null == beverage
          ? _value.beverage
          : beverage // ignore: cast_nullable_to_non_nullable
              as BeverageRef,
      rating: freezed == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double?,
      review: freezed == review
          ? _value.review
          : review // ignore: cast_nullable_to_non_nullable
              as String?,
      tags: null == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<FlavorTag>,
      toasts: null == toasts
          ? _value.toasts
          : toasts // ignore: cast_nullable_to_non_nullable
              as int,
      youToasted: null == youToasted
          ? _value.youToasted
          : youToasted // ignore: cast_nullable_to_non_nullable
              as bool,
      photoCount: null == photoCount
          ? _value.photoCount
          : photoCount // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CheckinUserCopyWith<$Res> get user {
    return $CheckinUserCopyWith<$Res>(_value.user, (value) {
      return _then(_value.copyWith(user: value) as $Val);
    });
  }

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BeverageRefCopyWith<$Res> get beverage {
    return $BeverageRefCopyWith<$Res>(_value.beverage, (value) {
      return _then(_value.copyWith(beverage: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$FeedItemImplCopyWith<$Res>
    implements $FeedItemCopyWith<$Res> {
  factory _$$FeedItemImplCopyWith(
          _$FeedItemImpl value, $Res Function(_$FeedItemImpl) then) =
      __$$FeedItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      CheckinUser user,
      BeverageRef beverage,
      double? rating,
      String? review,
      List<FlavorTag> tags,
      int toasts,
      bool youToasted,
      int photoCount,
      String createdAt});

  @override
  $CheckinUserCopyWith<$Res> get user;
  @override
  $BeverageRefCopyWith<$Res> get beverage;
}

/// @nodoc
class __$$FeedItemImplCopyWithImpl<$Res>
    extends _$FeedItemCopyWithImpl<$Res, _$FeedItemImpl>
    implements _$$FeedItemImplCopyWith<$Res> {
  __$$FeedItemImplCopyWithImpl(
      _$FeedItemImpl _value, $Res Function(_$FeedItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? beverage = null,
    Object? rating = freezed,
    Object? review = freezed,
    Object? tags = null,
    Object? toasts = null,
    Object? youToasted = null,
    Object? photoCount = null,
    Object? createdAt = null,
  }) {
    return _then(_$FeedItemImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as CheckinUser,
      beverage: null == beverage
          ? _value.beverage
          : beverage // ignore: cast_nullable_to_non_nullable
              as BeverageRef,
      rating: freezed == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double?,
      review: freezed == review
          ? _value.review
          : review // ignore: cast_nullable_to_non_nullable
              as String?,
      tags: null == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<FlavorTag>,
      toasts: null == toasts
          ? _value.toasts
          : toasts // ignore: cast_nullable_to_non_nullable
              as int,
      youToasted: null == youToasted
          ? _value.youToasted
          : youToasted // ignore: cast_nullable_to_non_nullable
              as bool,
      photoCount: null == photoCount
          ? _value.photoCount
          : photoCount // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$FeedItemImpl implements _FeedItem {
  const _$FeedItemImpl(
      {required this.id,
      required this.user,
      required this.beverage,
      this.rating,
      this.review,
      final List<FlavorTag> tags = const <FlavorTag>[],
      this.toasts = 0,
      this.youToasted = false,
      this.photoCount = 0,
      this.createdAt = ''})
      : _tags = tags;

  @override
  final String id;
  @override
  final CheckinUser user;
  @override
  final BeverageRef beverage;
  @override
  final double? rating;
  @override
  final String? review;
  final List<FlavorTag> _tags;
  @override
  @JsonKey()
  List<FlavorTag> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  @JsonKey()
  final int toasts;
  @override
  @JsonKey()
  final bool youToasted;
  @override
  @JsonKey()
  final int photoCount;
  @override
  @JsonKey()
  final String createdAt;

  @override
  String toString() {
    return 'FeedItem(id: $id, user: $user, beverage: $beverage, rating: $rating, review: $review, tags: $tags, toasts: $toasts, youToasted: $youToasted, photoCount: $photoCount, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeedItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.beverage, beverage) ||
                other.beverage == beverage) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.review, review) || other.review == review) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.toasts, toasts) || other.toasts == toasts) &&
            (identical(other.youToasted, youToasted) ||
                other.youToasted == youToasted) &&
            (identical(other.photoCount, photoCount) ||
                other.photoCount == photoCount) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      user,
      beverage,
      rating,
      review,
      const DeepCollectionEquality().hash(_tags),
      toasts,
      youToasted,
      photoCount,
      createdAt);

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeedItemImplCopyWith<_$FeedItemImpl> get copyWith =>
      __$$FeedItemImplCopyWithImpl<_$FeedItemImpl>(this, _$identity);
}

abstract class _FeedItem implements FeedItem {
  const factory _FeedItem(
      {required final String id,
      required final CheckinUser user,
      required final BeverageRef beverage,
      final double? rating,
      final String? review,
      final List<FlavorTag> tags,
      final int toasts,
      final bool youToasted,
      final int photoCount,
      final String createdAt}) = _$FeedItemImpl;

  @override
  String get id;
  @override
  CheckinUser get user;
  @override
  BeverageRef get beverage;
  @override
  double? get rating;
  @override
  String? get review;
  @override
  List<FlavorTag> get tags;
  @override
  int get toasts;
  @override
  bool get youToasted;
  @override
  int get photoCount;
  @override
  String get createdAt;

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeedItemImplCopyWith<_$FeedItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ToastState {
  int get toasts => throw _privateConstructorUsedError;
  bool get youToasted => throw _privateConstructorUsedError;

  /// Create a copy of ToastState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ToastStateCopyWith<ToastState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ToastStateCopyWith<$Res> {
  factory $ToastStateCopyWith(
          ToastState value, $Res Function(ToastState) then) =
      _$ToastStateCopyWithImpl<$Res, ToastState>;
  @useResult
  $Res call({int toasts, bool youToasted});
}

/// @nodoc
class _$ToastStateCopyWithImpl<$Res, $Val extends ToastState>
    implements $ToastStateCopyWith<$Res> {
  _$ToastStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ToastState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? toasts = null,
    Object? youToasted = null,
  }) {
    return _then(_value.copyWith(
      toasts: null == toasts
          ? _value.toasts
          : toasts // ignore: cast_nullable_to_non_nullable
              as int,
      youToasted: null == youToasted
          ? _value.youToasted
          : youToasted // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ToastStateImplCopyWith<$Res>
    implements $ToastStateCopyWith<$Res> {
  factory _$$ToastStateImplCopyWith(
          _$ToastStateImpl value, $Res Function(_$ToastStateImpl) then) =
      __$$ToastStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int toasts, bool youToasted});
}

/// @nodoc
class __$$ToastStateImplCopyWithImpl<$Res>
    extends _$ToastStateCopyWithImpl<$Res, _$ToastStateImpl>
    implements _$$ToastStateImplCopyWith<$Res> {
  __$$ToastStateImplCopyWithImpl(
      _$ToastStateImpl _value, $Res Function(_$ToastStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of ToastState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? toasts = null,
    Object? youToasted = null,
  }) {
    return _then(_$ToastStateImpl(
      toasts: null == toasts
          ? _value.toasts
          : toasts // ignore: cast_nullable_to_non_nullable
              as int,
      youToasted: null == youToasted
          ? _value.youToasted
          : youToasted // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$ToastStateImpl implements _ToastState {
  const _$ToastStateImpl({this.toasts = 0, this.youToasted = false});

  @override
  @JsonKey()
  final int toasts;
  @override
  @JsonKey()
  final bool youToasted;

  @override
  String toString() {
    return 'ToastState(toasts: $toasts, youToasted: $youToasted)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ToastStateImpl &&
            (identical(other.toasts, toasts) || other.toasts == toasts) &&
            (identical(other.youToasted, youToasted) ||
                other.youToasted == youToasted));
  }

  @override
  int get hashCode => Object.hash(runtimeType, toasts, youToasted);

  /// Create a copy of ToastState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ToastStateImplCopyWith<_$ToastStateImpl> get copyWith =>
      __$$ToastStateImplCopyWithImpl<_$ToastStateImpl>(this, _$identity);
}

abstract class _ToastState implements ToastState {
  const factory _ToastState({final int toasts, final bool youToasted}) =
      _$ToastStateImpl;

  @override
  int get toasts;
  @override
  bool get youToasted;

  /// Create a copy of ToastState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ToastStateImplCopyWith<_$ToastStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
