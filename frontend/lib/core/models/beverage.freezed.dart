// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'beverage.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Beverage {

 String get id; I18nText get name; Brewery get brewery; CategoryLabel get category; I18nText? get subcategory; double? get abv; int? get polishingRatio; String? get prefecture; String? get region; List<String> get flavorProfile; I18nText? get description; String? get labelImageUrl; double? get avgRating; int get checkInCount; String get createdAt;
/// Create a copy of Beverage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BeverageCopyWith<Beverage> get copyWith => _$BeverageCopyWithImpl<Beverage>(this as Beverage, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Beverage&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.brewery, brewery) || other.brewery == brewery)&&(identical(other.category, category) || other.category == category)&&(identical(other.subcategory, subcategory) || other.subcategory == subcategory)&&(identical(other.abv, abv) || other.abv == abv)&&(identical(other.polishingRatio, polishingRatio) || other.polishingRatio == polishingRatio)&&(identical(other.prefecture, prefecture) || other.prefecture == prefecture)&&(identical(other.region, region) || other.region == region)&&const DeepCollectionEquality().equals(other.flavorProfile, flavorProfile)&&(identical(other.description, description) || other.description == description)&&(identical(other.labelImageUrl, labelImageUrl) || other.labelImageUrl == labelImageUrl)&&(identical(other.avgRating, avgRating) || other.avgRating == avgRating)&&(identical(other.checkInCount, checkInCount) || other.checkInCount == checkInCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,brewery,category,subcategory,abv,polishingRatio,prefecture,region,const DeepCollectionEquality().hash(flavorProfile),description,labelImageUrl,avgRating,checkInCount,createdAt);

@override
String toString() {
  return 'Beverage(id: $id, name: $name, brewery: $brewery, category: $category, subcategory: $subcategory, abv: $abv, polishingRatio: $polishingRatio, prefecture: $prefecture, region: $region, flavorProfile: $flavorProfile, description: $description, labelImageUrl: $labelImageUrl, avgRating: $avgRating, checkInCount: $checkInCount, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $BeverageCopyWith<$Res>  {
  factory $BeverageCopyWith(Beverage value, $Res Function(Beverage) _then) = _$BeverageCopyWithImpl;
@useResult
$Res call({
 String id, I18nText name, Brewery brewery, CategoryLabel category, I18nText? subcategory, double? abv, int? polishingRatio, String? prefecture, String? region, List<String> flavorProfile, I18nText? description, String? labelImageUrl, double? avgRating, int checkInCount, String createdAt
});


$I18nTextCopyWith<$Res> get name;$BreweryCopyWith<$Res> get brewery;$CategoryLabelCopyWith<$Res> get category;$I18nTextCopyWith<$Res>? get subcategory;$I18nTextCopyWith<$Res>? get description;

}
/// @nodoc
class _$BeverageCopyWithImpl<$Res>
    implements $BeverageCopyWith<$Res> {
  _$BeverageCopyWithImpl(this._self, this._then);

  final Beverage _self;
  final $Res Function(Beverage) _then;

/// Create a copy of Beverage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? brewery = null,Object? category = null,Object? subcategory = freezed,Object? abv = freezed,Object? polishingRatio = freezed,Object? prefecture = freezed,Object? region = freezed,Object? flavorProfile = null,Object? description = freezed,Object? labelImageUrl = freezed,Object? avgRating = freezed,Object? checkInCount = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as I18nText,brewery: null == brewery ? _self.brewery : brewery // ignore: cast_nullable_to_non_nullable
as Brewery,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as CategoryLabel,subcategory: freezed == subcategory ? _self.subcategory : subcategory // ignore: cast_nullable_to_non_nullable
as I18nText?,abv: freezed == abv ? _self.abv : abv // ignore: cast_nullable_to_non_nullable
as double?,polishingRatio: freezed == polishingRatio ? _self.polishingRatio : polishingRatio // ignore: cast_nullable_to_non_nullable
as int?,prefecture: freezed == prefecture ? _self.prefecture : prefecture // ignore: cast_nullable_to_non_nullable
as String?,region: freezed == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String?,flavorProfile: null == flavorProfile ? _self.flavorProfile : flavorProfile // ignore: cast_nullable_to_non_nullable
as List<String>,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as I18nText?,labelImageUrl: freezed == labelImageUrl ? _self.labelImageUrl : labelImageUrl // ignore: cast_nullable_to_non_nullable
as String?,avgRating: freezed == avgRating ? _self.avgRating : avgRating // ignore: cast_nullable_to_non_nullable
as double?,checkInCount: null == checkInCount ? _self.checkInCount : checkInCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of Beverage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res> get name {
  
  return $I18nTextCopyWith<$Res>(_self.name, (value) {
    return _then(_self.copyWith(name: value));
  });
}/// Create a copy of Beverage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BreweryCopyWith<$Res> get brewery {
  
  return $BreweryCopyWith<$Res>(_self.brewery, (value) {
    return _then(_self.copyWith(brewery: value));
  });
}/// Create a copy of Beverage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CategoryLabelCopyWith<$Res> get category {
  
  return $CategoryLabelCopyWith<$Res>(_self.category, (value) {
    return _then(_self.copyWith(category: value));
  });
}/// Create a copy of Beverage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res>? get subcategory {
    if (_self.subcategory == null) {
    return null;
  }

  return $I18nTextCopyWith<$Res>(_self.subcategory!, (value) {
    return _then(_self.copyWith(subcategory: value));
  });
}/// Create a copy of Beverage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res>? get description {
    if (_self.description == null) {
    return null;
  }

  return $I18nTextCopyWith<$Res>(_self.description!, (value) {
    return _then(_self.copyWith(description: value));
  });
}
}


/// Adds pattern-matching-related methods to [Beverage].
extension BeveragePatterns on Beverage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Beverage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Beverage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Beverage value)  $default,){
final _that = this;
switch (_that) {
case _Beverage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Beverage value)?  $default,){
final _that = this;
switch (_that) {
case _Beverage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  I18nText name,  Brewery brewery,  CategoryLabel category,  I18nText? subcategory,  double? abv,  int? polishingRatio,  String? prefecture,  String? region,  List<String> flavorProfile,  I18nText? description,  String? labelImageUrl,  double? avgRating,  int checkInCount,  String createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Beverage() when $default != null:
return $default(_that.id,_that.name,_that.brewery,_that.category,_that.subcategory,_that.abv,_that.polishingRatio,_that.prefecture,_that.region,_that.flavorProfile,_that.description,_that.labelImageUrl,_that.avgRating,_that.checkInCount,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  I18nText name,  Brewery brewery,  CategoryLabel category,  I18nText? subcategory,  double? abv,  int? polishingRatio,  String? prefecture,  String? region,  List<String> flavorProfile,  I18nText? description,  String? labelImageUrl,  double? avgRating,  int checkInCount,  String createdAt)  $default,) {final _that = this;
switch (_that) {
case _Beverage():
return $default(_that.id,_that.name,_that.brewery,_that.category,_that.subcategory,_that.abv,_that.polishingRatio,_that.prefecture,_that.region,_that.flavorProfile,_that.description,_that.labelImageUrl,_that.avgRating,_that.checkInCount,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  I18nText name,  Brewery brewery,  CategoryLabel category,  I18nText? subcategory,  double? abv,  int? polishingRatio,  String? prefecture,  String? region,  List<String> flavorProfile,  I18nText? description,  String? labelImageUrl,  double? avgRating,  int checkInCount,  String createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Beverage() when $default != null:
return $default(_that.id,_that.name,_that.brewery,_that.category,_that.subcategory,_that.abv,_that.polishingRatio,_that.prefecture,_that.region,_that.flavorProfile,_that.description,_that.labelImageUrl,_that.avgRating,_that.checkInCount,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _Beverage implements Beverage {
  const _Beverage({required this.id, required this.name, required this.brewery, required this.category, this.subcategory, this.abv, this.polishingRatio, this.prefecture, this.region, final  List<String> flavorProfile = const <String>[], this.description, this.labelImageUrl, this.avgRating, this.checkInCount = 0, this.createdAt = ''}): _flavorProfile = flavorProfile;
  

@override final  String id;
@override final  I18nText name;
@override final  Brewery brewery;
@override final  CategoryLabel category;
@override final  I18nText? subcategory;
@override final  double? abv;
@override final  int? polishingRatio;
@override final  String? prefecture;
@override final  String? region;
 final  List<String> _flavorProfile;
@override@JsonKey() List<String> get flavorProfile {
  if (_flavorProfile is EqualUnmodifiableListView) return _flavorProfile;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_flavorProfile);
}

@override final  I18nText? description;
@override final  String? labelImageUrl;
@override final  double? avgRating;
@override@JsonKey() final  int checkInCount;
@override@JsonKey() final  String createdAt;

/// Create a copy of Beverage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BeverageCopyWith<_Beverage> get copyWith => __$BeverageCopyWithImpl<_Beverage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Beverage&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.brewery, brewery) || other.brewery == brewery)&&(identical(other.category, category) || other.category == category)&&(identical(other.subcategory, subcategory) || other.subcategory == subcategory)&&(identical(other.abv, abv) || other.abv == abv)&&(identical(other.polishingRatio, polishingRatio) || other.polishingRatio == polishingRatio)&&(identical(other.prefecture, prefecture) || other.prefecture == prefecture)&&(identical(other.region, region) || other.region == region)&&const DeepCollectionEquality().equals(other._flavorProfile, _flavorProfile)&&(identical(other.description, description) || other.description == description)&&(identical(other.labelImageUrl, labelImageUrl) || other.labelImageUrl == labelImageUrl)&&(identical(other.avgRating, avgRating) || other.avgRating == avgRating)&&(identical(other.checkInCount, checkInCount) || other.checkInCount == checkInCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,brewery,category,subcategory,abv,polishingRatio,prefecture,region,const DeepCollectionEquality().hash(_flavorProfile),description,labelImageUrl,avgRating,checkInCount,createdAt);

@override
String toString() {
  return 'Beverage(id: $id, name: $name, brewery: $brewery, category: $category, subcategory: $subcategory, abv: $abv, polishingRatio: $polishingRatio, prefecture: $prefecture, region: $region, flavorProfile: $flavorProfile, description: $description, labelImageUrl: $labelImageUrl, avgRating: $avgRating, checkInCount: $checkInCount, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$BeverageCopyWith<$Res> implements $BeverageCopyWith<$Res> {
  factory _$BeverageCopyWith(_Beverage value, $Res Function(_Beverage) _then) = __$BeverageCopyWithImpl;
@override @useResult
$Res call({
 String id, I18nText name, Brewery brewery, CategoryLabel category, I18nText? subcategory, double? abv, int? polishingRatio, String? prefecture, String? region, List<String> flavorProfile, I18nText? description, String? labelImageUrl, double? avgRating, int checkInCount, String createdAt
});


@override $I18nTextCopyWith<$Res> get name;@override $BreweryCopyWith<$Res> get brewery;@override $CategoryLabelCopyWith<$Res> get category;@override $I18nTextCopyWith<$Res>? get subcategory;@override $I18nTextCopyWith<$Res>? get description;

}
/// @nodoc
class __$BeverageCopyWithImpl<$Res>
    implements _$BeverageCopyWith<$Res> {
  __$BeverageCopyWithImpl(this._self, this._then);

  final _Beverage _self;
  final $Res Function(_Beverage) _then;

/// Create a copy of Beverage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? brewery = null,Object? category = null,Object? subcategory = freezed,Object? abv = freezed,Object? polishingRatio = freezed,Object? prefecture = freezed,Object? region = freezed,Object? flavorProfile = null,Object? description = freezed,Object? labelImageUrl = freezed,Object? avgRating = freezed,Object? checkInCount = null,Object? createdAt = null,}) {
  return _then(_Beverage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as I18nText,brewery: null == brewery ? _self.brewery : brewery // ignore: cast_nullable_to_non_nullable
as Brewery,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as CategoryLabel,subcategory: freezed == subcategory ? _self.subcategory : subcategory // ignore: cast_nullable_to_non_nullable
as I18nText?,abv: freezed == abv ? _self.abv : abv // ignore: cast_nullable_to_non_nullable
as double?,polishingRatio: freezed == polishingRatio ? _self.polishingRatio : polishingRatio // ignore: cast_nullable_to_non_nullable
as int?,prefecture: freezed == prefecture ? _self.prefecture : prefecture // ignore: cast_nullable_to_non_nullable
as String?,region: freezed == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String?,flavorProfile: null == flavorProfile ? _self._flavorProfile : flavorProfile // ignore: cast_nullable_to_non_nullable
as List<String>,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as I18nText?,labelImageUrl: freezed == labelImageUrl ? _self.labelImageUrl : labelImageUrl // ignore: cast_nullable_to_non_nullable
as String?,avgRating: freezed == avgRating ? _self.avgRating : avgRating // ignore: cast_nullable_to_non_nullable
as double?,checkInCount: null == checkInCount ? _self.checkInCount : checkInCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of Beverage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res> get name {
  
  return $I18nTextCopyWith<$Res>(_self.name, (value) {
    return _then(_self.copyWith(name: value));
  });
}/// Create a copy of Beverage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BreweryCopyWith<$Res> get brewery {
  
  return $BreweryCopyWith<$Res>(_self.brewery, (value) {
    return _then(_self.copyWith(brewery: value));
  });
}/// Create a copy of Beverage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CategoryLabelCopyWith<$Res> get category {
  
  return $CategoryLabelCopyWith<$Res>(_self.category, (value) {
    return _then(_self.copyWith(category: value));
  });
}/// Create a copy of Beverage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res>? get subcategory {
    if (_self.subcategory == null) {
    return null;
  }

  return $I18nTextCopyWith<$Res>(_self.subcategory!, (value) {
    return _then(_self.copyWith(subcategory: value));
  });
}/// Create a copy of Beverage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res>? get description {
    if (_self.description == null) {
    return null;
  }

  return $I18nTextCopyWith<$Res>(_self.description!, (value) {
    return _then(_self.copyWith(description: value));
  });
}
}

/// @nodoc
mixin _$BeverageRef {

 String get id; I18nText get name; BreweryRef get brewery; CategoryLabel get category; String? get labelImageUrl;
/// Create a copy of BeverageRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BeverageRefCopyWith<BeverageRef> get copyWith => _$BeverageRefCopyWithImpl<BeverageRef>(this as BeverageRef, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BeverageRef&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.brewery, brewery) || other.brewery == brewery)&&(identical(other.category, category) || other.category == category)&&(identical(other.labelImageUrl, labelImageUrl) || other.labelImageUrl == labelImageUrl));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,brewery,category,labelImageUrl);

@override
String toString() {
  return 'BeverageRef(id: $id, name: $name, brewery: $brewery, category: $category, labelImageUrl: $labelImageUrl)';
}


}

/// @nodoc
abstract mixin class $BeverageRefCopyWith<$Res>  {
  factory $BeverageRefCopyWith(BeverageRef value, $Res Function(BeverageRef) _then) = _$BeverageRefCopyWithImpl;
@useResult
$Res call({
 String id, I18nText name, BreweryRef brewery, CategoryLabel category, String? labelImageUrl
});


$I18nTextCopyWith<$Res> get name;$BreweryRefCopyWith<$Res> get brewery;$CategoryLabelCopyWith<$Res> get category;

}
/// @nodoc
class _$BeverageRefCopyWithImpl<$Res>
    implements $BeverageRefCopyWith<$Res> {
  _$BeverageRefCopyWithImpl(this._self, this._then);

  final BeverageRef _self;
  final $Res Function(BeverageRef) _then;

/// Create a copy of BeverageRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? brewery = null,Object? category = null,Object? labelImageUrl = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as I18nText,brewery: null == brewery ? _self.brewery : brewery // ignore: cast_nullable_to_non_nullable
as BreweryRef,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as CategoryLabel,labelImageUrl: freezed == labelImageUrl ? _self.labelImageUrl : labelImageUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of BeverageRef
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res> get name {
  
  return $I18nTextCopyWith<$Res>(_self.name, (value) {
    return _then(_self.copyWith(name: value));
  });
}/// Create a copy of BeverageRef
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BreweryRefCopyWith<$Res> get brewery {
  
  return $BreweryRefCopyWith<$Res>(_self.brewery, (value) {
    return _then(_self.copyWith(brewery: value));
  });
}/// Create a copy of BeverageRef
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CategoryLabelCopyWith<$Res> get category {
  
  return $CategoryLabelCopyWith<$Res>(_self.category, (value) {
    return _then(_self.copyWith(category: value));
  });
}
}


/// Adds pattern-matching-related methods to [BeverageRef].
extension BeverageRefPatterns on BeverageRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BeverageRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BeverageRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BeverageRef value)  $default,){
final _that = this;
switch (_that) {
case _BeverageRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BeverageRef value)?  $default,){
final _that = this;
switch (_that) {
case _BeverageRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  I18nText name,  BreweryRef brewery,  CategoryLabel category,  String? labelImageUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BeverageRef() when $default != null:
return $default(_that.id,_that.name,_that.brewery,_that.category,_that.labelImageUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  I18nText name,  BreweryRef brewery,  CategoryLabel category,  String? labelImageUrl)  $default,) {final _that = this;
switch (_that) {
case _BeverageRef():
return $default(_that.id,_that.name,_that.brewery,_that.category,_that.labelImageUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  I18nText name,  BreweryRef brewery,  CategoryLabel category,  String? labelImageUrl)?  $default,) {final _that = this;
switch (_that) {
case _BeverageRef() when $default != null:
return $default(_that.id,_that.name,_that.brewery,_that.category,_that.labelImageUrl);case _:
  return null;

}
}

}

/// @nodoc


class _BeverageRef implements BeverageRef {
  const _BeverageRef({required this.id, required this.name, required this.brewery, required this.category, this.labelImageUrl});
  

@override final  String id;
@override final  I18nText name;
@override final  BreweryRef brewery;
@override final  CategoryLabel category;
@override final  String? labelImageUrl;

/// Create a copy of BeverageRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BeverageRefCopyWith<_BeverageRef> get copyWith => __$BeverageRefCopyWithImpl<_BeverageRef>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BeverageRef&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.brewery, brewery) || other.brewery == brewery)&&(identical(other.category, category) || other.category == category)&&(identical(other.labelImageUrl, labelImageUrl) || other.labelImageUrl == labelImageUrl));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,brewery,category,labelImageUrl);

@override
String toString() {
  return 'BeverageRef(id: $id, name: $name, brewery: $brewery, category: $category, labelImageUrl: $labelImageUrl)';
}


}

/// @nodoc
abstract mixin class _$BeverageRefCopyWith<$Res> implements $BeverageRefCopyWith<$Res> {
  factory _$BeverageRefCopyWith(_BeverageRef value, $Res Function(_BeverageRef) _then) = __$BeverageRefCopyWithImpl;
@override @useResult
$Res call({
 String id, I18nText name, BreweryRef brewery, CategoryLabel category, String? labelImageUrl
});


@override $I18nTextCopyWith<$Res> get name;@override $BreweryRefCopyWith<$Res> get brewery;@override $CategoryLabelCopyWith<$Res> get category;

}
/// @nodoc
class __$BeverageRefCopyWithImpl<$Res>
    implements _$BeverageRefCopyWith<$Res> {
  __$BeverageRefCopyWithImpl(this._self, this._then);

  final _BeverageRef _self;
  final $Res Function(_BeverageRef) _then;

/// Create a copy of BeverageRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? brewery = null,Object? category = null,Object? labelImageUrl = freezed,}) {
  return _then(_BeverageRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as I18nText,brewery: null == brewery ? _self.brewery : brewery // ignore: cast_nullable_to_non_nullable
as BreweryRef,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as CategoryLabel,labelImageUrl: freezed == labelImageUrl ? _self.labelImageUrl : labelImageUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of BeverageRef
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res> get name {
  
  return $I18nTextCopyWith<$Res>(_self.name, (value) {
    return _then(_self.copyWith(name: value));
  });
}/// Create a copy of BeverageRef
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BreweryRefCopyWith<$Res> get brewery {
  
  return $BreweryRefCopyWith<$Res>(_self.brewery, (value) {
    return _then(_self.copyWith(brewery: value));
  });
}/// Create a copy of BeverageRef
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CategoryLabelCopyWith<$Res> get category {
  
  return $CategoryLabelCopyWith<$Res>(_self.category, (value) {
    return _then(_self.copyWith(category: value));
  });
}
}

/// @nodoc
mixin _$FlavorAggregate {

 String get slug; String get dimension; I18nText get name; int get uses;
/// Create a copy of FlavorAggregate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FlavorAggregateCopyWith<FlavorAggregate> get copyWith => _$FlavorAggregateCopyWithImpl<FlavorAggregate>(this as FlavorAggregate, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FlavorAggregate&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.dimension, dimension) || other.dimension == dimension)&&(identical(other.name, name) || other.name == name)&&(identical(other.uses, uses) || other.uses == uses));
}


@override
int get hashCode => Object.hash(runtimeType,slug,dimension,name,uses);

@override
String toString() {
  return 'FlavorAggregate(slug: $slug, dimension: $dimension, name: $name, uses: $uses)';
}


}

/// @nodoc
abstract mixin class $FlavorAggregateCopyWith<$Res>  {
  factory $FlavorAggregateCopyWith(FlavorAggregate value, $Res Function(FlavorAggregate) _then) = _$FlavorAggregateCopyWithImpl;
@useResult
$Res call({
 String slug, String dimension, I18nText name, int uses
});


$I18nTextCopyWith<$Res> get name;

}
/// @nodoc
class _$FlavorAggregateCopyWithImpl<$Res>
    implements $FlavorAggregateCopyWith<$Res> {
  _$FlavorAggregateCopyWithImpl(this._self, this._then);

  final FlavorAggregate _self;
  final $Res Function(FlavorAggregate) _then;

/// Create a copy of FlavorAggregate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? slug = null,Object? dimension = null,Object? name = null,Object? uses = null,}) {
  return _then(_self.copyWith(
slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,dimension: null == dimension ? _self.dimension : dimension // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as I18nText,uses: null == uses ? _self.uses : uses // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of FlavorAggregate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res> get name {
  
  return $I18nTextCopyWith<$Res>(_self.name, (value) {
    return _then(_self.copyWith(name: value));
  });
}
}


/// Adds pattern-matching-related methods to [FlavorAggregate].
extension FlavorAggregatePatterns on FlavorAggregate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FlavorAggregate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FlavorAggregate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FlavorAggregate value)  $default,){
final _that = this;
switch (_that) {
case _FlavorAggregate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FlavorAggregate value)?  $default,){
final _that = this;
switch (_that) {
case _FlavorAggregate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String slug,  String dimension,  I18nText name,  int uses)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FlavorAggregate() when $default != null:
return $default(_that.slug,_that.dimension,_that.name,_that.uses);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String slug,  String dimension,  I18nText name,  int uses)  $default,) {final _that = this;
switch (_that) {
case _FlavorAggregate():
return $default(_that.slug,_that.dimension,_that.name,_that.uses);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String slug,  String dimension,  I18nText name,  int uses)?  $default,) {final _that = this;
switch (_that) {
case _FlavorAggregate() when $default != null:
return $default(_that.slug,_that.dimension,_that.name,_that.uses);case _:
  return null;

}
}

}

/// @nodoc


class _FlavorAggregate implements FlavorAggregate {
  const _FlavorAggregate({required this.slug, required this.dimension, required this.name, this.uses = 0});
  

@override final  String slug;
@override final  String dimension;
@override final  I18nText name;
@override@JsonKey() final  int uses;

/// Create a copy of FlavorAggregate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FlavorAggregateCopyWith<_FlavorAggregate> get copyWith => __$FlavorAggregateCopyWithImpl<_FlavorAggregate>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FlavorAggregate&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.dimension, dimension) || other.dimension == dimension)&&(identical(other.name, name) || other.name == name)&&(identical(other.uses, uses) || other.uses == uses));
}


@override
int get hashCode => Object.hash(runtimeType,slug,dimension,name,uses);

@override
String toString() {
  return 'FlavorAggregate(slug: $slug, dimension: $dimension, name: $name, uses: $uses)';
}


}

/// @nodoc
abstract mixin class _$FlavorAggregateCopyWith<$Res> implements $FlavorAggregateCopyWith<$Res> {
  factory _$FlavorAggregateCopyWith(_FlavorAggregate value, $Res Function(_FlavorAggregate) _then) = __$FlavorAggregateCopyWithImpl;
@override @useResult
$Res call({
 String slug, String dimension, I18nText name, int uses
});


@override $I18nTextCopyWith<$Res> get name;

}
/// @nodoc
class __$FlavorAggregateCopyWithImpl<$Res>
    implements _$FlavorAggregateCopyWith<$Res> {
  __$FlavorAggregateCopyWithImpl(this._self, this._then);

  final _FlavorAggregate _self;
  final $Res Function(_FlavorAggregate) _then;

/// Create a copy of FlavorAggregate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? slug = null,Object? dimension = null,Object? name = null,Object? uses = null,}) {
  return _then(_FlavorAggregate(
slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,dimension: null == dimension ? _self.dimension : dimension // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as I18nText,uses: null == uses ? _self.uses : uses // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of FlavorAggregate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res> get name {
  
  return $I18nTextCopyWith<$Res>(_self.name, (value) {
    return _then(_self.copyWith(name: value));
  });
}
}

/// @nodoc
mixin _$BeverageDetail {

 Beverage get beverage; List<FlavorAggregate> get aggregatedFlavor; List<CheckinSummary> get recentCheckIns;
/// Create a copy of BeverageDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BeverageDetailCopyWith<BeverageDetail> get copyWith => _$BeverageDetailCopyWithImpl<BeverageDetail>(this as BeverageDetail, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BeverageDetail&&(identical(other.beverage, beverage) || other.beverage == beverage)&&const DeepCollectionEquality().equals(other.aggregatedFlavor, aggregatedFlavor)&&const DeepCollectionEquality().equals(other.recentCheckIns, recentCheckIns));
}


@override
int get hashCode => Object.hash(runtimeType,beverage,const DeepCollectionEquality().hash(aggregatedFlavor),const DeepCollectionEquality().hash(recentCheckIns));

@override
String toString() {
  return 'BeverageDetail(beverage: $beverage, aggregatedFlavor: $aggregatedFlavor, recentCheckIns: $recentCheckIns)';
}


}

/// @nodoc
abstract mixin class $BeverageDetailCopyWith<$Res>  {
  factory $BeverageDetailCopyWith(BeverageDetail value, $Res Function(BeverageDetail) _then) = _$BeverageDetailCopyWithImpl;
@useResult
$Res call({
 Beverage beverage, List<FlavorAggregate> aggregatedFlavor, List<CheckinSummary> recentCheckIns
});


$BeverageCopyWith<$Res> get beverage;

}
/// @nodoc
class _$BeverageDetailCopyWithImpl<$Res>
    implements $BeverageDetailCopyWith<$Res> {
  _$BeverageDetailCopyWithImpl(this._self, this._then);

  final BeverageDetail _self;
  final $Res Function(BeverageDetail) _then;

/// Create a copy of BeverageDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? beverage = null,Object? aggregatedFlavor = null,Object? recentCheckIns = null,}) {
  return _then(_self.copyWith(
beverage: null == beverage ? _self.beverage : beverage // ignore: cast_nullable_to_non_nullable
as Beverage,aggregatedFlavor: null == aggregatedFlavor ? _self.aggregatedFlavor : aggregatedFlavor // ignore: cast_nullable_to_non_nullable
as List<FlavorAggregate>,recentCheckIns: null == recentCheckIns ? _self.recentCheckIns : recentCheckIns // ignore: cast_nullable_to_non_nullable
as List<CheckinSummary>,
  ));
}
/// Create a copy of BeverageDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BeverageCopyWith<$Res> get beverage {
  
  return $BeverageCopyWith<$Res>(_self.beverage, (value) {
    return _then(_self.copyWith(beverage: value));
  });
}
}


/// Adds pattern-matching-related methods to [BeverageDetail].
extension BeverageDetailPatterns on BeverageDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BeverageDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BeverageDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BeverageDetail value)  $default,){
final _that = this;
switch (_that) {
case _BeverageDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BeverageDetail value)?  $default,){
final _that = this;
switch (_that) {
case _BeverageDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Beverage beverage,  List<FlavorAggregate> aggregatedFlavor,  List<CheckinSummary> recentCheckIns)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BeverageDetail() when $default != null:
return $default(_that.beverage,_that.aggregatedFlavor,_that.recentCheckIns);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Beverage beverage,  List<FlavorAggregate> aggregatedFlavor,  List<CheckinSummary> recentCheckIns)  $default,) {final _that = this;
switch (_that) {
case _BeverageDetail():
return $default(_that.beverage,_that.aggregatedFlavor,_that.recentCheckIns);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Beverage beverage,  List<FlavorAggregate> aggregatedFlavor,  List<CheckinSummary> recentCheckIns)?  $default,) {final _that = this;
switch (_that) {
case _BeverageDetail() when $default != null:
return $default(_that.beverage,_that.aggregatedFlavor,_that.recentCheckIns);case _:
  return null;

}
}

}

/// @nodoc


class _BeverageDetail implements BeverageDetail {
  const _BeverageDetail({required this.beverage, final  List<FlavorAggregate> aggregatedFlavor = const <FlavorAggregate>[], final  List<CheckinSummary> recentCheckIns = const <CheckinSummary>[]}): _aggregatedFlavor = aggregatedFlavor,_recentCheckIns = recentCheckIns;
  

@override final  Beverage beverage;
 final  List<FlavorAggregate> _aggregatedFlavor;
@override@JsonKey() List<FlavorAggregate> get aggregatedFlavor {
  if (_aggregatedFlavor is EqualUnmodifiableListView) return _aggregatedFlavor;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_aggregatedFlavor);
}

 final  List<CheckinSummary> _recentCheckIns;
@override@JsonKey() List<CheckinSummary> get recentCheckIns {
  if (_recentCheckIns is EqualUnmodifiableListView) return _recentCheckIns;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recentCheckIns);
}


/// Create a copy of BeverageDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BeverageDetailCopyWith<_BeverageDetail> get copyWith => __$BeverageDetailCopyWithImpl<_BeverageDetail>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BeverageDetail&&(identical(other.beverage, beverage) || other.beverage == beverage)&&const DeepCollectionEquality().equals(other._aggregatedFlavor, _aggregatedFlavor)&&const DeepCollectionEquality().equals(other._recentCheckIns, _recentCheckIns));
}


@override
int get hashCode => Object.hash(runtimeType,beverage,const DeepCollectionEquality().hash(_aggregatedFlavor),const DeepCollectionEquality().hash(_recentCheckIns));

@override
String toString() {
  return 'BeverageDetail(beverage: $beverage, aggregatedFlavor: $aggregatedFlavor, recentCheckIns: $recentCheckIns)';
}


}

/// @nodoc
abstract mixin class _$BeverageDetailCopyWith<$Res> implements $BeverageDetailCopyWith<$Res> {
  factory _$BeverageDetailCopyWith(_BeverageDetail value, $Res Function(_BeverageDetail) _then) = __$BeverageDetailCopyWithImpl;
@override @useResult
$Res call({
 Beverage beverage, List<FlavorAggregate> aggregatedFlavor, List<CheckinSummary> recentCheckIns
});


@override $BeverageCopyWith<$Res> get beverage;

}
/// @nodoc
class __$BeverageDetailCopyWithImpl<$Res>
    implements _$BeverageDetailCopyWith<$Res> {
  __$BeverageDetailCopyWithImpl(this._self, this._then);

  final _BeverageDetail _self;
  final $Res Function(_BeverageDetail) _then;

/// Create a copy of BeverageDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? beverage = null,Object? aggregatedFlavor = null,Object? recentCheckIns = null,}) {
  return _then(_BeverageDetail(
beverage: null == beverage ? _self.beverage : beverage // ignore: cast_nullable_to_non_nullable
as Beverage,aggregatedFlavor: null == aggregatedFlavor ? _self._aggregatedFlavor : aggregatedFlavor // ignore: cast_nullable_to_non_nullable
as List<FlavorAggregate>,recentCheckIns: null == recentCheckIns ? _self._recentCheckIns : recentCheckIns // ignore: cast_nullable_to_non_nullable
as List<CheckinSummary>,
  ));
}

/// Create a copy of BeverageDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BeverageCopyWith<$Res> get beverage {
  
  return $BeverageCopyWith<$Res>(_self.beverage, (value) {
    return _then(_self.copyWith(beverage: value));
  });
}
}

/// @nodoc
mixin _$CheckinSummary {

 String get id; CheckinUser get user; double? get rating; String? get review; String get createdAt;
/// Create a copy of CheckinSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CheckinSummaryCopyWith<CheckinSummary> get copyWith => _$CheckinSummaryCopyWithImpl<CheckinSummary>(this as CheckinSummary, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CheckinSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.user, user) || other.user == user)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.review, review) || other.review == review)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,user,rating,review,createdAt);

@override
String toString() {
  return 'CheckinSummary(id: $id, user: $user, rating: $rating, review: $review, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $CheckinSummaryCopyWith<$Res>  {
  factory $CheckinSummaryCopyWith(CheckinSummary value, $Res Function(CheckinSummary) _then) = _$CheckinSummaryCopyWithImpl;
@useResult
$Res call({
 String id, CheckinUser user, double? rating, String? review, String createdAt
});


$CheckinUserCopyWith<$Res> get user;

}
/// @nodoc
class _$CheckinSummaryCopyWithImpl<$Res>
    implements $CheckinSummaryCopyWith<$Res> {
  _$CheckinSummaryCopyWithImpl(this._self, this._then);

  final CheckinSummary _self;
  final $Res Function(CheckinSummary) _then;

/// Create a copy of CheckinSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? user = null,Object? rating = freezed,Object? review = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as CheckinUser,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,review: freezed == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of CheckinSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CheckinUserCopyWith<$Res> get user {
  
  return $CheckinUserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// Adds pattern-matching-related methods to [CheckinSummary].
extension CheckinSummaryPatterns on CheckinSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CheckinSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CheckinSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CheckinSummary value)  $default,){
final _that = this;
switch (_that) {
case _CheckinSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CheckinSummary value)?  $default,){
final _that = this;
switch (_that) {
case _CheckinSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  CheckinUser user,  double? rating,  String? review,  String createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CheckinSummary() when $default != null:
return $default(_that.id,_that.user,_that.rating,_that.review,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  CheckinUser user,  double? rating,  String? review,  String createdAt)  $default,) {final _that = this;
switch (_that) {
case _CheckinSummary():
return $default(_that.id,_that.user,_that.rating,_that.review,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  CheckinUser user,  double? rating,  String? review,  String createdAt)?  $default,) {final _that = this;
switch (_that) {
case _CheckinSummary() when $default != null:
return $default(_that.id,_that.user,_that.rating,_that.review,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _CheckinSummary implements CheckinSummary {
  const _CheckinSummary({required this.id, required this.user, this.rating, this.review, this.createdAt = ''});
  

@override final  String id;
@override final  CheckinUser user;
@override final  double? rating;
@override final  String? review;
@override@JsonKey() final  String createdAt;

/// Create a copy of CheckinSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CheckinSummaryCopyWith<_CheckinSummary> get copyWith => __$CheckinSummaryCopyWithImpl<_CheckinSummary>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CheckinSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.user, user) || other.user == user)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.review, review) || other.review == review)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,user,rating,review,createdAt);

@override
String toString() {
  return 'CheckinSummary(id: $id, user: $user, rating: $rating, review: $review, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$CheckinSummaryCopyWith<$Res> implements $CheckinSummaryCopyWith<$Res> {
  factory _$CheckinSummaryCopyWith(_CheckinSummary value, $Res Function(_CheckinSummary) _then) = __$CheckinSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, CheckinUser user, double? rating, String? review, String createdAt
});


@override $CheckinUserCopyWith<$Res> get user;

}
/// @nodoc
class __$CheckinSummaryCopyWithImpl<$Res>
    implements _$CheckinSummaryCopyWith<$Res> {
  __$CheckinSummaryCopyWithImpl(this._self, this._then);

  final _CheckinSummary _self;
  final $Res Function(_CheckinSummary) _then;

/// Create a copy of CheckinSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? user = null,Object? rating = freezed,Object? review = freezed,Object? createdAt = null,}) {
  return _then(_CheckinSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as CheckinUser,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,review: freezed == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of CheckinSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CheckinUserCopyWith<$Res> get user {
  
  return $CheckinUserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}

/// @nodoc
mixin _$CheckinUser {

 String get id; String get username; String get displayUsername; String get displayName; String? get avatarUrl;
/// Create a copy of CheckinUser
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CheckinUserCopyWith<CheckinUser> get copyWith => _$CheckinUserCopyWithImpl<CheckinUser>(this as CheckinUser, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CheckinUser&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayUsername, displayUsername) || other.displayUsername == displayUsername)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}


@override
int get hashCode => Object.hash(runtimeType,id,username,displayUsername,displayName,avatarUrl);

@override
String toString() {
  return 'CheckinUser(id: $id, username: $username, displayUsername: $displayUsername, displayName: $displayName, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class $CheckinUserCopyWith<$Res>  {
  factory $CheckinUserCopyWith(CheckinUser value, $Res Function(CheckinUser) _then) = _$CheckinUserCopyWithImpl;
@useResult
$Res call({
 String id, String username, String displayUsername, String displayName, String? avatarUrl
});




}
/// @nodoc
class _$CheckinUserCopyWithImpl<$Res>
    implements $CheckinUserCopyWith<$Res> {
  _$CheckinUserCopyWithImpl(this._self, this._then);

  final CheckinUser _self;
  final $Res Function(CheckinUser) _then;

/// Create a copy of CheckinUser
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? username = null,Object? displayUsername = null,Object? displayName = null,Object? avatarUrl = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayUsername: null == displayUsername ? _self.displayUsername : displayUsername // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CheckinUser].
extension CheckinUserPatterns on CheckinUser {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CheckinUser value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CheckinUser() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CheckinUser value)  $default,){
final _that = this;
switch (_that) {
case _CheckinUser():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CheckinUser value)?  $default,){
final _that = this;
switch (_that) {
case _CheckinUser() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String username,  String displayUsername,  String displayName,  String? avatarUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CheckinUser() when $default != null:
return $default(_that.id,_that.username,_that.displayUsername,_that.displayName,_that.avatarUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String username,  String displayUsername,  String displayName,  String? avatarUrl)  $default,) {final _that = this;
switch (_that) {
case _CheckinUser():
return $default(_that.id,_that.username,_that.displayUsername,_that.displayName,_that.avatarUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String username,  String displayUsername,  String displayName,  String? avatarUrl)?  $default,) {final _that = this;
switch (_that) {
case _CheckinUser() when $default != null:
return $default(_that.id,_that.username,_that.displayUsername,_that.displayName,_that.avatarUrl);case _:
  return null;

}
}

}

/// @nodoc


class _CheckinUser implements CheckinUser {
  const _CheckinUser({required this.id, required this.username, required this.displayUsername, required this.displayName, this.avatarUrl});
  

@override final  String id;
@override final  String username;
@override final  String displayUsername;
@override final  String displayName;
@override final  String? avatarUrl;

/// Create a copy of CheckinUser
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CheckinUserCopyWith<_CheckinUser> get copyWith => __$CheckinUserCopyWithImpl<_CheckinUser>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CheckinUser&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayUsername, displayUsername) || other.displayUsername == displayUsername)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}


@override
int get hashCode => Object.hash(runtimeType,id,username,displayUsername,displayName,avatarUrl);

@override
String toString() {
  return 'CheckinUser(id: $id, username: $username, displayUsername: $displayUsername, displayName: $displayName, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class _$CheckinUserCopyWith<$Res> implements $CheckinUserCopyWith<$Res> {
  factory _$CheckinUserCopyWith(_CheckinUser value, $Res Function(_CheckinUser) _then) = __$CheckinUserCopyWithImpl;
@override @useResult
$Res call({
 String id, String username, String displayUsername, String displayName, String? avatarUrl
});




}
/// @nodoc
class __$CheckinUserCopyWithImpl<$Res>
    implements _$CheckinUserCopyWith<$Res> {
  __$CheckinUserCopyWithImpl(this._self, this._then);

  final _CheckinUser _self;
  final $Res Function(_CheckinUser) _then;

/// Create a copy of CheckinUser
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? username = null,Object? displayUsername = null,Object? displayName = null,Object? avatarUrl = freezed,}) {
  return _then(_CheckinUser(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayUsername: null == displayUsername ? _self.displayUsername : displayUsername // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
