// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'collection.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Collection {

 String get id; String get name; int get entryCount; CollectionVisibility get visibility; String get createdAt; String get updatedAt;
/// Create a copy of Collection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CollectionCopyWith<Collection> get copyWith => _$CollectionCopyWithImpl<Collection>(this as Collection, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Collection&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.entryCount, entryCount) || other.entryCount == entryCount)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,entryCount,visibility,createdAt,updatedAt);

@override
String toString() {
  return 'Collection(id: $id, name: $name, entryCount: $entryCount, visibility: $visibility, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $CollectionCopyWith<$Res>  {
  factory $CollectionCopyWith(Collection value, $Res Function(Collection) _then) = _$CollectionCopyWithImpl;
@useResult
$Res call({
 String id, String name, int entryCount, CollectionVisibility visibility, String createdAt, String updatedAt
});




}
/// @nodoc
class _$CollectionCopyWithImpl<$Res>
    implements $CollectionCopyWith<$Res> {
  _$CollectionCopyWithImpl(this._self, this._then);

  final Collection _self;
  final $Res Function(Collection) _then;

/// Create a copy of Collection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? entryCount = null,Object? visibility = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,entryCount: null == entryCount ? _self.entryCount : entryCount // ignore: cast_nullable_to_non_nullable
as int,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as CollectionVisibility,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Collection].
extension CollectionPatterns on Collection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Collection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Collection() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Collection value)  $default,){
final _that = this;
switch (_that) {
case _Collection():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Collection value)?  $default,){
final _that = this;
switch (_that) {
case _Collection() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  int entryCount,  CollectionVisibility visibility,  String createdAt,  String updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Collection() when $default != null:
return $default(_that.id,_that.name,_that.entryCount,_that.visibility,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  int entryCount,  CollectionVisibility visibility,  String createdAt,  String updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Collection():
return $default(_that.id,_that.name,_that.entryCount,_that.visibility,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  int entryCount,  CollectionVisibility visibility,  String createdAt,  String updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Collection() when $default != null:
return $default(_that.id,_that.name,_that.entryCount,_that.visibility,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _Collection implements Collection {
  const _Collection({required this.id, required this.name, this.entryCount = 0, this.visibility = CollectionVisibility.private, this.createdAt = '', this.updatedAt = ''});
  

@override final  String id;
@override final  String name;
@override@JsonKey() final  int entryCount;
@override@JsonKey() final  CollectionVisibility visibility;
@override@JsonKey() final  String createdAt;
@override@JsonKey() final  String updatedAt;

/// Create a copy of Collection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CollectionCopyWith<_Collection> get copyWith => __$CollectionCopyWithImpl<_Collection>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Collection&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.entryCount, entryCount) || other.entryCount == entryCount)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,entryCount,visibility,createdAt,updatedAt);

@override
String toString() {
  return 'Collection(id: $id, name: $name, entryCount: $entryCount, visibility: $visibility, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$CollectionCopyWith<$Res> implements $CollectionCopyWith<$Res> {
  factory _$CollectionCopyWith(_Collection value, $Res Function(_Collection) _then) = __$CollectionCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, int entryCount, CollectionVisibility visibility, String createdAt, String updatedAt
});




}
/// @nodoc
class __$CollectionCopyWithImpl<$Res>
    implements _$CollectionCopyWith<$Res> {
  __$CollectionCopyWithImpl(this._self, this._then);

  final _Collection _self;
  final $Res Function(_Collection) _then;

/// Create a copy of Collection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? entryCount = null,Object? visibility = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Collection(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,entryCount: null == entryCount ? _self.entryCount : entryCount // ignore: cast_nullable_to_non_nullable
as int,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as CollectionVisibility,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$CollectionOwner {

 String get id; String get username; String get displayUsername; String? get avatarUrl;
/// Create a copy of CollectionOwner
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CollectionOwnerCopyWith<CollectionOwner> get copyWith => _$CollectionOwnerCopyWithImpl<CollectionOwner>(this as CollectionOwner, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CollectionOwner&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayUsername, displayUsername) || other.displayUsername == displayUsername)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}


@override
int get hashCode => Object.hash(runtimeType,id,username,displayUsername,avatarUrl);

@override
String toString() {
  return 'CollectionOwner(id: $id, username: $username, displayUsername: $displayUsername, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class $CollectionOwnerCopyWith<$Res>  {
  factory $CollectionOwnerCopyWith(CollectionOwner value, $Res Function(CollectionOwner) _then) = _$CollectionOwnerCopyWithImpl;
@useResult
$Res call({
 String id, String username, String displayUsername, String? avatarUrl
});




}
/// @nodoc
class _$CollectionOwnerCopyWithImpl<$Res>
    implements $CollectionOwnerCopyWith<$Res> {
  _$CollectionOwnerCopyWithImpl(this._self, this._then);

  final CollectionOwner _self;
  final $Res Function(CollectionOwner) _then;

/// Create a copy of CollectionOwner
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? username = null,Object? displayUsername = null,Object? avatarUrl = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayUsername: null == displayUsername ? _self.displayUsername : displayUsername // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CollectionOwner].
extension CollectionOwnerPatterns on CollectionOwner {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CollectionOwner value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CollectionOwner() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CollectionOwner value)  $default,){
final _that = this;
switch (_that) {
case _CollectionOwner():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CollectionOwner value)?  $default,){
final _that = this;
switch (_that) {
case _CollectionOwner() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String username,  String displayUsername,  String? avatarUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CollectionOwner() when $default != null:
return $default(_that.id,_that.username,_that.displayUsername,_that.avatarUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String username,  String displayUsername,  String? avatarUrl)  $default,) {final _that = this;
switch (_that) {
case _CollectionOwner():
return $default(_that.id,_that.username,_that.displayUsername,_that.avatarUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String username,  String displayUsername,  String? avatarUrl)?  $default,) {final _that = this;
switch (_that) {
case _CollectionOwner() when $default != null:
return $default(_that.id,_that.username,_that.displayUsername,_that.avatarUrl);case _:
  return null;

}
}

}

/// @nodoc


class _CollectionOwner implements CollectionOwner {
  const _CollectionOwner({required this.id, required this.username, required this.displayUsername, this.avatarUrl});
  

@override final  String id;
@override final  String username;
@override final  String displayUsername;
@override final  String? avatarUrl;

/// Create a copy of CollectionOwner
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CollectionOwnerCopyWith<_CollectionOwner> get copyWith => __$CollectionOwnerCopyWithImpl<_CollectionOwner>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CollectionOwner&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayUsername, displayUsername) || other.displayUsername == displayUsername)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}


@override
int get hashCode => Object.hash(runtimeType,id,username,displayUsername,avatarUrl);

@override
String toString() {
  return 'CollectionOwner(id: $id, username: $username, displayUsername: $displayUsername, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class _$CollectionOwnerCopyWith<$Res> implements $CollectionOwnerCopyWith<$Res> {
  factory _$CollectionOwnerCopyWith(_CollectionOwner value, $Res Function(_CollectionOwner) _then) = __$CollectionOwnerCopyWithImpl;
@override @useResult
$Res call({
 String id, String username, String displayUsername, String? avatarUrl
});




}
/// @nodoc
class __$CollectionOwnerCopyWithImpl<$Res>
    implements _$CollectionOwnerCopyWith<$Res> {
  __$CollectionOwnerCopyWithImpl(this._self, this._then);

  final _CollectionOwner _self;
  final $Res Function(_CollectionOwner) _then;

/// Create a copy of CollectionOwner
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? username = null,Object? displayUsername = null,Object? avatarUrl = freezed,}) {
  return _then(_CollectionOwner(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayUsername: null == displayUsername ? _self.displayUsername : displayUsername // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$CollectionWithOwner {

 Collection get collection; CollectionOwner get owner;
/// Create a copy of CollectionWithOwner
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CollectionWithOwnerCopyWith<CollectionWithOwner> get copyWith => _$CollectionWithOwnerCopyWithImpl<CollectionWithOwner>(this as CollectionWithOwner, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CollectionWithOwner&&(identical(other.collection, collection) || other.collection == collection)&&(identical(other.owner, owner) || other.owner == owner));
}


@override
int get hashCode => Object.hash(runtimeType,collection,owner);

@override
String toString() {
  return 'CollectionWithOwner(collection: $collection, owner: $owner)';
}


}

/// @nodoc
abstract mixin class $CollectionWithOwnerCopyWith<$Res>  {
  factory $CollectionWithOwnerCopyWith(CollectionWithOwner value, $Res Function(CollectionWithOwner) _then) = _$CollectionWithOwnerCopyWithImpl;
@useResult
$Res call({
 Collection collection, CollectionOwner owner
});


$CollectionCopyWith<$Res> get collection;$CollectionOwnerCopyWith<$Res> get owner;

}
/// @nodoc
class _$CollectionWithOwnerCopyWithImpl<$Res>
    implements $CollectionWithOwnerCopyWith<$Res> {
  _$CollectionWithOwnerCopyWithImpl(this._self, this._then);

  final CollectionWithOwner _self;
  final $Res Function(CollectionWithOwner) _then;

/// Create a copy of CollectionWithOwner
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? collection = null,Object? owner = null,}) {
  return _then(_self.copyWith(
collection: null == collection ? _self.collection : collection // ignore: cast_nullable_to_non_nullable
as Collection,owner: null == owner ? _self.owner : owner // ignore: cast_nullable_to_non_nullable
as CollectionOwner,
  ));
}
/// Create a copy of CollectionWithOwner
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CollectionCopyWith<$Res> get collection {
  
  return $CollectionCopyWith<$Res>(_self.collection, (value) {
    return _then(_self.copyWith(collection: value));
  });
}/// Create a copy of CollectionWithOwner
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CollectionOwnerCopyWith<$Res> get owner {
  
  return $CollectionOwnerCopyWith<$Res>(_self.owner, (value) {
    return _then(_self.copyWith(owner: value));
  });
}
}


/// Adds pattern-matching-related methods to [CollectionWithOwner].
extension CollectionWithOwnerPatterns on CollectionWithOwner {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CollectionWithOwner value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CollectionWithOwner() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CollectionWithOwner value)  $default,){
final _that = this;
switch (_that) {
case _CollectionWithOwner():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CollectionWithOwner value)?  $default,){
final _that = this;
switch (_that) {
case _CollectionWithOwner() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Collection collection,  CollectionOwner owner)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CollectionWithOwner() when $default != null:
return $default(_that.collection,_that.owner);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Collection collection,  CollectionOwner owner)  $default,) {final _that = this;
switch (_that) {
case _CollectionWithOwner():
return $default(_that.collection,_that.owner);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Collection collection,  CollectionOwner owner)?  $default,) {final _that = this;
switch (_that) {
case _CollectionWithOwner() when $default != null:
return $default(_that.collection,_that.owner);case _:
  return null;

}
}

}

/// @nodoc


class _CollectionWithOwner implements CollectionWithOwner {
  const _CollectionWithOwner({required this.collection, required this.owner});
  

@override final  Collection collection;
@override final  CollectionOwner owner;

/// Create a copy of CollectionWithOwner
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CollectionWithOwnerCopyWith<_CollectionWithOwner> get copyWith => __$CollectionWithOwnerCopyWithImpl<_CollectionWithOwner>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CollectionWithOwner&&(identical(other.collection, collection) || other.collection == collection)&&(identical(other.owner, owner) || other.owner == owner));
}


@override
int get hashCode => Object.hash(runtimeType,collection,owner);

@override
String toString() {
  return 'CollectionWithOwner(collection: $collection, owner: $owner)';
}


}

/// @nodoc
abstract mixin class _$CollectionWithOwnerCopyWith<$Res> implements $CollectionWithOwnerCopyWith<$Res> {
  factory _$CollectionWithOwnerCopyWith(_CollectionWithOwner value, $Res Function(_CollectionWithOwner) _then) = __$CollectionWithOwnerCopyWithImpl;
@override @useResult
$Res call({
 Collection collection, CollectionOwner owner
});


@override $CollectionCopyWith<$Res> get collection;@override $CollectionOwnerCopyWith<$Res> get owner;

}
/// @nodoc
class __$CollectionWithOwnerCopyWithImpl<$Res>
    implements _$CollectionWithOwnerCopyWith<$Res> {
  __$CollectionWithOwnerCopyWithImpl(this._self, this._then);

  final _CollectionWithOwner _self;
  final $Res Function(_CollectionWithOwner) _then;

/// Create a copy of CollectionWithOwner
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? collection = null,Object? owner = null,}) {
  return _then(_CollectionWithOwner(
collection: null == collection ? _self.collection : collection // ignore: cast_nullable_to_non_nullable
as Collection,owner: null == owner ? _self.owner : owner // ignore: cast_nullable_to_non_nullable
as CollectionOwner,
  ));
}

/// Create a copy of CollectionWithOwner
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CollectionCopyWith<$Res> get collection {
  
  return $CollectionCopyWith<$Res>(_self.collection, (value) {
    return _then(_self.copyWith(collection: value));
  });
}/// Create a copy of CollectionWithOwner
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CollectionOwnerCopyWith<$Res> get owner {
  
  return $CollectionOwnerCopyWith<$Res>(_self.owner, (value) {
    return _then(_self.copyWith(owner: value));
  });
}
}

/// @nodoc
mixin _$CollectionEntry {

 BeverageRef get beverage; String? get note; String get addedAt;
/// Create a copy of CollectionEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CollectionEntryCopyWith<CollectionEntry> get copyWith => _$CollectionEntryCopyWithImpl<CollectionEntry>(this as CollectionEntry, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CollectionEntry&&(identical(other.beverage, beverage) || other.beverage == beverage)&&(identical(other.note, note) || other.note == note)&&(identical(other.addedAt, addedAt) || other.addedAt == addedAt));
}


@override
int get hashCode => Object.hash(runtimeType,beverage,note,addedAt);

@override
String toString() {
  return 'CollectionEntry(beverage: $beverage, note: $note, addedAt: $addedAt)';
}


}

/// @nodoc
abstract mixin class $CollectionEntryCopyWith<$Res>  {
  factory $CollectionEntryCopyWith(CollectionEntry value, $Res Function(CollectionEntry) _then) = _$CollectionEntryCopyWithImpl;
@useResult
$Res call({
 BeverageRef beverage, String? note, String addedAt
});


$BeverageRefCopyWith<$Res> get beverage;

}
/// @nodoc
class _$CollectionEntryCopyWithImpl<$Res>
    implements $CollectionEntryCopyWith<$Res> {
  _$CollectionEntryCopyWithImpl(this._self, this._then);

  final CollectionEntry _self;
  final $Res Function(CollectionEntry) _then;

/// Create a copy of CollectionEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? beverage = null,Object? note = freezed,Object? addedAt = null,}) {
  return _then(_self.copyWith(
beverage: null == beverage ? _self.beverage : beverage // ignore: cast_nullable_to_non_nullable
as BeverageRef,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,addedAt: null == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of CollectionEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BeverageRefCopyWith<$Res> get beverage {
  
  return $BeverageRefCopyWith<$Res>(_self.beverage, (value) {
    return _then(_self.copyWith(beverage: value));
  });
}
}


/// Adds pattern-matching-related methods to [CollectionEntry].
extension CollectionEntryPatterns on CollectionEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CollectionEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CollectionEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CollectionEntry value)  $default,){
final _that = this;
switch (_that) {
case _CollectionEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CollectionEntry value)?  $default,){
final _that = this;
switch (_that) {
case _CollectionEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( BeverageRef beverage,  String? note,  String addedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CollectionEntry() when $default != null:
return $default(_that.beverage,_that.note,_that.addedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( BeverageRef beverage,  String? note,  String addedAt)  $default,) {final _that = this;
switch (_that) {
case _CollectionEntry():
return $default(_that.beverage,_that.note,_that.addedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( BeverageRef beverage,  String? note,  String addedAt)?  $default,) {final _that = this;
switch (_that) {
case _CollectionEntry() when $default != null:
return $default(_that.beverage,_that.note,_that.addedAt);case _:
  return null;

}
}

}

/// @nodoc


class _CollectionEntry implements CollectionEntry {
  const _CollectionEntry({required this.beverage, this.note, this.addedAt = ''});
  

@override final  BeverageRef beverage;
@override final  String? note;
@override@JsonKey() final  String addedAt;

/// Create a copy of CollectionEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CollectionEntryCopyWith<_CollectionEntry> get copyWith => __$CollectionEntryCopyWithImpl<_CollectionEntry>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CollectionEntry&&(identical(other.beverage, beverage) || other.beverage == beverage)&&(identical(other.note, note) || other.note == note)&&(identical(other.addedAt, addedAt) || other.addedAt == addedAt));
}


@override
int get hashCode => Object.hash(runtimeType,beverage,note,addedAt);

@override
String toString() {
  return 'CollectionEntry(beverage: $beverage, note: $note, addedAt: $addedAt)';
}


}

/// @nodoc
abstract mixin class _$CollectionEntryCopyWith<$Res> implements $CollectionEntryCopyWith<$Res> {
  factory _$CollectionEntryCopyWith(_CollectionEntry value, $Res Function(_CollectionEntry) _then) = __$CollectionEntryCopyWithImpl;
@override @useResult
$Res call({
 BeverageRef beverage, String? note, String addedAt
});


@override $BeverageRefCopyWith<$Res> get beverage;

}
/// @nodoc
class __$CollectionEntryCopyWithImpl<$Res>
    implements _$CollectionEntryCopyWith<$Res> {
  __$CollectionEntryCopyWithImpl(this._self, this._then);

  final _CollectionEntry _self;
  final $Res Function(_CollectionEntry) _then;

/// Create a copy of CollectionEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? beverage = null,Object? note = freezed,Object? addedAt = null,}) {
  return _then(_CollectionEntry(
beverage: null == beverage ? _self.beverage : beverage // ignore: cast_nullable_to_non_nullable
as BeverageRef,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,addedAt: null == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of CollectionEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BeverageRefCopyWith<$Res> get beverage {
  
  return $BeverageRefCopyWith<$Res>(_self.beverage, (value) {
    return _then(_self.copyWith(beverage: value));
  });
}
}

// dart format on
