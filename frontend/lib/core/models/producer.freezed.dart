// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'producer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Producer {

 String get id; I18nText get name; Prefecture? get prefecture; int? get foundedYear; String? get website; I18nText? get description;@JsonKey(name: 'image_url') String? get imageUrl;// Populated by `GET /v1/producers/{id}` and `GET /v1/producers`. Absent in
// nested `ProducerRef` embeddings (which use the ProducerRef model) and in
// /v1/search producer results — `null` then.
 int? get beverageCount; String get createdAt;
/// Create a copy of Producer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProducerCopyWith<Producer> get copyWith => _$ProducerCopyWithImpl<Producer>(this as Producer, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Producer&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.prefecture, prefecture) || other.prefecture == prefecture)&&(identical(other.foundedYear, foundedYear) || other.foundedYear == foundedYear)&&(identical(other.website, website) || other.website == website)&&(identical(other.description, description) || other.description == description)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.beverageCount, beverageCount) || other.beverageCount == beverageCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,prefecture,foundedYear,website,description,imageUrl,beverageCount,createdAt);

@override
String toString() {
  return 'Producer(id: $id, name: $name, prefecture: $prefecture, foundedYear: $foundedYear, website: $website, description: $description, imageUrl: $imageUrl, beverageCount: $beverageCount, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $ProducerCopyWith<$Res>  {
  factory $ProducerCopyWith(Producer value, $Res Function(Producer) _then) = _$ProducerCopyWithImpl;
@useResult
$Res call({
 String id, I18nText name, Prefecture? prefecture, int? foundedYear, String? website, I18nText? description,@JsonKey(name: 'image_url') String? imageUrl, int? beverageCount, String createdAt
});


$I18nTextCopyWith<$Res> get name;$PrefectureCopyWith<$Res>? get prefecture;$I18nTextCopyWith<$Res>? get description;

}
/// @nodoc
class _$ProducerCopyWithImpl<$Res>
    implements $ProducerCopyWith<$Res> {
  _$ProducerCopyWithImpl(this._self, this._then);

  final Producer _self;
  final $Res Function(Producer) _then;

/// Create a copy of Producer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? prefecture = freezed,Object? foundedYear = freezed,Object? website = freezed,Object? description = freezed,Object? imageUrl = freezed,Object? beverageCount = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as I18nText,prefecture: freezed == prefecture ? _self.prefecture : prefecture // ignore: cast_nullable_to_non_nullable
as Prefecture?,foundedYear: freezed == foundedYear ? _self.foundedYear : foundedYear // ignore: cast_nullable_to_non_nullable
as int?,website: freezed == website ? _self.website : website // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as I18nText?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,beverageCount: freezed == beverageCount ? _self.beverageCount : beverageCount // ignore: cast_nullable_to_non_nullable
as int?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of Producer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res> get name {
  
  return $I18nTextCopyWith<$Res>(_self.name, (value) {
    return _then(_self.copyWith(name: value));
  });
}/// Create a copy of Producer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PrefectureCopyWith<$Res>? get prefecture {
    if (_self.prefecture == null) {
    return null;
  }

  return $PrefectureCopyWith<$Res>(_self.prefecture!, (value) {
    return _then(_self.copyWith(prefecture: value));
  });
}/// Create a copy of Producer
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


/// Adds pattern-matching-related methods to [Producer].
extension ProducerPatterns on Producer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Producer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Producer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Producer value)  $default,){
final _that = this;
switch (_that) {
case _Producer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Producer value)?  $default,){
final _that = this;
switch (_that) {
case _Producer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  I18nText name,  Prefecture? prefecture,  int? foundedYear,  String? website,  I18nText? description, @JsonKey(name: 'image_url')  String? imageUrl,  int? beverageCount,  String createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Producer() when $default != null:
return $default(_that.id,_that.name,_that.prefecture,_that.foundedYear,_that.website,_that.description,_that.imageUrl,_that.beverageCount,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  I18nText name,  Prefecture? prefecture,  int? foundedYear,  String? website,  I18nText? description, @JsonKey(name: 'image_url')  String? imageUrl,  int? beverageCount,  String createdAt)  $default,) {final _that = this;
switch (_that) {
case _Producer():
return $default(_that.id,_that.name,_that.prefecture,_that.foundedYear,_that.website,_that.description,_that.imageUrl,_that.beverageCount,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  I18nText name,  Prefecture? prefecture,  int? foundedYear,  String? website,  I18nText? description, @JsonKey(name: 'image_url')  String? imageUrl,  int? beverageCount,  String createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Producer() when $default != null:
return $default(_that.id,_that.name,_that.prefecture,_that.foundedYear,_that.website,_that.description,_that.imageUrl,_that.beverageCount,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _Producer implements Producer {
  const _Producer({required this.id, required this.name, this.prefecture, this.foundedYear, this.website, this.description, @JsonKey(name: 'image_url') this.imageUrl, this.beverageCount, this.createdAt = ''});
  

@override final  String id;
@override final  I18nText name;
@override final  Prefecture? prefecture;
@override final  int? foundedYear;
@override final  String? website;
@override final  I18nText? description;
@override@JsonKey(name: 'image_url') final  String? imageUrl;
// Populated by `GET /v1/producers/{id}` and `GET /v1/producers`. Absent in
// nested `ProducerRef` embeddings (which use the ProducerRef model) and in
// /v1/search producer results — `null` then.
@override final  int? beverageCount;
@override@JsonKey() final  String createdAt;

/// Create a copy of Producer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProducerCopyWith<_Producer> get copyWith => __$ProducerCopyWithImpl<_Producer>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Producer&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.prefecture, prefecture) || other.prefecture == prefecture)&&(identical(other.foundedYear, foundedYear) || other.foundedYear == foundedYear)&&(identical(other.website, website) || other.website == website)&&(identical(other.description, description) || other.description == description)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.beverageCount, beverageCount) || other.beverageCount == beverageCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,prefecture,foundedYear,website,description,imageUrl,beverageCount,createdAt);

@override
String toString() {
  return 'Producer(id: $id, name: $name, prefecture: $prefecture, foundedYear: $foundedYear, website: $website, description: $description, imageUrl: $imageUrl, beverageCount: $beverageCount, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$ProducerCopyWith<$Res> implements $ProducerCopyWith<$Res> {
  factory _$ProducerCopyWith(_Producer value, $Res Function(_Producer) _then) = __$ProducerCopyWithImpl;
@override @useResult
$Res call({
 String id, I18nText name, Prefecture? prefecture, int? foundedYear, String? website, I18nText? description,@JsonKey(name: 'image_url') String? imageUrl, int? beverageCount, String createdAt
});


@override $I18nTextCopyWith<$Res> get name;@override $PrefectureCopyWith<$Res>? get prefecture;@override $I18nTextCopyWith<$Res>? get description;

}
/// @nodoc
class __$ProducerCopyWithImpl<$Res>
    implements _$ProducerCopyWith<$Res> {
  __$ProducerCopyWithImpl(this._self, this._then);

  final _Producer _self;
  final $Res Function(_Producer) _then;

/// Create a copy of Producer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? prefecture = freezed,Object? foundedYear = freezed,Object? website = freezed,Object? description = freezed,Object? imageUrl = freezed,Object? beverageCount = freezed,Object? createdAt = null,}) {
  return _then(_Producer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as I18nText,prefecture: freezed == prefecture ? _self.prefecture : prefecture // ignore: cast_nullable_to_non_nullable
as Prefecture?,foundedYear: freezed == foundedYear ? _self.foundedYear : foundedYear // ignore: cast_nullable_to_non_nullable
as int?,website: freezed == website ? _self.website : website // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as I18nText?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,beverageCount: freezed == beverageCount ? _self.beverageCount : beverageCount // ignore: cast_nullable_to_non_nullable
as int?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of Producer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res> get name {
  
  return $I18nTextCopyWith<$Res>(_self.name, (value) {
    return _then(_self.copyWith(name: value));
  });
}/// Create a copy of Producer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PrefectureCopyWith<$Res>? get prefecture {
    if (_self.prefecture == null) {
    return null;
  }

  return $PrefectureCopyWith<$Res>(_self.prefecture!, (value) {
    return _then(_self.copyWith(prefecture: value));
  });
}/// Create a copy of Producer
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
mixin _$ProducerRef {

 String get id; I18nText get name; Prefecture? get prefecture;@JsonKey(name: 'image_url') String? get imageUrl;
/// Create a copy of ProducerRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProducerRefCopyWith<ProducerRef> get copyWith => _$ProducerRefCopyWithImpl<ProducerRef>(this as ProducerRef, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProducerRef&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.prefecture, prefecture) || other.prefecture == prefecture)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,prefecture,imageUrl);

@override
String toString() {
  return 'ProducerRef(id: $id, name: $name, prefecture: $prefecture, imageUrl: $imageUrl)';
}


}

/// @nodoc
abstract mixin class $ProducerRefCopyWith<$Res>  {
  factory $ProducerRefCopyWith(ProducerRef value, $Res Function(ProducerRef) _then) = _$ProducerRefCopyWithImpl;
@useResult
$Res call({
 String id, I18nText name, Prefecture? prefecture,@JsonKey(name: 'image_url') String? imageUrl
});


$I18nTextCopyWith<$Res> get name;$PrefectureCopyWith<$Res>? get prefecture;

}
/// @nodoc
class _$ProducerRefCopyWithImpl<$Res>
    implements $ProducerRefCopyWith<$Res> {
  _$ProducerRefCopyWithImpl(this._self, this._then);

  final ProducerRef _self;
  final $Res Function(ProducerRef) _then;

/// Create a copy of ProducerRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? prefecture = freezed,Object? imageUrl = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as I18nText,prefecture: freezed == prefecture ? _self.prefecture : prefecture // ignore: cast_nullable_to_non_nullable
as Prefecture?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of ProducerRef
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res> get name {
  
  return $I18nTextCopyWith<$Res>(_self.name, (value) {
    return _then(_self.copyWith(name: value));
  });
}/// Create a copy of ProducerRef
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PrefectureCopyWith<$Res>? get prefecture {
    if (_self.prefecture == null) {
    return null;
  }

  return $PrefectureCopyWith<$Res>(_self.prefecture!, (value) {
    return _then(_self.copyWith(prefecture: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProducerRef].
extension ProducerRefPatterns on ProducerRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProducerRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProducerRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProducerRef value)  $default,){
final _that = this;
switch (_that) {
case _ProducerRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProducerRef value)?  $default,){
final _that = this;
switch (_that) {
case _ProducerRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  I18nText name,  Prefecture? prefecture, @JsonKey(name: 'image_url')  String? imageUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProducerRef() when $default != null:
return $default(_that.id,_that.name,_that.prefecture,_that.imageUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  I18nText name,  Prefecture? prefecture, @JsonKey(name: 'image_url')  String? imageUrl)  $default,) {final _that = this;
switch (_that) {
case _ProducerRef():
return $default(_that.id,_that.name,_that.prefecture,_that.imageUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  I18nText name,  Prefecture? prefecture, @JsonKey(name: 'image_url')  String? imageUrl)?  $default,) {final _that = this;
switch (_that) {
case _ProducerRef() when $default != null:
return $default(_that.id,_that.name,_that.prefecture,_that.imageUrl);case _:
  return null;

}
}

}

/// @nodoc


class _ProducerRef implements ProducerRef {
  const _ProducerRef({required this.id, required this.name, this.prefecture, @JsonKey(name: 'image_url') this.imageUrl});
  

@override final  String id;
@override final  I18nText name;
@override final  Prefecture? prefecture;
@override@JsonKey(name: 'image_url') final  String? imageUrl;

/// Create a copy of ProducerRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProducerRefCopyWith<_ProducerRef> get copyWith => __$ProducerRefCopyWithImpl<_ProducerRef>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProducerRef&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.prefecture, prefecture) || other.prefecture == prefecture)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,prefecture,imageUrl);

@override
String toString() {
  return 'ProducerRef(id: $id, name: $name, prefecture: $prefecture, imageUrl: $imageUrl)';
}


}

/// @nodoc
abstract mixin class _$ProducerRefCopyWith<$Res> implements $ProducerRefCopyWith<$Res> {
  factory _$ProducerRefCopyWith(_ProducerRef value, $Res Function(_ProducerRef) _then) = __$ProducerRefCopyWithImpl;
@override @useResult
$Res call({
 String id, I18nText name, Prefecture? prefecture,@JsonKey(name: 'image_url') String? imageUrl
});


@override $I18nTextCopyWith<$Res> get name;@override $PrefectureCopyWith<$Res>? get prefecture;

}
/// @nodoc
class __$ProducerRefCopyWithImpl<$Res>
    implements _$ProducerRefCopyWith<$Res> {
  __$ProducerRefCopyWithImpl(this._self, this._then);

  final _ProducerRef _self;
  final $Res Function(_ProducerRef) _then;

/// Create a copy of ProducerRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? prefecture = freezed,Object? imageUrl = freezed,}) {
  return _then(_ProducerRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as I18nText,prefecture: freezed == prefecture ? _self.prefecture : prefecture // ignore: cast_nullable_to_non_nullable
as Prefecture?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of ProducerRef
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$I18nTextCopyWith<$Res> get name {
  
  return $I18nTextCopyWith<$Res>(_self.name, (value) {
    return _then(_self.copyWith(name: value));
  });
}/// Create a copy of ProducerRef
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PrefectureCopyWith<$Res>? get prefecture {
    if (_self.prefecture == null) {
    return null;
  }

  return $PrefectureCopyWith<$Res>(_self.prefecture!, (value) {
    return _then(_self.copyWith(prefecture: value));
  });
}
}

// dart format on
