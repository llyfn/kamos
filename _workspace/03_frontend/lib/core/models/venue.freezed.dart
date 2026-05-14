// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'venue.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Venue {

 String get id; String get name; String? get foursquareId; String? get address; double? get lat; double? get lng; String? get country; String? get prefecture; String? get locality;
/// Create a copy of Venue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VenueCopyWith<Venue> get copyWith => _$VenueCopyWithImpl<Venue>(this as Venue, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Venue&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.foursquareId, foursquareId) || other.foursquareId == foursquareId)&&(identical(other.address, address) || other.address == address)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.country, country) || other.country == country)&&(identical(other.prefecture, prefecture) || other.prefecture == prefecture)&&(identical(other.locality, locality) || other.locality == locality));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,foursquareId,address,lat,lng,country,prefecture,locality);

@override
String toString() {
  return 'Venue(id: $id, name: $name, foursquareId: $foursquareId, address: $address, lat: $lat, lng: $lng, country: $country, prefecture: $prefecture, locality: $locality)';
}


}

/// @nodoc
abstract mixin class $VenueCopyWith<$Res>  {
  factory $VenueCopyWith(Venue value, $Res Function(Venue) _then) = _$VenueCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? foursquareId, String? address, double? lat, double? lng, String? country, String? prefecture, String? locality
});




}
/// @nodoc
class _$VenueCopyWithImpl<$Res>
    implements $VenueCopyWith<$Res> {
  _$VenueCopyWithImpl(this._self, this._then);

  final Venue _self;
  final $Res Function(Venue) _then;

/// Create a copy of Venue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? foursquareId = freezed,Object? address = freezed,Object? lat = freezed,Object? lng = freezed,Object? country = freezed,Object? prefecture = freezed,Object? locality = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,foursquareId: freezed == foursquareId ? _self.foursquareId : foursquareId // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lng: freezed == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,prefecture: freezed == prefecture ? _self.prefecture : prefecture // ignore: cast_nullable_to_non_nullable
as String?,locality: freezed == locality ? _self.locality : locality // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Venue].
extension VenuePatterns on Venue {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Venue value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Venue() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Venue value)  $default,){
final _that = this;
switch (_that) {
case _Venue():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Venue value)?  $default,){
final _that = this;
switch (_that) {
case _Venue() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? foursquareId,  String? address,  double? lat,  double? lng,  String? country,  String? prefecture,  String? locality)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Venue() when $default != null:
return $default(_that.id,_that.name,_that.foursquareId,_that.address,_that.lat,_that.lng,_that.country,_that.prefecture,_that.locality);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? foursquareId,  String? address,  double? lat,  double? lng,  String? country,  String? prefecture,  String? locality)  $default,) {final _that = this;
switch (_that) {
case _Venue():
return $default(_that.id,_that.name,_that.foursquareId,_that.address,_that.lat,_that.lng,_that.country,_that.prefecture,_that.locality);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? foursquareId,  String? address,  double? lat,  double? lng,  String? country,  String? prefecture,  String? locality)?  $default,) {final _that = this;
switch (_that) {
case _Venue() when $default != null:
return $default(_that.id,_that.name,_that.foursquareId,_that.address,_that.lat,_that.lng,_that.country,_that.prefecture,_that.locality);case _:
  return null;

}
}

}

/// @nodoc


class _Venue implements Venue {
  const _Venue({required this.id, required this.name, this.foursquareId, this.address, this.lat, this.lng, this.country, this.prefecture, this.locality});
  

@override final  String id;
@override final  String name;
@override final  String? foursquareId;
@override final  String? address;
@override final  double? lat;
@override final  double? lng;
@override final  String? country;
@override final  String? prefecture;
@override final  String? locality;

/// Create a copy of Venue
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VenueCopyWith<_Venue> get copyWith => __$VenueCopyWithImpl<_Venue>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Venue&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.foursquareId, foursquareId) || other.foursquareId == foursquareId)&&(identical(other.address, address) || other.address == address)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.country, country) || other.country == country)&&(identical(other.prefecture, prefecture) || other.prefecture == prefecture)&&(identical(other.locality, locality) || other.locality == locality));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,foursquareId,address,lat,lng,country,prefecture,locality);

@override
String toString() {
  return 'Venue(id: $id, name: $name, foursquareId: $foursquareId, address: $address, lat: $lat, lng: $lng, country: $country, prefecture: $prefecture, locality: $locality)';
}


}

/// @nodoc
abstract mixin class _$VenueCopyWith<$Res> implements $VenueCopyWith<$Res> {
  factory _$VenueCopyWith(_Venue value, $Res Function(_Venue) _then) = __$VenueCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? foursquareId, String? address, double? lat, double? lng, String? country, String? prefecture, String? locality
});




}
/// @nodoc
class __$VenueCopyWithImpl<$Res>
    implements _$VenueCopyWith<$Res> {
  __$VenueCopyWithImpl(this._self, this._then);

  final _Venue _self;
  final $Res Function(_Venue) _then;

/// Create a copy of Venue
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? foursquareId = freezed,Object? address = freezed,Object? lat = freezed,Object? lng = freezed,Object? country = freezed,Object? prefecture = freezed,Object? locality = freezed,}) {
  return _then(_Venue(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,foursquareId: freezed == foursquareId ? _self.foursquareId : foursquareId // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lng: freezed == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,prefecture: freezed == prefecture ? _self.prefecture : prefecture // ignore: cast_nullable_to_non_nullable
as String?,locality: freezed == locality ? _self.locality : locality // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$VenueRef {

 String get id; String get name; String? get locality; String? get country;
/// Create a copy of VenueRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VenueRefCopyWith<VenueRef> get copyWith => _$VenueRefCopyWithImpl<VenueRef>(this as VenueRef, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VenueRef&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.locality, locality) || other.locality == locality)&&(identical(other.country, country) || other.country == country));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,locality,country);

@override
String toString() {
  return 'VenueRef(id: $id, name: $name, locality: $locality, country: $country)';
}


}

/// @nodoc
abstract mixin class $VenueRefCopyWith<$Res>  {
  factory $VenueRefCopyWith(VenueRef value, $Res Function(VenueRef) _then) = _$VenueRefCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? locality, String? country
});




}
/// @nodoc
class _$VenueRefCopyWithImpl<$Res>
    implements $VenueRefCopyWith<$Res> {
  _$VenueRefCopyWithImpl(this._self, this._then);

  final VenueRef _self;
  final $Res Function(VenueRef) _then;

/// Create a copy of VenueRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? locality = freezed,Object? country = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,locality: freezed == locality ? _self.locality : locality // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VenueRef].
extension VenueRefPatterns on VenueRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VenueRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VenueRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VenueRef value)  $default,){
final _that = this;
switch (_that) {
case _VenueRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VenueRef value)?  $default,){
final _that = this;
switch (_that) {
case _VenueRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? locality,  String? country)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VenueRef() when $default != null:
return $default(_that.id,_that.name,_that.locality,_that.country);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? locality,  String? country)  $default,) {final _that = this;
switch (_that) {
case _VenueRef():
return $default(_that.id,_that.name,_that.locality,_that.country);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? locality,  String? country)?  $default,) {final _that = this;
switch (_that) {
case _VenueRef() when $default != null:
return $default(_that.id,_that.name,_that.locality,_that.country);case _:
  return null;

}
}

}

/// @nodoc


class _VenueRef implements VenueRef {
  const _VenueRef({required this.id, required this.name, this.locality, this.country});
  

@override final  String id;
@override final  String name;
@override final  String? locality;
@override final  String? country;

/// Create a copy of VenueRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VenueRefCopyWith<_VenueRef> get copyWith => __$VenueRefCopyWithImpl<_VenueRef>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VenueRef&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.locality, locality) || other.locality == locality)&&(identical(other.country, country) || other.country == country));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,locality,country);

@override
String toString() {
  return 'VenueRef(id: $id, name: $name, locality: $locality, country: $country)';
}


}

/// @nodoc
abstract mixin class _$VenueRefCopyWith<$Res> implements $VenueRefCopyWith<$Res> {
  factory _$VenueRefCopyWith(_VenueRef value, $Res Function(_VenueRef) _then) = __$VenueRefCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? locality, String? country
});




}
/// @nodoc
class __$VenueRefCopyWithImpl<$Res>
    implements _$VenueRefCopyWith<$Res> {
  __$VenueRefCopyWithImpl(this._self, this._then);

  final _VenueRef _self;
  final $Res Function(_VenueRef) _then;

/// Create a copy of VenueRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? locality = freezed,Object? country = freezed,}) {
  return _then(_VenueRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,locality: freezed == locality ? _self.locality : locality // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$FoursquarePlace {

 String get foursquareId; String get name; String? get address; double? get lat; double? get lng; String? get country; String? get prefecture; String? get locality;
/// Create a copy of FoursquarePlace
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FoursquarePlaceCopyWith<FoursquarePlace> get copyWith => _$FoursquarePlaceCopyWithImpl<FoursquarePlace>(this as FoursquarePlace, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FoursquarePlace&&(identical(other.foursquareId, foursquareId) || other.foursquareId == foursquareId)&&(identical(other.name, name) || other.name == name)&&(identical(other.address, address) || other.address == address)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.country, country) || other.country == country)&&(identical(other.prefecture, prefecture) || other.prefecture == prefecture)&&(identical(other.locality, locality) || other.locality == locality));
}


@override
int get hashCode => Object.hash(runtimeType,foursquareId,name,address,lat,lng,country,prefecture,locality);

@override
String toString() {
  return 'FoursquarePlace(foursquareId: $foursquareId, name: $name, address: $address, lat: $lat, lng: $lng, country: $country, prefecture: $prefecture, locality: $locality)';
}


}

/// @nodoc
abstract mixin class $FoursquarePlaceCopyWith<$Res>  {
  factory $FoursquarePlaceCopyWith(FoursquarePlace value, $Res Function(FoursquarePlace) _then) = _$FoursquarePlaceCopyWithImpl;
@useResult
$Res call({
 String foursquareId, String name, String? address, double? lat, double? lng, String? country, String? prefecture, String? locality
});




}
/// @nodoc
class _$FoursquarePlaceCopyWithImpl<$Res>
    implements $FoursquarePlaceCopyWith<$Res> {
  _$FoursquarePlaceCopyWithImpl(this._self, this._then);

  final FoursquarePlace _self;
  final $Res Function(FoursquarePlace) _then;

/// Create a copy of FoursquarePlace
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? foursquareId = null,Object? name = null,Object? address = freezed,Object? lat = freezed,Object? lng = freezed,Object? country = freezed,Object? prefecture = freezed,Object? locality = freezed,}) {
  return _then(_self.copyWith(
foursquareId: null == foursquareId ? _self.foursquareId : foursquareId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lng: freezed == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,prefecture: freezed == prefecture ? _self.prefecture : prefecture // ignore: cast_nullable_to_non_nullable
as String?,locality: freezed == locality ? _self.locality : locality // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FoursquarePlace].
extension FoursquarePlacePatterns on FoursquarePlace {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FoursquarePlace value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FoursquarePlace() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FoursquarePlace value)  $default,){
final _that = this;
switch (_that) {
case _FoursquarePlace():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FoursquarePlace value)?  $default,){
final _that = this;
switch (_that) {
case _FoursquarePlace() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String foursquareId,  String name,  String? address,  double? lat,  double? lng,  String? country,  String? prefecture,  String? locality)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FoursquarePlace() when $default != null:
return $default(_that.foursquareId,_that.name,_that.address,_that.lat,_that.lng,_that.country,_that.prefecture,_that.locality);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String foursquareId,  String name,  String? address,  double? lat,  double? lng,  String? country,  String? prefecture,  String? locality)  $default,) {final _that = this;
switch (_that) {
case _FoursquarePlace():
return $default(_that.foursquareId,_that.name,_that.address,_that.lat,_that.lng,_that.country,_that.prefecture,_that.locality);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String foursquareId,  String name,  String? address,  double? lat,  double? lng,  String? country,  String? prefecture,  String? locality)?  $default,) {final _that = this;
switch (_that) {
case _FoursquarePlace() when $default != null:
return $default(_that.foursquareId,_that.name,_that.address,_that.lat,_that.lng,_that.country,_that.prefecture,_that.locality);case _:
  return null;

}
}

}

/// @nodoc


class _FoursquarePlace extends FoursquarePlace {
  const _FoursquarePlace({required this.foursquareId, required this.name, this.address, this.lat, this.lng, this.country, this.prefecture, this.locality}): super._();
  

@override final  String foursquareId;
@override final  String name;
@override final  String? address;
@override final  double? lat;
@override final  double? lng;
@override final  String? country;
@override final  String? prefecture;
@override final  String? locality;

/// Create a copy of FoursquarePlace
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FoursquarePlaceCopyWith<_FoursquarePlace> get copyWith => __$FoursquarePlaceCopyWithImpl<_FoursquarePlace>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FoursquarePlace&&(identical(other.foursquareId, foursquareId) || other.foursquareId == foursquareId)&&(identical(other.name, name) || other.name == name)&&(identical(other.address, address) || other.address == address)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.country, country) || other.country == country)&&(identical(other.prefecture, prefecture) || other.prefecture == prefecture)&&(identical(other.locality, locality) || other.locality == locality));
}


@override
int get hashCode => Object.hash(runtimeType,foursquareId,name,address,lat,lng,country,prefecture,locality);

@override
String toString() {
  return 'FoursquarePlace(foursquareId: $foursquareId, name: $name, address: $address, lat: $lat, lng: $lng, country: $country, prefecture: $prefecture, locality: $locality)';
}


}

/// @nodoc
abstract mixin class _$FoursquarePlaceCopyWith<$Res> implements $FoursquarePlaceCopyWith<$Res> {
  factory _$FoursquarePlaceCopyWith(_FoursquarePlace value, $Res Function(_FoursquarePlace) _then) = __$FoursquarePlaceCopyWithImpl;
@override @useResult
$Res call({
 String foursquareId, String name, String? address, double? lat, double? lng, String? country, String? prefecture, String? locality
});




}
/// @nodoc
class __$FoursquarePlaceCopyWithImpl<$Res>
    implements _$FoursquarePlaceCopyWith<$Res> {
  __$FoursquarePlaceCopyWithImpl(this._self, this._then);

  final _FoursquarePlace _self;
  final $Res Function(_FoursquarePlace) _then;

/// Create a copy of FoursquarePlace
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? foursquareId = null,Object? name = null,Object? address = freezed,Object? lat = freezed,Object? lng = freezed,Object? country = freezed,Object? prefecture = freezed,Object? locality = freezed,}) {
  return _then(_FoursquarePlace(
foursquareId: null == foursquareId ? _self.foursquareId : foursquareId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lng: freezed == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,prefecture: freezed == prefecture ? _self.prefecture : prefecture // ignore: cast_nullable_to_non_nullable
as String?,locality: freezed == locality ? _self.locality : locality // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
