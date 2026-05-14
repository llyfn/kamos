// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'brewery.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Brewery {

 String get id; I18nText get name; String? get prefecture; String? get region; int? get foundedYear; String? get website; I18nText? get description; String get createdAt;
/// Create a copy of Brewery
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BreweryCopyWith<Brewery> get copyWith => _$BreweryCopyWithImpl<Brewery>(this as Brewery, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Brewery&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.prefecture, prefecture) || other.prefecture == prefecture)&&(identical(other.region, region) || other.region == region)&&(identical(other.foundedYear, foundedYear) || other.foundedYear == foundedYear)&&(identical(other.website, website) || other.website == website)&&(identical(other.description, description) || other.description == description)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,prefecture,region,foundedYear,website,description,createdAt);

@override
String toString() {
  return 'Brewery(id: $id, name: $name, prefecture: $prefecture, region: $region, foundedYear: $foundedYear, website: $website, description: $description, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $BreweryCopyWith<$Res>  {
  factory $BreweryCopyWith(Brewery value, $Res Function(Brewery) _then) = _$BreweryCopyWithImpl;
@useResult
$Res call({
 String id, I18nText name, String? prefecture, String? region, int? foundedYear, String? website, I18nText? description, String createdAt
});


$I18nTextCopyWith<$Res> get name;$I18nTextCopyWith<$Res>? get description;

}
/// @nodoc
class _$BreweryCopyWithImpl<$Res>
    implements $BreweryCopyWith<$Res> {
  _$BreweryCopyWithImpl(this._self, this._then);

  final Brewery _self;
  final $Res Function(Brewery) _then;

/// Create a copy of Brewery
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? prefecture = freezed,Object? region = freezed,Object? foundedYear = freezed,Object? website = freezed,Object? description = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as I18nText,prefecture: freezed == prefecture ? _self.prefecture : prefecture // ignore: cast_nullable_to_non_nullable
as String?,region: freezed == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String?,foundedYear: freezed == foundedYear ? _self.foundedYear : foundedYear // ignore: cast_nullable_to_non_nullable
as int?,website: freezed == website ? _self.website : website // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as I18nText?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of Brewery
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res> get name {
  
  return $I18nTextCopyWith<$Res>(_self.name, (value) {
    return _then(_self.copyWith(name: value));
  });
}/// Create a copy of Brewery
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


/// Adds pattern-matching-related methods to [Brewery].
extension BreweryPatterns on Brewery {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Brewery value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Brewery() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Brewery value)  $default,){
final _that = this;
switch (_that) {
case _Brewery():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Brewery value)?  $default,){
final _that = this;
switch (_that) {
case _Brewery() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  I18nText name,  String? prefecture,  String? region,  int? foundedYear,  String? website,  I18nText? description,  String createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Brewery() when $default != null:
return $default(_that.id,_that.name,_that.prefecture,_that.region,_that.foundedYear,_that.website,_that.description,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  I18nText name,  String? prefecture,  String? region,  int? foundedYear,  String? website,  I18nText? description,  String createdAt)  $default,) {final _that = this;
switch (_that) {
case _Brewery():
return $default(_that.id,_that.name,_that.prefecture,_that.region,_that.foundedYear,_that.website,_that.description,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  I18nText name,  String? prefecture,  String? region,  int? foundedYear,  String? website,  I18nText? description,  String createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Brewery() when $default != null:
return $default(_that.id,_that.name,_that.prefecture,_that.region,_that.foundedYear,_that.website,_that.description,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _Brewery implements Brewery {
  const _Brewery({required this.id, required this.name, this.prefecture, this.region, this.foundedYear, this.website, this.description, this.createdAt = ''});
  

@override final  String id;
@override final  I18nText name;
@override final  String? prefecture;
@override final  String? region;
@override final  int? foundedYear;
@override final  String? website;
@override final  I18nText? description;
@override@JsonKey() final  String createdAt;

/// Create a copy of Brewery
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BreweryCopyWith<_Brewery> get copyWith => __$BreweryCopyWithImpl<_Brewery>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Brewery&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.prefecture, prefecture) || other.prefecture == prefecture)&&(identical(other.region, region) || other.region == region)&&(identical(other.foundedYear, foundedYear) || other.foundedYear == foundedYear)&&(identical(other.website, website) || other.website == website)&&(identical(other.description, description) || other.description == description)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,prefecture,region,foundedYear,website,description,createdAt);

@override
String toString() {
  return 'Brewery(id: $id, name: $name, prefecture: $prefecture, region: $region, foundedYear: $foundedYear, website: $website, description: $description, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$BreweryCopyWith<$Res> implements $BreweryCopyWith<$Res> {
  factory _$BreweryCopyWith(_Brewery value, $Res Function(_Brewery) _then) = __$BreweryCopyWithImpl;
@override @useResult
$Res call({
 String id, I18nText name, String? prefecture, String? region, int? foundedYear, String? website, I18nText? description, String createdAt
});


@override $I18nTextCopyWith<$Res> get name;@override $I18nTextCopyWith<$Res>? get description;

}
/// @nodoc
class __$BreweryCopyWithImpl<$Res>
    implements _$BreweryCopyWith<$Res> {
  __$BreweryCopyWithImpl(this._self, this._then);

  final _Brewery _self;
  final $Res Function(_Brewery) _then;

/// Create a copy of Brewery
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? prefecture = freezed,Object? region = freezed,Object? foundedYear = freezed,Object? website = freezed,Object? description = freezed,Object? createdAt = null,}) {
  return _then(_Brewery(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as I18nText,prefecture: freezed == prefecture ? _self.prefecture : prefecture // ignore: cast_nullable_to_non_nullable
as String?,region: freezed == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String?,foundedYear: freezed == foundedYear ? _self.foundedYear : foundedYear // ignore: cast_nullable_to_non_nullable
as int?,website: freezed == website ? _self.website : website // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as I18nText?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of Brewery
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res> get name {
  
  return $I18nTextCopyWith<$Res>(_self.name, (value) {
    return _then(_self.copyWith(name: value));
  });
}/// Create a copy of Brewery
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
mixin _$BreweryRef {

 String get id; I18nText get name; String? get region;
/// Create a copy of BreweryRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BreweryRefCopyWith<BreweryRef> get copyWith => _$BreweryRefCopyWithImpl<BreweryRef>(this as BreweryRef, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BreweryRef&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.region, region) || other.region == region));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,region);

@override
String toString() {
  return 'BreweryRef(id: $id, name: $name, region: $region)';
}


}

/// @nodoc
abstract mixin class $BreweryRefCopyWith<$Res>  {
  factory $BreweryRefCopyWith(BreweryRef value, $Res Function(BreweryRef) _then) = _$BreweryRefCopyWithImpl;
@useResult
$Res call({
 String id, I18nText name, String? region
});


$I18nTextCopyWith<$Res> get name;

}
/// @nodoc
class _$BreweryRefCopyWithImpl<$Res>
    implements $BreweryRefCopyWith<$Res> {
  _$BreweryRefCopyWithImpl(this._self, this._then);

  final BreweryRef _self;
  final $Res Function(BreweryRef) _then;

/// Create a copy of BreweryRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? region = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as I18nText,region: freezed == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of BreweryRef
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res> get name {
  
  return $I18nTextCopyWith<$Res>(_self.name, (value) {
    return _then(_self.copyWith(name: value));
  });
}
}


/// Adds pattern-matching-related methods to [BreweryRef].
extension BreweryRefPatterns on BreweryRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BreweryRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BreweryRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BreweryRef value)  $default,){
final _that = this;
switch (_that) {
case _BreweryRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BreweryRef value)?  $default,){
final _that = this;
switch (_that) {
case _BreweryRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  I18nText name,  String? region)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BreweryRef() when $default != null:
return $default(_that.id,_that.name,_that.region);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  I18nText name,  String? region)  $default,) {final _that = this;
switch (_that) {
case _BreweryRef():
return $default(_that.id,_that.name,_that.region);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  I18nText name,  String? region)?  $default,) {final _that = this;
switch (_that) {
case _BreweryRef() when $default != null:
return $default(_that.id,_that.name,_that.region);case _:
  return null;

}
}

}

/// @nodoc


class _BreweryRef implements BreweryRef {
  const _BreweryRef({required this.id, required this.name, this.region});
  

@override final  String id;
@override final  I18nText name;
@override final  String? region;

/// Create a copy of BreweryRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BreweryRefCopyWith<_BreweryRef> get copyWith => __$BreweryRefCopyWithImpl<_BreweryRef>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BreweryRef&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.region, region) || other.region == region));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,region);

@override
String toString() {
  return 'BreweryRef(id: $id, name: $name, region: $region)';
}


}

/// @nodoc
abstract mixin class _$BreweryRefCopyWith<$Res> implements $BreweryRefCopyWith<$Res> {
  factory _$BreweryRefCopyWith(_BreweryRef value, $Res Function(_BreweryRef) _then) = __$BreweryRefCopyWithImpl;
@override @useResult
$Res call({
 String id, I18nText name, String? region
});


@override $I18nTextCopyWith<$Res> get name;

}
/// @nodoc
class __$BreweryRefCopyWithImpl<$Res>
    implements _$BreweryRefCopyWith<$Res> {
  __$BreweryRefCopyWithImpl(this._self, this._then);

  final _BreweryRef _self;
  final $Res Function(_BreweryRef) _then;

/// Create a copy of BreweryRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? region = freezed,}) {
  return _then(_BreweryRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as I18nText,region: freezed == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of BreweryRef
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res> get name {
  
  return $I18nTextCopyWith<$Res>(_self.name, (value) {
    return _then(_self.copyWith(name: value));
  });
}
}

// dart format on
