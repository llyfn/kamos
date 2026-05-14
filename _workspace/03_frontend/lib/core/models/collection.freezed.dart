// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'collection.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$Collection {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int get entryCount => throw _privateConstructorUsedError;
  String get createdAt => throw _privateConstructorUsedError;
  String get updatedAt => throw _privateConstructorUsedError;

  /// Create a copy of Collection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CollectionCopyWith<Collection> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CollectionCopyWith<$Res> {
  factory $CollectionCopyWith(
          Collection value, $Res Function(Collection) then) =
      _$CollectionCopyWithImpl<$Res, Collection>;
  @useResult
  $Res call(
      {String id,
      String name,
      int entryCount,
      String createdAt,
      String updatedAt});
}

/// @nodoc
class _$CollectionCopyWithImpl<$Res, $Val extends Collection>
    implements $CollectionCopyWith<$Res> {
  _$CollectionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Collection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? entryCount = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      entryCount: null == entryCount
          ? _value.entryCount
          : entryCount // ignore: cast_nullable_to_non_nullable
              as int,
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
}

/// @nodoc
abstract class _$$CollectionImplCopyWith<$Res>
    implements $CollectionCopyWith<$Res> {
  factory _$$CollectionImplCopyWith(
          _$CollectionImpl value, $Res Function(_$CollectionImpl) then) =
      __$$CollectionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      int entryCount,
      String createdAt,
      String updatedAt});
}

/// @nodoc
class __$$CollectionImplCopyWithImpl<$Res>
    extends _$CollectionCopyWithImpl<$Res, _$CollectionImpl>
    implements _$$CollectionImplCopyWith<$Res> {
  __$$CollectionImplCopyWithImpl(
      _$CollectionImpl _value, $Res Function(_$CollectionImpl) _then)
      : super(_value, _then);

  /// Create a copy of Collection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? entryCount = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$CollectionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      entryCount: null == entryCount
          ? _value.entryCount
          : entryCount // ignore: cast_nullable_to_non_nullable
              as int,
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

class _$CollectionImpl implements _Collection {
  const _$CollectionImpl(
      {required this.id,
      required this.name,
      this.entryCount = 0,
      this.createdAt = '',
      this.updatedAt = ''});

  @override
  final String id;
  @override
  final String name;
  @override
  @JsonKey()
  final int entryCount;
  @override
  @JsonKey()
  final String createdAt;
  @override
  @JsonKey()
  final String updatedAt;

  @override
  String toString() {
    return 'Collection(id: $id, name: $name, entryCount: $entryCount, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CollectionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.entryCount, entryCount) ||
                other.entryCount == entryCount) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, entryCount, createdAt, updatedAt);

  /// Create a copy of Collection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CollectionImplCopyWith<_$CollectionImpl> get copyWith =>
      __$$CollectionImplCopyWithImpl<_$CollectionImpl>(this, _$identity);
}

abstract class _Collection implements Collection {
  const factory _Collection(
      {required final String id,
      required final String name,
      final int entryCount,
      final String createdAt,
      final String updatedAt}) = _$CollectionImpl;

  @override
  String get id;
  @override
  String get name;
  @override
  int get entryCount;
  @override
  String get createdAt;
  @override
  String get updatedAt;

  /// Create a copy of Collection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CollectionImplCopyWith<_$CollectionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$CollectionEntry {
  BeverageRef get beverage => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;
  String get addedAt => throw _privateConstructorUsedError;

  /// Create a copy of CollectionEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CollectionEntryCopyWith<CollectionEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CollectionEntryCopyWith<$Res> {
  factory $CollectionEntryCopyWith(
          CollectionEntry value, $Res Function(CollectionEntry) then) =
      _$CollectionEntryCopyWithImpl<$Res, CollectionEntry>;
  @useResult
  $Res call({BeverageRef beverage, String? note, String addedAt});

  $BeverageRefCopyWith<$Res> get beverage;
}

/// @nodoc
class _$CollectionEntryCopyWithImpl<$Res, $Val extends CollectionEntry>
    implements $CollectionEntryCopyWith<$Res> {
  _$CollectionEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CollectionEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? beverage = null,
    Object? note = freezed,
    Object? addedAt = null,
  }) {
    return _then(_value.copyWith(
      beverage: null == beverage
          ? _value.beverage
          : beverage // ignore: cast_nullable_to_non_nullable
              as BeverageRef,
      note: freezed == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      addedAt: null == addedAt
          ? _value.addedAt
          : addedAt // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }

  /// Create a copy of CollectionEntry
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
abstract class _$$CollectionEntryImplCopyWith<$Res>
    implements $CollectionEntryCopyWith<$Res> {
  factory _$$CollectionEntryImplCopyWith(_$CollectionEntryImpl value,
          $Res Function(_$CollectionEntryImpl) then) =
      __$$CollectionEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({BeverageRef beverage, String? note, String addedAt});

  @override
  $BeverageRefCopyWith<$Res> get beverage;
}

/// @nodoc
class __$$CollectionEntryImplCopyWithImpl<$Res>
    extends _$CollectionEntryCopyWithImpl<$Res, _$CollectionEntryImpl>
    implements _$$CollectionEntryImplCopyWith<$Res> {
  __$$CollectionEntryImplCopyWithImpl(
      _$CollectionEntryImpl _value, $Res Function(_$CollectionEntryImpl) _then)
      : super(_value, _then);

  /// Create a copy of CollectionEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? beverage = null,
    Object? note = freezed,
    Object? addedAt = null,
  }) {
    return _then(_$CollectionEntryImpl(
      beverage: null == beverage
          ? _value.beverage
          : beverage // ignore: cast_nullable_to_non_nullable
              as BeverageRef,
      note: freezed == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      addedAt: null == addedAt
          ? _value.addedAt
          : addedAt // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$CollectionEntryImpl implements _CollectionEntry {
  const _$CollectionEntryImpl(
      {required this.beverage, this.note, this.addedAt = ''});

  @override
  final BeverageRef beverage;
  @override
  final String? note;
  @override
  @JsonKey()
  final String addedAt;

  @override
  String toString() {
    return 'CollectionEntry(beverage: $beverage, note: $note, addedAt: $addedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CollectionEntryImpl &&
            (identical(other.beverage, beverage) ||
                other.beverage == beverage) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.addedAt, addedAt) || other.addedAt == addedAt));
  }

  @override
  int get hashCode => Object.hash(runtimeType, beverage, note, addedAt);

  /// Create a copy of CollectionEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CollectionEntryImplCopyWith<_$CollectionEntryImpl> get copyWith =>
      __$$CollectionEntryImplCopyWithImpl<_$CollectionEntryImpl>(
          this, _$identity);
}

abstract class _CollectionEntry implements CollectionEntry {
  const factory _CollectionEntry(
      {required final BeverageRef beverage,
      final String? note,
      final String addedAt}) = _$CollectionEntryImpl;

  @override
  BeverageRef get beverage;
  @override
  String? get note;
  @override
  String get addedAt;

  /// Create a copy of CollectionEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CollectionEntryImplCopyWith<_$CollectionEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
