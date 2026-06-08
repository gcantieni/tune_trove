// dart format width=80
// GENERATED CODE, DO NOT EDIT BY HAND.
// ignore_for_file: type=lint
import 'package:drift/drift.dart';

class Recordings extends Table with TableInfo<Recordings, RecordingsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Recordings(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> performers = GeneratedColumn<String>(
    'performers',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> modifiedAt = GeneratedColumn<DateTime>(
    'modified_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    url,
    performers,
    createdAt,
    modifiedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recordings';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecordingsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordingsData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      performers: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}performers'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      modifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modified_at'],
      ),
    );
  }

  @override
  Recordings createAlias(String alias) {
    return Recordings(attachedDatabase, alias);
  }
}

class RecordingsData extends DataClass implements Insertable<RecordingsData> {
  final int id;
  final String name;
  final String url;
  final String? performers;
  final DateTime createdAt;
  final DateTime? modifiedAt;
  const RecordingsData({
    required this.id,
    required this.name,
    required this.url,
    this.performers,
    required this.createdAt,
    this.modifiedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || performers != null) {
      map['performers'] = Variable<String>(performers);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || modifiedAt != null) {
      map['modified_at'] = Variable<DateTime>(modifiedAt);
    }
    return map;
  }

  RecordingsCompanion toCompanion(bool nullToAbsent) {
    return RecordingsCompanion(
      id: Value(id),
      name: Value(name),
      url: Value(url),
      performers: performers == null && nullToAbsent
          ? const Value.absent()
          : Value(performers),
      createdAt: Value(createdAt),
      modifiedAt: modifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(modifiedAt),
    );
  }

  factory RecordingsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordingsData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      url: serializer.fromJson<String>(json['url']),
      performers: serializer.fromJson<String?>(json['performers']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      modifiedAt: serializer.fromJson<DateTime?>(json['modifiedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'url': serializer.toJson<String>(url),
      'performers': serializer.toJson<String?>(performers),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'modifiedAt': serializer.toJson<DateTime?>(modifiedAt),
    };
  }

  RecordingsData copyWith({
    int? id,
    String? name,
    String? url,
    Value<String?> performers = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> modifiedAt = const Value.absent(),
  }) => RecordingsData(
    id: id ?? this.id,
    name: name ?? this.name,
    url: url ?? this.url,
    performers: performers.present ? performers.value : this.performers,
    createdAt: createdAt ?? this.createdAt,
    modifiedAt: modifiedAt.present ? modifiedAt.value : this.modifiedAt,
  );
  RecordingsData copyWithCompanion(RecordingsCompanion data) {
    return RecordingsData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      url: data.url.present ? data.url.value : this.url,
      performers: data.performers.present
          ? data.performers.value
          : this.performers,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      modifiedAt: data.modifiedAt.present
          ? data.modifiedAt.value
          : this.modifiedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordingsData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('performers: $performers, ')
          ..write('createdAt: $createdAt, ')
          ..write('modifiedAt: $modifiedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, url, performers, createdAt, modifiedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordingsData &&
          other.id == this.id &&
          other.name == this.name &&
          other.url == this.url &&
          other.performers == this.performers &&
          other.createdAt == this.createdAt &&
          other.modifiedAt == this.modifiedAt);
}

class RecordingsCompanion extends UpdateCompanion<RecordingsData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> url;
  final Value<String?> performers;
  final Value<DateTime> createdAt;
  final Value<DateTime?> modifiedAt;
  const RecordingsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.url = const Value.absent(),
    this.performers = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.modifiedAt = const Value.absent(),
  });
  RecordingsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String url,
    this.performers = const Value.absent(),
    required DateTime createdAt,
    this.modifiedAt = const Value.absent(),
  }) : name = Value(name),
       url = Value(url),
       createdAt = Value(createdAt);
  static Insertable<RecordingsData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? url,
    Expression<String>? performers,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? modifiedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (url != null) 'url': url,
      if (performers != null) 'performers': performers,
      if (createdAt != null) 'created_at': createdAt,
      if (modifiedAt != null) 'modified_at': modifiedAt,
    });
  }

  RecordingsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? url,
    Value<String?>? performers,
    Value<DateTime>? createdAt,
    Value<DateTime?>? modifiedAt,
  }) {
    return RecordingsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      performers: performers ?? this.performers,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (performers.present) {
      map['performers'] = Variable<String>(performers.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (modifiedAt.present) {
      map['modified_at'] = Variable<DateTime>(modifiedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordingsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('performers: $performers, ')
          ..write('createdAt: $createdAt, ')
          ..write('modifiedAt: $modifiedAt')
          ..write(')'))
        .toString();
  }
}

class Tunes extends Table with TableInfo<Tunes, TunesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Tunes(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> abc = GeneratedColumn<String>(
    'abc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> abcSvg = GeneratedColumn<String>(
    'abc_svg',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> tsId = GeneratedColumn<int>(
    'ts_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> from = GeneratedColumn<String>(
    'from',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> modifiedAt = GeneratedColumn<DateTime>(
    'modified_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    abc,
    abcSvg,
    tsId,
    from,
    status,
    key,
    type,
    genre,
    createdAt,
    modifiedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tunes';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TunesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TunesData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      abc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}abc'],
      ),
      abcSvg: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}abc_svg'],
      ),
      tsId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ts_id'],
      ),
      from: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      modifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modified_at'],
      ),
    );
  }

  @override
  Tunes createAlias(String alias) {
    return Tunes(attachedDatabase, alias);
  }
}

class TunesData extends DataClass implements Insertable<TunesData> {
  final int id;
  final String name;
  final String? abc;
  final String? abcSvg;
  final int? tsId;
  final String? from;
  final String? status;
  final String? key;
  final String? type;
  final String? genre;
  final DateTime createdAt;
  final DateTime? modifiedAt;
  const TunesData({
    required this.id,
    required this.name,
    this.abc,
    this.abcSvg,
    this.tsId,
    this.from,
    this.status,
    this.key,
    this.type,
    this.genre,
    required this.createdAt,
    this.modifiedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || abc != null) {
      map['abc'] = Variable<String>(abc);
    }
    if (!nullToAbsent || abcSvg != null) {
      map['abc_svg'] = Variable<String>(abcSvg);
    }
    if (!nullToAbsent || tsId != null) {
      map['ts_id'] = Variable<int>(tsId);
    }
    if (!nullToAbsent || from != null) {
      map['from'] = Variable<String>(from);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    if (!nullToAbsent || key != null) {
      map['key'] = Variable<String>(key);
    }
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || modifiedAt != null) {
      map['modified_at'] = Variable<DateTime>(modifiedAt);
    }
    return map;
  }

  TunesCompanion toCompanion(bool nullToAbsent) {
    return TunesCompanion(
      id: Value(id),
      name: Value(name),
      abc: abc == null && nullToAbsent ? const Value.absent() : Value(abc),
      abcSvg: abcSvg == null && nullToAbsent
          ? const Value.absent()
          : Value(abcSvg),
      tsId: tsId == null && nullToAbsent ? const Value.absent() : Value(tsId),
      from: from == null && nullToAbsent ? const Value.absent() : Value(from),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      key: key == null && nullToAbsent ? const Value.absent() : Value(key),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      createdAt: Value(createdAt),
      modifiedAt: modifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(modifiedAt),
    );
  }

  factory TunesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TunesData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      abc: serializer.fromJson<String?>(json['abc']),
      abcSvg: serializer.fromJson<String?>(json['abcSvg']),
      tsId: serializer.fromJson<int?>(json['tsId']),
      from: serializer.fromJson<String?>(json['from']),
      status: serializer.fromJson<String?>(json['status']),
      key: serializer.fromJson<String?>(json['key']),
      type: serializer.fromJson<String?>(json['type']),
      genre: serializer.fromJson<String?>(json['genre']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      modifiedAt: serializer.fromJson<DateTime?>(json['modifiedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'abc': serializer.toJson<String?>(abc),
      'abcSvg': serializer.toJson<String?>(abcSvg),
      'tsId': serializer.toJson<int?>(tsId),
      'from': serializer.toJson<String?>(from),
      'status': serializer.toJson<String?>(status),
      'key': serializer.toJson<String?>(key),
      'type': serializer.toJson<String?>(type),
      'genre': serializer.toJson<String?>(genre),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'modifiedAt': serializer.toJson<DateTime?>(modifiedAt),
    };
  }

  TunesData copyWith({
    int? id,
    String? name,
    Value<String?> abc = const Value.absent(),
    Value<String?> abcSvg = const Value.absent(),
    Value<int?> tsId = const Value.absent(),
    Value<String?> from = const Value.absent(),
    Value<String?> status = const Value.absent(),
    Value<String?> key = const Value.absent(),
    Value<String?> type = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> modifiedAt = const Value.absent(),
  }) => TunesData(
    id: id ?? this.id,
    name: name ?? this.name,
    abc: abc.present ? abc.value : this.abc,
    abcSvg: abcSvg.present ? abcSvg.value : this.abcSvg,
    tsId: tsId.present ? tsId.value : this.tsId,
    from: from.present ? from.value : this.from,
    status: status.present ? status.value : this.status,
    key: key.present ? key.value : this.key,
    type: type.present ? type.value : this.type,
    genre: genre.present ? genre.value : this.genre,
    createdAt: createdAt ?? this.createdAt,
    modifiedAt: modifiedAt.present ? modifiedAt.value : this.modifiedAt,
  );
  TunesData copyWithCompanion(TunesCompanion data) {
    return TunesData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      abc: data.abc.present ? data.abc.value : this.abc,
      abcSvg: data.abcSvg.present ? data.abcSvg.value : this.abcSvg,
      tsId: data.tsId.present ? data.tsId.value : this.tsId,
      from: data.from.present ? data.from.value : this.from,
      status: data.status.present ? data.status.value : this.status,
      key: data.key.present ? data.key.value : this.key,
      type: data.type.present ? data.type.value : this.type,
      genre: data.genre.present ? data.genre.value : this.genre,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      modifiedAt: data.modifiedAt.present
          ? data.modifiedAt.value
          : this.modifiedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TunesData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('abc: $abc, ')
          ..write('abcSvg: $abcSvg, ')
          ..write('tsId: $tsId, ')
          ..write('from: $from, ')
          ..write('status: $status, ')
          ..write('key: $key, ')
          ..write('type: $type, ')
          ..write('genre: $genre, ')
          ..write('createdAt: $createdAt, ')
          ..write('modifiedAt: $modifiedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    abc,
    abcSvg,
    tsId,
    from,
    status,
    key,
    type,
    genre,
    createdAt,
    modifiedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TunesData &&
          other.id == this.id &&
          other.name == this.name &&
          other.abc == this.abc &&
          other.abcSvg == this.abcSvg &&
          other.tsId == this.tsId &&
          other.from == this.from &&
          other.status == this.status &&
          other.key == this.key &&
          other.type == this.type &&
          other.genre == this.genre &&
          other.createdAt == this.createdAt &&
          other.modifiedAt == this.modifiedAt);
}

class TunesCompanion extends UpdateCompanion<TunesData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> abc;
  final Value<String?> abcSvg;
  final Value<int?> tsId;
  final Value<String?> from;
  final Value<String?> status;
  final Value<String?> key;
  final Value<String?> type;
  final Value<String?> genre;
  final Value<DateTime> createdAt;
  final Value<DateTime?> modifiedAt;
  const TunesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.abc = const Value.absent(),
    this.abcSvg = const Value.absent(),
    this.tsId = const Value.absent(),
    this.from = const Value.absent(),
    this.status = const Value.absent(),
    this.key = const Value.absent(),
    this.type = const Value.absent(),
    this.genre = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.modifiedAt = const Value.absent(),
  });
  TunesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.abc = const Value.absent(),
    this.abcSvg = const Value.absent(),
    this.tsId = const Value.absent(),
    this.from = const Value.absent(),
    this.status = const Value.absent(),
    this.key = const Value.absent(),
    this.type = const Value.absent(),
    this.genre = const Value.absent(),
    required DateTime createdAt,
    this.modifiedAt = const Value.absent(),
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<TunesData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? abc,
    Expression<String>? abcSvg,
    Expression<int>? tsId,
    Expression<String>? from,
    Expression<String>? status,
    Expression<String>? key,
    Expression<String>? type,
    Expression<String>? genre,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? modifiedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (abc != null) 'abc': abc,
      if (abcSvg != null) 'abc_svg': abcSvg,
      if (tsId != null) 'ts_id': tsId,
      if (from != null) 'from': from,
      if (status != null) 'status': status,
      if (key != null) 'key': key,
      if (type != null) 'type': type,
      if (genre != null) 'genre': genre,
      if (createdAt != null) 'created_at': createdAt,
      if (modifiedAt != null) 'modified_at': modifiedAt,
    });
  }

  TunesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? abc,
    Value<String?>? abcSvg,
    Value<int?>? tsId,
    Value<String?>? from,
    Value<String?>? status,
    Value<String?>? key,
    Value<String?>? type,
    Value<String?>? genre,
    Value<DateTime>? createdAt,
    Value<DateTime?>? modifiedAt,
  }) {
    return TunesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      abc: abc ?? this.abc,
      abcSvg: abcSvg ?? this.abcSvg,
      tsId: tsId ?? this.tsId,
      from: from ?? this.from,
      status: status ?? this.status,
      key: key ?? this.key,
      type: type ?? this.type,
      genre: genre ?? this.genre,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (abc.present) {
      map['abc'] = Variable<String>(abc.value);
    }
    if (abcSvg.present) {
      map['abc_svg'] = Variable<String>(abcSvg.value);
    }
    if (tsId.present) {
      map['ts_id'] = Variable<int>(tsId.value);
    }
    if (from.present) {
      map['from'] = Variable<String>(from.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (modifiedAt.present) {
      map['modified_at'] = Variable<DateTime>(modifiedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TunesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('abc: $abc, ')
          ..write('abcSvg: $abcSvg, ')
          ..write('tsId: $tsId, ')
          ..write('from: $from, ')
          ..write('status: $status, ')
          ..write('key: $key, ')
          ..write('type: $type, ')
          ..write('genre: $genre, ')
          ..write('createdAt: $createdAt, ')
          ..write('modifiedAt: $modifiedAt')
          ..write(')'))
        .toString();
  }
}

class TuneRecording extends Table
    with TableInfo<TuneRecording, TuneRecordingData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  TuneRecording(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> tuneId = GeneratedColumn<int>(
    'tune_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> recordingId = GeneratedColumn<int>(
    'recording_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> startTime = GeneratedColumn<int>(
    'start_time',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> endTime = GeneratedColumn<int>(
    'end_time',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> performers = GeneratedColumn<String>(
    'performers',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    tuneId,
    recordingId,
    startTime,
    endTime,
    performers,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tune_recording';
  @override
  Set<GeneratedColumn> get $primaryKey => {tuneId, recordingId};
  @override
  TuneRecordingData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TuneRecordingData(
      tuneId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tune_id'],
      )!,
      recordingId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recording_id'],
      )!,
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_time'],
      ),
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_time'],
      ),
      performers: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}performers'],
      ),
    );
  }

  @override
  TuneRecording createAlias(String alias) {
    return TuneRecording(attachedDatabase, alias);
  }
}

class TuneRecordingData extends DataClass
    implements Insertable<TuneRecordingData> {
  final int tuneId;
  final int recordingId;
  final int? startTime;
  final int? endTime;
  final String? performers;
  const TuneRecordingData({
    required this.tuneId,
    required this.recordingId,
    this.startTime,
    this.endTime,
    this.performers,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tune_id'] = Variable<int>(tuneId);
    map['recording_id'] = Variable<int>(recordingId);
    if (!nullToAbsent || startTime != null) {
      map['start_time'] = Variable<int>(startTime);
    }
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<int>(endTime);
    }
    if (!nullToAbsent || performers != null) {
      map['performers'] = Variable<String>(performers);
    }
    return map;
  }

  TuneRecordingCompanion toCompanion(bool nullToAbsent) {
    return TuneRecordingCompanion(
      tuneId: Value(tuneId),
      recordingId: Value(recordingId),
      startTime: startTime == null && nullToAbsent
          ? const Value.absent()
          : Value(startTime),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
      performers: performers == null && nullToAbsent
          ? const Value.absent()
          : Value(performers),
    );
  }

  factory TuneRecordingData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TuneRecordingData(
      tuneId: serializer.fromJson<int>(json['tuneId']),
      recordingId: serializer.fromJson<int>(json['recordingId']),
      startTime: serializer.fromJson<int?>(json['startTime']),
      endTime: serializer.fromJson<int?>(json['endTime']),
      performers: serializer.fromJson<String?>(json['performers']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tuneId': serializer.toJson<int>(tuneId),
      'recordingId': serializer.toJson<int>(recordingId),
      'startTime': serializer.toJson<int?>(startTime),
      'endTime': serializer.toJson<int?>(endTime),
      'performers': serializer.toJson<String?>(performers),
    };
  }

  TuneRecordingData copyWith({
    int? tuneId,
    int? recordingId,
    Value<int?> startTime = const Value.absent(),
    Value<int?> endTime = const Value.absent(),
    Value<String?> performers = const Value.absent(),
  }) => TuneRecordingData(
    tuneId: tuneId ?? this.tuneId,
    recordingId: recordingId ?? this.recordingId,
    startTime: startTime.present ? startTime.value : this.startTime,
    endTime: endTime.present ? endTime.value : this.endTime,
    performers: performers.present ? performers.value : this.performers,
  );
  TuneRecordingData copyWithCompanion(TuneRecordingCompanion data) {
    return TuneRecordingData(
      tuneId: data.tuneId.present ? data.tuneId.value : this.tuneId,
      recordingId: data.recordingId.present
          ? data.recordingId.value
          : this.recordingId,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      performers: data.performers.present
          ? data.performers.value
          : this.performers,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TuneRecordingData(')
          ..write('tuneId: $tuneId, ')
          ..write('recordingId: $recordingId, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('performers: $performers')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(tuneId, recordingId, startTime, endTime, performers);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TuneRecordingData &&
          other.tuneId == this.tuneId &&
          other.recordingId == this.recordingId &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.performers == this.performers);
}

class TuneRecordingCompanion extends UpdateCompanion<TuneRecordingData> {
  final Value<int> tuneId;
  final Value<int> recordingId;
  final Value<int?> startTime;
  final Value<int?> endTime;
  final Value<String?> performers;
  final Value<int> rowid;
  const TuneRecordingCompanion({
    this.tuneId = const Value.absent(),
    this.recordingId = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.performers = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TuneRecordingCompanion.insert({
    required int tuneId,
    required int recordingId,
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.performers = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : tuneId = Value(tuneId),
       recordingId = Value(recordingId);
  static Insertable<TuneRecordingData> custom({
    Expression<int>? tuneId,
    Expression<int>? recordingId,
    Expression<int>? startTime,
    Expression<int>? endTime,
    Expression<String>? performers,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tuneId != null) 'tune_id': tuneId,
      if (recordingId != null) 'recording_id': recordingId,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (performers != null) 'performers': performers,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TuneRecordingCompanion copyWith({
    Value<int>? tuneId,
    Value<int>? recordingId,
    Value<int?>? startTime,
    Value<int?>? endTime,
    Value<String?>? performers,
    Value<int>? rowid,
  }) {
    return TuneRecordingCompanion(
      tuneId: tuneId ?? this.tuneId,
      recordingId: recordingId ?? this.recordingId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      performers: performers ?? this.performers,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tuneId.present) {
      map['tune_id'] = Variable<int>(tuneId.value);
    }
    if (recordingId.present) {
      map['recording_id'] = Variable<int>(recordingId.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<int>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<int>(endTime.value);
    }
    if (performers.present) {
      map['performers'] = Variable<String>(performers.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TuneRecordingCompanion(')
          ..write('tuneId: $tuneId, ')
          ..write('recordingId: $recordingId, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('performers: $performers, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class DatabaseAtV4 extends GeneratedDatabase {
  DatabaseAtV4(QueryExecutor e) : super(e);
  late final Recordings recordings = Recordings(this);
  late final Tunes tunes = Tunes(this);
  late final TuneRecording tuneRecording = TuneRecording(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    recordings,
    tunes,
    tuneRecording,
  ];
  @override
  int get schemaVersion => 4;
}
