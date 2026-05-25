// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'checkin.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Price {

 double get amount; String get currency; String get mode;
/// Create a copy of Price
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PriceCopyWith<Price> get copyWith => _$PriceCopyWithImpl<Price>(this as Price, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Price&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.mode, mode) || other.mode == mode));
}


@override
int get hashCode => Object.hash(runtimeType,amount,currency,mode);

@override
String toString() {
  return 'Price(amount: $amount, currency: $currency, mode: $mode)';
}


}

/// @nodoc
abstract mixin class $PriceCopyWith<$Res>  {
  factory $PriceCopyWith(Price value, $Res Function(Price) _then) = _$PriceCopyWithImpl;
@useResult
$Res call({
 double amount, String currency, String mode
});




}
/// @nodoc
class _$PriceCopyWithImpl<$Res>
    implements $PriceCopyWith<$Res> {
  _$PriceCopyWithImpl(this._self, this._then);

  final Price _self;
  final $Res Function(Price) _then;

/// Create a copy of Price
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? amount = null,Object? currency = null,Object? mode = null,}) {
  return _then(_self.copyWith(
amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Price].
extension PricePatterns on Price {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Price value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Price() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Price value)  $default,){
final _that = this;
switch (_that) {
case _Price():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Price value)?  $default,){
final _that = this;
switch (_that) {
case _Price() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double amount,  String currency,  String mode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Price() when $default != null:
return $default(_that.amount,_that.currency,_that.mode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double amount,  String currency,  String mode)  $default,) {final _that = this;
switch (_that) {
case _Price():
return $default(_that.amount,_that.currency,_that.mode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double amount,  String currency,  String mode)?  $default,) {final _that = this;
switch (_that) {
case _Price() when $default != null:
return $default(_that.amount,_that.currency,_that.mode);case _:
  return null;

}
}

}

/// @nodoc


class _Price extends Price {
  const _Price({required this.amount, required this.currency, required this.mode}): super._();
  

@override final  double amount;
@override final  String currency;
@override final  String mode;

/// Create a copy of Price
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PriceCopyWith<_Price> get copyWith => __$PriceCopyWithImpl<_Price>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Price&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.mode, mode) || other.mode == mode));
}


@override
int get hashCode => Object.hash(runtimeType,amount,currency,mode);

@override
String toString() {
  return 'Price(amount: $amount, currency: $currency, mode: $mode)';
}


}

/// @nodoc
abstract mixin class _$PriceCopyWith<$Res> implements $PriceCopyWith<$Res> {
  factory _$PriceCopyWith(_Price value, $Res Function(_Price) _then) = __$PriceCopyWithImpl;
@override @useResult
$Res call({
 double amount, String currency, String mode
});




}
/// @nodoc
class __$PriceCopyWithImpl<$Res>
    implements _$PriceCopyWith<$Res> {
  __$PriceCopyWithImpl(this._self, this._then);

  final _Price _self;
  final $Res Function(_Price) _then;

/// Create a copy of Price
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? amount = null,Object? currency = null,Object? mode = null,}) {
  return _then(_Price(
amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$Checkin {

 String get id; CheckinUser get user; BeverageRef get beverage; double? get rating; String? get review; List<FlavorTag> get tags; List<PhotoRef> get photos; Price? get price; String? get purchaseType; VenueRef? get venue; int get toasts; bool get youToasted;// Server-aggregated comment count (Phase 6a). Defaults to 0 so older
// servers (or omitted-key responses) remain wire-compatible. Mirrors
// the same field on FeedItem so the detail screen can render the
// comment badge without a separate `GET /comments` round trip.
 int get commentCount; String get createdAt; String get updatedAt;
/// Create a copy of Checkin
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CheckinCopyWith<Checkin> get copyWith => _$CheckinCopyWithImpl<Checkin>(this as Checkin, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Checkin&&(identical(other.id, id) || other.id == id)&&(identical(other.user, user) || other.user == user)&&(identical(other.beverage, beverage) || other.beverage == beverage)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.review, review) || other.review == review)&&const DeepCollectionEquality().equals(other.tags, tags)&&const DeepCollectionEquality().equals(other.photos, photos)&&(identical(other.price, price) || other.price == price)&&(identical(other.purchaseType, purchaseType) || other.purchaseType == purchaseType)&&(identical(other.venue, venue) || other.venue == venue)&&(identical(other.toasts, toasts) || other.toasts == toasts)&&(identical(other.youToasted, youToasted) || other.youToasted == youToasted)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,user,beverage,rating,review,const DeepCollectionEquality().hash(tags),const DeepCollectionEquality().hash(photos),price,purchaseType,venue,toasts,youToasted,commentCount,createdAt,updatedAt);

@override
String toString() {
  return 'Checkin(id: $id, user: $user, beverage: $beverage, rating: $rating, review: $review, tags: $tags, photos: $photos, price: $price, purchaseType: $purchaseType, venue: $venue, toasts: $toasts, youToasted: $youToasted, commentCount: $commentCount, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $CheckinCopyWith<$Res>  {
  factory $CheckinCopyWith(Checkin value, $Res Function(Checkin) _then) = _$CheckinCopyWithImpl;
@useResult
$Res call({
 String id, CheckinUser user, BeverageRef beverage, double? rating, String? review, List<FlavorTag> tags, List<PhotoRef> photos, Price? price, String? purchaseType, VenueRef? venue, int toasts, bool youToasted, int commentCount, String createdAt, String updatedAt
});


$CheckinUserCopyWith<$Res> get user;$BeverageRefCopyWith<$Res> get beverage;$PriceCopyWith<$Res>? get price;$VenueRefCopyWith<$Res>? get venue;

}
/// @nodoc
class _$CheckinCopyWithImpl<$Res>
    implements $CheckinCopyWith<$Res> {
  _$CheckinCopyWithImpl(this._self, this._then);

  final Checkin _self;
  final $Res Function(Checkin) _then;

/// Create a copy of Checkin
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? user = null,Object? beverage = null,Object? rating = freezed,Object? review = freezed,Object? tags = null,Object? photos = null,Object? price = freezed,Object? purchaseType = freezed,Object? venue = freezed,Object? toasts = null,Object? youToasted = null,Object? commentCount = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as CheckinUser,beverage: null == beverage ? _self.beverage : beverage // ignore: cast_nullable_to_non_nullable
as BeverageRef,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,review: freezed == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<FlavorTag>,photos: null == photos ? _self.photos : photos // ignore: cast_nullable_to_non_nullable
as List<PhotoRef>,price: freezed == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as Price?,purchaseType: freezed == purchaseType ? _self.purchaseType : purchaseType // ignore: cast_nullable_to_non_nullable
as String?,venue: freezed == venue ? _self.venue : venue // ignore: cast_nullable_to_non_nullable
as VenueRef?,toasts: null == toasts ? _self.toasts : toasts // ignore: cast_nullable_to_non_nullable
as int,youToasted: null == youToasted ? _self.youToasted : youToasted // ignore: cast_nullable_to_non_nullable
as bool,commentCount: null == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of Checkin
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CheckinUserCopyWith<$Res> get user {
  
  return $CheckinUserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}/// Create a copy of Checkin
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BeverageRefCopyWith<$Res> get beverage {
  
  return $BeverageRefCopyWith<$Res>(_self.beverage, (value) {
    return _then(_self.copyWith(beverage: value));
  });
}/// Create a copy of Checkin
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PriceCopyWith<$Res>? get price {
    if (_self.price == null) {
    return null;
  }

  return $PriceCopyWith<$Res>(_self.price!, (value) {
    return _then(_self.copyWith(price: value));
  });
}/// Create a copy of Checkin
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VenueRefCopyWith<$Res>? get venue {
    if (_self.venue == null) {
    return null;
  }

  return $VenueRefCopyWith<$Res>(_self.venue!, (value) {
    return _then(_self.copyWith(venue: value));
  });
}
}


/// Adds pattern-matching-related methods to [Checkin].
extension CheckinPatterns on Checkin {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Checkin value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Checkin() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Checkin value)  $default,){
final _that = this;
switch (_that) {
case _Checkin():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Checkin value)?  $default,){
final _that = this;
switch (_that) {
case _Checkin() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  CheckinUser user,  BeverageRef beverage,  double? rating,  String? review,  List<FlavorTag> tags,  List<PhotoRef> photos,  Price? price,  String? purchaseType,  VenueRef? venue,  int toasts,  bool youToasted,  int commentCount,  String createdAt,  String updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Checkin() when $default != null:
return $default(_that.id,_that.user,_that.beverage,_that.rating,_that.review,_that.tags,_that.photos,_that.price,_that.purchaseType,_that.venue,_that.toasts,_that.youToasted,_that.commentCount,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  CheckinUser user,  BeverageRef beverage,  double? rating,  String? review,  List<FlavorTag> tags,  List<PhotoRef> photos,  Price? price,  String? purchaseType,  VenueRef? venue,  int toasts,  bool youToasted,  int commentCount,  String createdAt,  String updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Checkin():
return $default(_that.id,_that.user,_that.beverage,_that.rating,_that.review,_that.tags,_that.photos,_that.price,_that.purchaseType,_that.venue,_that.toasts,_that.youToasted,_that.commentCount,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  CheckinUser user,  BeverageRef beverage,  double? rating,  String? review,  List<FlavorTag> tags,  List<PhotoRef> photos,  Price? price,  String? purchaseType,  VenueRef? venue,  int toasts,  bool youToasted,  int commentCount,  String createdAt,  String updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Checkin() when $default != null:
return $default(_that.id,_that.user,_that.beverage,_that.rating,_that.review,_that.tags,_that.photos,_that.price,_that.purchaseType,_that.venue,_that.toasts,_that.youToasted,_that.commentCount,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _Checkin implements Checkin {
  const _Checkin({required this.id, required this.user, required this.beverage, this.rating, this.review, final  List<FlavorTag> tags = const <FlavorTag>[], final  List<PhotoRef> photos = const <PhotoRef>[], this.price, this.purchaseType, this.venue, this.toasts = 0, this.youToasted = false, this.commentCount = 0, this.createdAt = '', this.updatedAt = ''}): _tags = tags,_photos = photos;
  

@override final  String id;
@override final  CheckinUser user;
@override final  BeverageRef beverage;
@override final  double? rating;
@override final  String? review;
 final  List<FlavorTag> _tags;
@override@JsonKey() List<FlavorTag> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

 final  List<PhotoRef> _photos;
@override@JsonKey() List<PhotoRef> get photos {
  if (_photos is EqualUnmodifiableListView) return _photos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_photos);
}

@override final  Price? price;
@override final  String? purchaseType;
@override final  VenueRef? venue;
@override@JsonKey() final  int toasts;
@override@JsonKey() final  bool youToasted;
// Server-aggregated comment count (Phase 6a). Defaults to 0 so older
// servers (or omitted-key responses) remain wire-compatible. Mirrors
// the same field on FeedItem so the detail screen can render the
// comment badge without a separate `GET /comments` round trip.
@override@JsonKey() final  int commentCount;
@override@JsonKey() final  String createdAt;
@override@JsonKey() final  String updatedAt;

/// Create a copy of Checkin
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CheckinCopyWith<_Checkin> get copyWith => __$CheckinCopyWithImpl<_Checkin>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Checkin&&(identical(other.id, id) || other.id == id)&&(identical(other.user, user) || other.user == user)&&(identical(other.beverage, beverage) || other.beverage == beverage)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.review, review) || other.review == review)&&const DeepCollectionEquality().equals(other._tags, _tags)&&const DeepCollectionEquality().equals(other._photos, _photos)&&(identical(other.price, price) || other.price == price)&&(identical(other.purchaseType, purchaseType) || other.purchaseType == purchaseType)&&(identical(other.venue, venue) || other.venue == venue)&&(identical(other.toasts, toasts) || other.toasts == toasts)&&(identical(other.youToasted, youToasted) || other.youToasted == youToasted)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,user,beverage,rating,review,const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_photos),price,purchaseType,venue,toasts,youToasted,commentCount,createdAt,updatedAt);

@override
String toString() {
  return 'Checkin(id: $id, user: $user, beverage: $beverage, rating: $rating, review: $review, tags: $tags, photos: $photos, price: $price, purchaseType: $purchaseType, venue: $venue, toasts: $toasts, youToasted: $youToasted, commentCount: $commentCount, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$CheckinCopyWith<$Res> implements $CheckinCopyWith<$Res> {
  factory _$CheckinCopyWith(_Checkin value, $Res Function(_Checkin) _then) = __$CheckinCopyWithImpl;
@override @useResult
$Res call({
 String id, CheckinUser user, BeverageRef beverage, double? rating, String? review, List<FlavorTag> tags, List<PhotoRef> photos, Price? price, String? purchaseType, VenueRef? venue, int toasts, bool youToasted, int commentCount, String createdAt, String updatedAt
});


@override $CheckinUserCopyWith<$Res> get user;@override $BeverageRefCopyWith<$Res> get beverage;@override $PriceCopyWith<$Res>? get price;@override $VenueRefCopyWith<$Res>? get venue;

}
/// @nodoc
class __$CheckinCopyWithImpl<$Res>
    implements _$CheckinCopyWith<$Res> {
  __$CheckinCopyWithImpl(this._self, this._then);

  final _Checkin _self;
  final $Res Function(_Checkin) _then;

/// Create a copy of Checkin
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? user = null,Object? beverage = null,Object? rating = freezed,Object? review = freezed,Object? tags = null,Object? photos = null,Object? price = freezed,Object? purchaseType = freezed,Object? venue = freezed,Object? toasts = null,Object? youToasted = null,Object? commentCount = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Checkin(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as CheckinUser,beverage: null == beverage ? _self.beverage : beverage // ignore: cast_nullable_to_non_nullable
as BeverageRef,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,review: freezed == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<FlavorTag>,photos: null == photos ? _self._photos : photos // ignore: cast_nullable_to_non_nullable
as List<PhotoRef>,price: freezed == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as Price?,purchaseType: freezed == purchaseType ? _self.purchaseType : purchaseType // ignore: cast_nullable_to_non_nullable
as String?,venue: freezed == venue ? _self.venue : venue // ignore: cast_nullable_to_non_nullable
as VenueRef?,toasts: null == toasts ? _self.toasts : toasts // ignore: cast_nullable_to_non_nullable
as int,youToasted: null == youToasted ? _self.youToasted : youToasted // ignore: cast_nullable_to_non_nullable
as bool,commentCount: null == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of Checkin
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CheckinUserCopyWith<$Res> get user {
  
  return $CheckinUserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}/// Create a copy of Checkin
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BeverageRefCopyWith<$Res> get beverage {
  
  return $BeverageRefCopyWith<$Res>(_self.beverage, (value) {
    return _then(_self.copyWith(beverage: value));
  });
}/// Create a copy of Checkin
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PriceCopyWith<$Res>? get price {
    if (_self.price == null) {
    return null;
  }

  return $PriceCopyWith<$Res>(_self.price!, (value) {
    return _then(_self.copyWith(price: value));
  });
}/// Create a copy of Checkin
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VenueRefCopyWith<$Res>? get venue {
    if (_self.venue == null) {
    return null;
  }

  return $VenueRefCopyWith<$Res>(_self.venue!, (value) {
    return _then(_self.copyWith(venue: value));
  });
}
}

/// @nodoc
mixin _$FeedItem {

 String get id; CheckinUser get user; BeverageRef get beverage; double? get rating; String? get review; List<FlavorTag> get tags;// Stage 5: the server now hydrates photos[] directly on the feed.
// The card uses photos.length for the count (no separate field).
 List<PhotoRef> get photos; VenueRef? get venue; int get toasts; bool get youToasted;// Server-aggregated comment count. Defaults to 0 so older
// servers (or omitted-key responses) remain wire-compatible.
 int get commentCount; String get createdAt;
/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeedItemCopyWith<FeedItem> get copyWith => _$FeedItemCopyWithImpl<FeedItem>(this as FeedItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedItem&&(identical(other.id, id) || other.id == id)&&(identical(other.user, user) || other.user == user)&&(identical(other.beverage, beverage) || other.beverage == beverage)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.review, review) || other.review == review)&&const DeepCollectionEquality().equals(other.tags, tags)&&const DeepCollectionEquality().equals(other.photos, photos)&&(identical(other.venue, venue) || other.venue == venue)&&(identical(other.toasts, toasts) || other.toasts == toasts)&&(identical(other.youToasted, youToasted) || other.youToasted == youToasted)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,user,beverage,rating,review,const DeepCollectionEquality().hash(tags),const DeepCollectionEquality().hash(photos),venue,toasts,youToasted,commentCount,createdAt);

@override
String toString() {
  return 'FeedItem(id: $id, user: $user, beverage: $beverage, rating: $rating, review: $review, tags: $tags, photos: $photos, venue: $venue, toasts: $toasts, youToasted: $youToasted, commentCount: $commentCount, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $FeedItemCopyWith<$Res>  {
  factory $FeedItemCopyWith(FeedItem value, $Res Function(FeedItem) _then) = _$FeedItemCopyWithImpl;
@useResult
$Res call({
 String id, CheckinUser user, BeverageRef beverage, double? rating, String? review, List<FlavorTag> tags, List<PhotoRef> photos, VenueRef? venue, int toasts, bool youToasted, int commentCount, String createdAt
});


$CheckinUserCopyWith<$Res> get user;$BeverageRefCopyWith<$Res> get beverage;$VenueRefCopyWith<$Res>? get venue;

}
/// @nodoc
class _$FeedItemCopyWithImpl<$Res>
    implements $FeedItemCopyWith<$Res> {
  _$FeedItemCopyWithImpl(this._self, this._then);

  final FeedItem _self;
  final $Res Function(FeedItem) _then;

/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? user = null,Object? beverage = null,Object? rating = freezed,Object? review = freezed,Object? tags = null,Object? photos = null,Object? venue = freezed,Object? toasts = null,Object? youToasted = null,Object? commentCount = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as CheckinUser,beverage: null == beverage ? _self.beverage : beverage // ignore: cast_nullable_to_non_nullable
as BeverageRef,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,review: freezed == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<FlavorTag>,photos: null == photos ? _self.photos : photos // ignore: cast_nullable_to_non_nullable
as List<PhotoRef>,venue: freezed == venue ? _self.venue : venue // ignore: cast_nullable_to_non_nullable
as VenueRef?,toasts: null == toasts ? _self.toasts : toasts // ignore: cast_nullable_to_non_nullable
as int,youToasted: null == youToasted ? _self.youToasted : youToasted // ignore: cast_nullable_to_non_nullable
as bool,commentCount: null == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CheckinUserCopyWith<$Res> get user {
  
  return $CheckinUserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BeverageRefCopyWith<$Res> get beverage {
  
  return $BeverageRefCopyWith<$Res>(_self.beverage, (value) {
    return _then(_self.copyWith(beverage: value));
  });
}/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VenueRefCopyWith<$Res>? get venue {
    if (_self.venue == null) {
    return null;
  }

  return $VenueRefCopyWith<$Res>(_self.venue!, (value) {
    return _then(_self.copyWith(venue: value));
  });
}
}


/// Adds pattern-matching-related methods to [FeedItem].
extension FeedItemPatterns on FeedItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FeedItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FeedItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FeedItem value)  $default,){
final _that = this;
switch (_that) {
case _FeedItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FeedItem value)?  $default,){
final _that = this;
switch (_that) {
case _FeedItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  CheckinUser user,  BeverageRef beverage,  double? rating,  String? review,  List<FlavorTag> tags,  List<PhotoRef> photos,  VenueRef? venue,  int toasts,  bool youToasted,  int commentCount,  String createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FeedItem() when $default != null:
return $default(_that.id,_that.user,_that.beverage,_that.rating,_that.review,_that.tags,_that.photos,_that.venue,_that.toasts,_that.youToasted,_that.commentCount,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  CheckinUser user,  BeverageRef beverage,  double? rating,  String? review,  List<FlavorTag> tags,  List<PhotoRef> photos,  VenueRef? venue,  int toasts,  bool youToasted,  int commentCount,  String createdAt)  $default,) {final _that = this;
switch (_that) {
case _FeedItem():
return $default(_that.id,_that.user,_that.beverage,_that.rating,_that.review,_that.tags,_that.photos,_that.venue,_that.toasts,_that.youToasted,_that.commentCount,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  CheckinUser user,  BeverageRef beverage,  double? rating,  String? review,  List<FlavorTag> tags,  List<PhotoRef> photos,  VenueRef? venue,  int toasts,  bool youToasted,  int commentCount,  String createdAt)?  $default,) {final _that = this;
switch (_that) {
case _FeedItem() when $default != null:
return $default(_that.id,_that.user,_that.beverage,_that.rating,_that.review,_that.tags,_that.photos,_that.venue,_that.toasts,_that.youToasted,_that.commentCount,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _FeedItem extends FeedItem {
  const _FeedItem({required this.id, required this.user, required this.beverage, this.rating, this.review, final  List<FlavorTag> tags = const <FlavorTag>[], final  List<PhotoRef> photos = const <PhotoRef>[], this.venue, this.toasts = 0, this.youToasted = false, this.commentCount = 0, this.createdAt = ''}): _tags = tags,_photos = photos,super._();
  

@override final  String id;
@override final  CheckinUser user;
@override final  BeverageRef beverage;
@override final  double? rating;
@override final  String? review;
 final  List<FlavorTag> _tags;
@override@JsonKey() List<FlavorTag> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

// Stage 5: the server now hydrates photos[] directly on the feed.
// The card uses photos.length for the count (no separate field).
 final  List<PhotoRef> _photos;
// Stage 5: the server now hydrates photos[] directly on the feed.
// The card uses photos.length for the count (no separate field).
@override@JsonKey() List<PhotoRef> get photos {
  if (_photos is EqualUnmodifiableListView) return _photos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_photos);
}

@override final  VenueRef? venue;
@override@JsonKey() final  int toasts;
@override@JsonKey() final  bool youToasted;
// Server-aggregated comment count. Defaults to 0 so older
// servers (or omitted-key responses) remain wire-compatible.
@override@JsonKey() final  int commentCount;
@override@JsonKey() final  String createdAt;

/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FeedItemCopyWith<_FeedItem> get copyWith => __$FeedItemCopyWithImpl<_FeedItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FeedItem&&(identical(other.id, id) || other.id == id)&&(identical(other.user, user) || other.user == user)&&(identical(other.beverage, beverage) || other.beverage == beverage)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.review, review) || other.review == review)&&const DeepCollectionEquality().equals(other._tags, _tags)&&const DeepCollectionEquality().equals(other._photos, _photos)&&(identical(other.venue, venue) || other.venue == venue)&&(identical(other.toasts, toasts) || other.toasts == toasts)&&(identical(other.youToasted, youToasted) || other.youToasted == youToasted)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,user,beverage,rating,review,const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_photos),venue,toasts,youToasted,commentCount,createdAt);

@override
String toString() {
  return 'FeedItem(id: $id, user: $user, beverage: $beverage, rating: $rating, review: $review, tags: $tags, photos: $photos, venue: $venue, toasts: $toasts, youToasted: $youToasted, commentCount: $commentCount, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$FeedItemCopyWith<$Res> implements $FeedItemCopyWith<$Res> {
  factory _$FeedItemCopyWith(_FeedItem value, $Res Function(_FeedItem) _then) = __$FeedItemCopyWithImpl;
@override @useResult
$Res call({
 String id, CheckinUser user, BeverageRef beverage, double? rating, String? review, List<FlavorTag> tags, List<PhotoRef> photos, VenueRef? venue, int toasts, bool youToasted, int commentCount, String createdAt
});


@override $CheckinUserCopyWith<$Res> get user;@override $BeverageRefCopyWith<$Res> get beverage;@override $VenueRefCopyWith<$Res>? get venue;

}
/// @nodoc
class __$FeedItemCopyWithImpl<$Res>
    implements _$FeedItemCopyWith<$Res> {
  __$FeedItemCopyWithImpl(this._self, this._then);

  final _FeedItem _self;
  final $Res Function(_FeedItem) _then;

/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? user = null,Object? beverage = null,Object? rating = freezed,Object? review = freezed,Object? tags = null,Object? photos = null,Object? venue = freezed,Object? toasts = null,Object? youToasted = null,Object? commentCount = null,Object? createdAt = null,}) {
  return _then(_FeedItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as CheckinUser,beverage: null == beverage ? _self.beverage : beverage // ignore: cast_nullable_to_non_nullable
as BeverageRef,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,review: freezed == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<FlavorTag>,photos: null == photos ? _self._photos : photos // ignore: cast_nullable_to_non_nullable
as List<PhotoRef>,venue: freezed == venue ? _self.venue : venue // ignore: cast_nullable_to_non_nullable
as VenueRef?,toasts: null == toasts ? _self.toasts : toasts // ignore: cast_nullable_to_non_nullable
as int,youToasted: null == youToasted ? _self.youToasted : youToasted // ignore: cast_nullable_to_non_nullable
as bool,commentCount: null == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CheckinUserCopyWith<$Res> get user {
  
  return $CheckinUserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BeverageRefCopyWith<$Res> get beverage {
  
  return $BeverageRefCopyWith<$Res>(_self.beverage, (value) {
    return _then(_self.copyWith(beverage: value));
  });
}/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VenueRefCopyWith<$Res>? get venue {
    if (_self.venue == null) {
    return null;
  }

  return $VenueRefCopyWith<$Res>(_self.venue!, (value) {
    return _then(_self.copyWith(venue: value));
  });
}
}

/// @nodoc
mixin _$ToastState {

 int get toasts; bool get youToasted;
/// Create a copy of ToastState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToastStateCopyWith<ToastState> get copyWith => _$ToastStateCopyWithImpl<ToastState>(this as ToastState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToastState&&(identical(other.toasts, toasts) || other.toasts == toasts)&&(identical(other.youToasted, youToasted) || other.youToasted == youToasted));
}


@override
int get hashCode => Object.hash(runtimeType,toasts,youToasted);

@override
String toString() {
  return 'ToastState(toasts: $toasts, youToasted: $youToasted)';
}


}

/// @nodoc
abstract mixin class $ToastStateCopyWith<$Res>  {
  factory $ToastStateCopyWith(ToastState value, $Res Function(ToastState) _then) = _$ToastStateCopyWithImpl;
@useResult
$Res call({
 int toasts, bool youToasted
});




}
/// @nodoc
class _$ToastStateCopyWithImpl<$Res>
    implements $ToastStateCopyWith<$Res> {
  _$ToastStateCopyWithImpl(this._self, this._then);

  final ToastState _self;
  final $Res Function(ToastState) _then;

/// Create a copy of ToastState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? toasts = null,Object? youToasted = null,}) {
  return _then(_self.copyWith(
toasts: null == toasts ? _self.toasts : toasts // ignore: cast_nullable_to_non_nullable
as int,youToasted: null == youToasted ? _self.youToasted : youToasted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ToastState].
extension ToastStatePatterns on ToastState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ToastState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ToastState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ToastState value)  $default,){
final _that = this;
switch (_that) {
case _ToastState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ToastState value)?  $default,){
final _that = this;
switch (_that) {
case _ToastState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int toasts,  bool youToasted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ToastState() when $default != null:
return $default(_that.toasts,_that.youToasted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int toasts,  bool youToasted)  $default,) {final _that = this;
switch (_that) {
case _ToastState():
return $default(_that.toasts,_that.youToasted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int toasts,  bool youToasted)?  $default,) {final _that = this;
switch (_that) {
case _ToastState() when $default != null:
return $default(_that.toasts,_that.youToasted);case _:
  return null;

}
}

}

/// @nodoc


class _ToastState implements ToastState {
  const _ToastState({this.toasts = 0, this.youToasted = false});
  

@override@JsonKey() final  int toasts;
@override@JsonKey() final  bool youToasted;

/// Create a copy of ToastState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ToastStateCopyWith<_ToastState> get copyWith => __$ToastStateCopyWithImpl<_ToastState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ToastState&&(identical(other.toasts, toasts) || other.toasts == toasts)&&(identical(other.youToasted, youToasted) || other.youToasted == youToasted));
}


@override
int get hashCode => Object.hash(runtimeType,toasts,youToasted);

@override
String toString() {
  return 'ToastState(toasts: $toasts, youToasted: $youToasted)';
}


}

/// @nodoc
abstract mixin class _$ToastStateCopyWith<$Res> implements $ToastStateCopyWith<$Res> {
  factory _$ToastStateCopyWith(_ToastState value, $Res Function(_ToastState) _then) = __$ToastStateCopyWithImpl;
@override @useResult
$Res call({
 int toasts, bool youToasted
});




}
/// @nodoc
class __$ToastStateCopyWithImpl<$Res>
    implements _$ToastStateCopyWith<$Res> {
  __$ToastStateCopyWithImpl(this._self, this._then);

  final _ToastState _self;
  final $Res Function(_ToastState) _then;

/// Create a copy of ToastState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? toasts = null,Object? youToasted = null,}) {
  return _then(_ToastState(
toasts: null == toasts ? _self.toasts : toasts // ignore: cast_nullable_to_non_nullable
as int,youToasted: null == youToasted ? _self.youToasted : youToasted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
