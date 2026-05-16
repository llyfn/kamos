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
