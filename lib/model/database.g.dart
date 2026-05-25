// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RecordingsTable extends Recordings
    with TableInfo<$RecordingsTable, Recording> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _performersMeta = const VerificationMeta(
    'performers',
  );
  @override
  late final GeneratedColumn<String> performers = GeneratedColumn<String>(
    'performers',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modifiedAtMeta = const VerificationMeta(
    'modifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> modifiedAt = GeneratedColumn<DateTime>(
    'modified_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cloudIdMeta = const VerificationMeta(
    'cloudId',
  );
  @override
  late final GeneratedColumn<String> cloudId = GeneratedColumn<String>(
    'cloud_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    cloudId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recordings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Recording> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('performers')) {
      context.handle(
        _performersMeta,
        performers.isAcceptableOrUnknown(data['performers']!, _performersMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('modified_at')) {
      context.handle(
        _modifiedAtMeta,
        modifiedAt.isAcceptableOrUnknown(data['modified_at']!, _modifiedAtMeta),
      );
    }
    if (data.containsKey('cloud_id')) {
      context.handle(
        _cloudIdMeta,
        cloudId.isAcceptableOrUnknown(data['cloud_id']!, _cloudIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Recording map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Recording(
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
      cloudId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_id'],
      ),
    );
  }

  @override
  $RecordingsTable createAlias(String alias) {
    return $RecordingsTable(attachedDatabase, alias);
  }
}

class Recording extends DataClass implements Insertable<Recording> {
  final int id;
  final String name;
  final String url;
  final String? performers;
  final DateTime createdAt;
  final DateTime? modifiedAt;
  final String? cloudId;
  const Recording({
    required this.id,
    required this.name,
    required this.url,
    this.performers,
    required this.createdAt,
    this.modifiedAt,
    this.cloudId,
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
    if (!nullToAbsent || cloudId != null) {
      map['cloud_id'] = Variable<String>(cloudId);
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
      cloudId: cloudId == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudId),
    );
  }

  factory Recording.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Recording(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      url: serializer.fromJson<String>(json['url']),
      performers: serializer.fromJson<String?>(json['performers']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      modifiedAt: serializer.fromJson<DateTime?>(json['modifiedAt']),
      cloudId: serializer.fromJson<String?>(json['cloudId']),
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
      'cloudId': serializer.toJson<String?>(cloudId),
    };
  }

  Recording copyWith({
    int? id,
    String? name,
    String? url,
    Value<String?> performers = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> modifiedAt = const Value.absent(),
    Value<String?> cloudId = const Value.absent(),
  }) => Recording(
    id: id ?? this.id,
    name: name ?? this.name,
    url: url ?? this.url,
    performers: performers.present ? performers.value : this.performers,
    createdAt: createdAt ?? this.createdAt,
    modifiedAt: modifiedAt.present ? modifiedAt.value : this.modifiedAt,
    cloudId: cloudId.present ? cloudId.value : this.cloudId,
  );
  Recording copyWithCompanion(RecordingsCompanion data) {
    return Recording(
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
      cloudId: data.cloudId.present ? data.cloudId.value : this.cloudId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Recording(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('performers: $performers, ')
          ..write('createdAt: $createdAt, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('cloudId: $cloudId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, url, performers, createdAt, modifiedAt, cloudId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Recording &&
          other.id == this.id &&
          other.name == this.name &&
          other.url == this.url &&
          other.performers == this.performers &&
          other.createdAt == this.createdAt &&
          other.modifiedAt == this.modifiedAt &&
          other.cloudId == this.cloudId);
}

class RecordingsCompanion extends UpdateCompanion<Recording> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> url;
  final Value<String?> performers;
  final Value<DateTime> createdAt;
  final Value<DateTime?> modifiedAt;
  final Value<String?> cloudId;
  const RecordingsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.url = const Value.absent(),
    this.performers = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.cloudId = const Value.absent(),
  });
  RecordingsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String url,
    this.performers = const Value.absent(),
    required DateTime createdAt,
    this.modifiedAt = const Value.absent(),
    this.cloudId = const Value.absent(),
  }) : name = Value(name),
       url = Value(url),
       createdAt = Value(createdAt);
  static Insertable<Recording> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? url,
    Expression<String>? performers,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? modifiedAt,
    Expression<String>? cloudId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (url != null) 'url': url,
      if (performers != null) 'performers': performers,
      if (createdAt != null) 'created_at': createdAt,
      if (modifiedAt != null) 'modified_at': modifiedAt,
      if (cloudId != null) 'cloud_id': cloudId,
    });
  }

  RecordingsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? url,
    Value<String?>? performers,
    Value<DateTime>? createdAt,
    Value<DateTime?>? modifiedAt,
    Value<String?>? cloudId,
  }) {
    return RecordingsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      performers: performers ?? this.performers,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      cloudId: cloudId ?? this.cloudId,
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
    if (cloudId.present) {
      map['cloud_id'] = Variable<String>(cloudId.value);
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
          ..write('modifiedAt: $modifiedAt, ')
          ..write('cloudId: $cloudId')
          ..write(')'))
        .toString();
  }
}

class $TunesTable extends Tunes with TableInfo<$TunesTable, Tune> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TunesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _abcMeta = const VerificationMeta('abc');
  @override
  late final GeneratedColumn<String> abc = GeneratedColumn<String>(
    'abc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _abcSvgMeta = const VerificationMeta('abcSvg');
  @override
  late final GeneratedColumn<String> abcSvg = GeneratedColumn<String>(
    'abc_svg',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tsIdMeta = const VerificationMeta('tsId');
  @override
  late final GeneratedColumn<int> tsId = GeneratedColumn<int>(
    'ts_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fromMeta = const VerificationMeta('from');
  @override
  late final GeneratedColumn<String> from = GeneratedColumn<String>(
    'from',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TuneStatus?, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<TuneStatus?>($TunesTable.$converterstatusn);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TuneType?, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<TuneType?>($TunesTable.$convertertypen);
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modifiedAtMeta = const VerificationMeta(
    'modifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> modifiedAt = GeneratedColumn<DateTime>(
    'modified_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cloudIdMeta = const VerificationMeta(
    'cloudId',
  );
  @override
  late final GeneratedColumn<String> cloudId = GeneratedColumn<String>(
    'cloud_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    cloudId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tunes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tune> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('abc')) {
      context.handle(
        _abcMeta,
        abc.isAcceptableOrUnknown(data['abc']!, _abcMeta),
      );
    }
    if (data.containsKey('abc_svg')) {
      context.handle(
        _abcSvgMeta,
        abcSvg.isAcceptableOrUnknown(data['abc_svg']!, _abcSvgMeta),
      );
    }
    if (data.containsKey('ts_id')) {
      context.handle(
        _tsIdMeta,
        tsId.isAcceptableOrUnknown(data['ts_id']!, _tsIdMeta),
      );
    }
    if (data.containsKey('from')) {
      context.handle(
        _fromMeta,
        from.isAcceptableOrUnknown(data['from']!, _fromMeta),
      );
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('modified_at')) {
      context.handle(
        _modifiedAtMeta,
        modifiedAt.isAcceptableOrUnknown(data['modified_at']!, _modifiedAtMeta),
      );
    }
    if (data.containsKey('cloud_id')) {
      context.handle(
        _cloudIdMeta,
        cloudId.isAcceptableOrUnknown(data['cloud_id']!, _cloudIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tune map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tune(
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
      status: $TunesTable.$converterstatusn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        ),
      ),
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      ),
      type: $TunesTable.$convertertypen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        ),
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
      cloudId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_id'],
      ),
    );
  }

  @override
  $TunesTable createAlias(String alias) {
    return $TunesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TuneStatus, String, String> $converterstatus =
      const EnumNameConverter<TuneStatus>(TuneStatus.values);
  static JsonTypeConverter2<TuneStatus?, String?, String?> $converterstatusn =
      JsonTypeConverter2.asNullable($converterstatus);
  static JsonTypeConverter2<TuneType, String, String> $convertertype =
      const EnumNameConverter<TuneType>(TuneType.values);
  static JsonTypeConverter2<TuneType?, String?, String?> $convertertypen =
      JsonTypeConverter2.asNullable($convertertype);
}

class Tune extends DataClass implements Insertable<Tune> {
  final int id;
  final String name;
  final String? abc;
  final String? abcSvg;
  final int? tsId;
  final String? from;
  final TuneStatus? status;
  final String? key;
  final TuneType? type;
  final String? genre;
  final DateTime createdAt;
  final DateTime? modifiedAt;
  final String? cloudId;
  const Tune({
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
    this.cloudId,
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
      map['status'] = Variable<String>(
        $TunesTable.$converterstatusn.toSql(status),
      );
    }
    if (!nullToAbsent || key != null) {
      map['key'] = Variable<String>(key);
    }
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>($TunesTable.$convertertypen.toSql(type));
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || modifiedAt != null) {
      map['modified_at'] = Variable<DateTime>(modifiedAt);
    }
    if (!nullToAbsent || cloudId != null) {
      map['cloud_id'] = Variable<String>(cloudId);
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
      cloudId: cloudId == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudId),
    );
  }

  factory Tune.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tune(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      abc: serializer.fromJson<String?>(json['abc']),
      abcSvg: serializer.fromJson<String?>(json['abcSvg']),
      tsId: serializer.fromJson<int?>(json['tsId']),
      from: serializer.fromJson<String?>(json['from']),
      status: $TunesTable.$converterstatusn.fromJson(
        serializer.fromJson<String?>(json['status']),
      ),
      key: serializer.fromJson<String?>(json['key']),
      type: $TunesTable.$convertertypen.fromJson(
        serializer.fromJson<String?>(json['type']),
      ),
      genre: serializer.fromJson<String?>(json['genre']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      modifiedAt: serializer.fromJson<DateTime?>(json['modifiedAt']),
      cloudId: serializer.fromJson<String?>(json['cloudId']),
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
      'status': serializer.toJson<String?>(
        $TunesTable.$converterstatusn.toJson(status),
      ),
      'key': serializer.toJson<String?>(key),
      'type': serializer.toJson<String?>(
        $TunesTable.$convertertypen.toJson(type),
      ),
      'genre': serializer.toJson<String?>(genre),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'modifiedAt': serializer.toJson<DateTime?>(modifiedAt),
      'cloudId': serializer.toJson<String?>(cloudId),
    };
  }

  Tune copyWith({
    int? id,
    String? name,
    Value<String?> abc = const Value.absent(),
    Value<String?> abcSvg = const Value.absent(),
    Value<int?> tsId = const Value.absent(),
    Value<String?> from = const Value.absent(),
    Value<TuneStatus?> status = const Value.absent(),
    Value<String?> key = const Value.absent(),
    Value<TuneType?> type = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> modifiedAt = const Value.absent(),
    Value<String?> cloudId = const Value.absent(),
  }) => Tune(
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
    cloudId: cloudId.present ? cloudId.value : this.cloudId,
  );
  Tune copyWithCompanion(TunesCompanion data) {
    return Tune(
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
      cloudId: data.cloudId.present ? data.cloudId.value : this.cloudId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tune(')
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
          ..write('modifiedAt: $modifiedAt, ')
          ..write('cloudId: $cloudId')
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
    cloudId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tune &&
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
          other.modifiedAt == this.modifiedAt &&
          other.cloudId == this.cloudId);
}

class TunesCompanion extends UpdateCompanion<Tune> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> abc;
  final Value<String?> abcSvg;
  final Value<int?> tsId;
  final Value<String?> from;
  final Value<TuneStatus?> status;
  final Value<String?> key;
  final Value<TuneType?> type;
  final Value<String?> genre;
  final Value<DateTime> createdAt;
  final Value<DateTime?> modifiedAt;
  final Value<String?> cloudId;
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
    this.cloudId = const Value.absent(),
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
    this.cloudId = const Value.absent(),
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Tune> custom({
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
    Expression<String>? cloudId,
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
      if (cloudId != null) 'cloud_id': cloudId,
    });
  }

  TunesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? abc,
    Value<String?>? abcSvg,
    Value<int?>? tsId,
    Value<String?>? from,
    Value<TuneStatus?>? status,
    Value<String?>? key,
    Value<TuneType?>? type,
    Value<String?>? genre,
    Value<DateTime>? createdAt,
    Value<DateTime?>? modifiedAt,
    Value<String?>? cloudId,
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
      cloudId: cloudId ?? this.cloudId,
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
      map['status'] = Variable<String>(
        $TunesTable.$converterstatusn.toSql(status.value),
      );
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $TunesTable.$convertertypen.toSql(type.value),
      );
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
    if (cloudId.present) {
      map['cloud_id'] = Variable<String>(cloudId.value);
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
          ..write('modifiedAt: $modifiedAt, ')
          ..write('cloudId: $cloudId')
          ..write(')'))
        .toString();
  }
}

class $TuneRecordingTable extends TuneRecording
    with TableInfo<$TuneRecordingTable, TuneRecordingData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TuneRecordingTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tuneIdMeta = const VerificationMeta('tuneId');
  @override
  late final GeneratedColumn<int> tuneId = GeneratedColumn<int>(
    'tune_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordingIdMeta = const VerificationMeta(
    'recordingId',
  );
  @override
  late final GeneratedColumn<int> recordingId = GeneratedColumn<int>(
    'recording_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<double> startTime = GeneratedColumn<double>(
    'start_time',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<double> endTime = GeneratedColumn<double>(
    'end_time',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _performersMeta = const VerificationMeta(
    'performers',
  );
  @override
  late final GeneratedColumn<String> performers = GeneratedColumn<String>(
    'performers',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _performedKeyMeta = const VerificationMeta(
    'performedKey',
  );
  @override
  late final GeneratedColumn<String> performedKey = GeneratedColumn<String>(
    'performed_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cloudIdMeta = const VerificationMeta(
    'cloudId',
  );
  @override
  late final GeneratedColumn<String> cloudId = GeneratedColumn<String>(
    'cloud_id',
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
    performedKey,
    cloudId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tune_recording';
  @override
  VerificationContext validateIntegrity(
    Insertable<TuneRecordingData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tune_id')) {
      context.handle(
        _tuneIdMeta,
        tuneId.isAcceptableOrUnknown(data['tune_id']!, _tuneIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tuneIdMeta);
    }
    if (data.containsKey('recording_id')) {
      context.handle(
        _recordingIdMeta,
        recordingId.isAcceptableOrUnknown(
          data['recording_id']!,
          _recordingIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordingIdMeta);
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    }
    if (data.containsKey('performers')) {
      context.handle(
        _performersMeta,
        performers.isAcceptableOrUnknown(data['performers']!, _performersMeta),
      );
    }
    if (data.containsKey('performed_key')) {
      context.handle(
        _performedKeyMeta,
        performedKey.isAcceptableOrUnknown(
          data['performed_key']!,
          _performedKeyMeta,
        ),
      );
    }
    if (data.containsKey('cloud_id')) {
      context.handle(
        _cloudIdMeta,
        cloudId.isAcceptableOrUnknown(data['cloud_id']!, _cloudIdMeta),
      );
    }
    return context;
  }

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
        DriftSqlType.double,
        data['${effectivePrefix}start_time'],
      ),
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}end_time'],
      ),
      performers: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}performers'],
      ),
      performedKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}performed_key'],
      ),
      cloudId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_id'],
      ),
    );
  }

  @override
  $TuneRecordingTable createAlias(String alias) {
    return $TuneRecordingTable(attachedDatabase, alias);
  }
}

class TuneRecordingData extends DataClass
    implements Insertable<TuneRecordingData> {
  final int tuneId;
  final int recordingId;

  /// Start timestamp in seconds (fractional, hundredths precision)
  final double? startTime;

  /// End timestamp in seconds (fractional, hundredths precision)
  final double? endTime;

  /// Free text for names of performers if known
  final String? performers;

  /// Key the tune was performed in on this recording (may differ from the
  /// tune's canonical key, e.g. a session recorded in G vs. the usual D)
  final String? performedKey;
  final String? cloudId;
  const TuneRecordingData({
    required this.tuneId,
    required this.recordingId,
    this.startTime,
    this.endTime,
    this.performers,
    this.performedKey,
    this.cloudId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tune_id'] = Variable<int>(tuneId);
    map['recording_id'] = Variable<int>(recordingId);
    if (!nullToAbsent || startTime != null) {
      map['start_time'] = Variable<double>(startTime);
    }
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<double>(endTime);
    }
    if (!nullToAbsent || performers != null) {
      map['performers'] = Variable<String>(performers);
    }
    if (!nullToAbsent || performedKey != null) {
      map['performed_key'] = Variable<String>(performedKey);
    }
    if (!nullToAbsent || cloudId != null) {
      map['cloud_id'] = Variable<String>(cloudId);
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
      performedKey: performedKey == null && nullToAbsent
          ? const Value.absent()
          : Value(performedKey),
      cloudId: cloudId == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudId),
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
      startTime: serializer.fromJson<double?>(json['startTime']),
      endTime: serializer.fromJson<double?>(json['endTime']),
      performers: serializer.fromJson<String?>(json['performers']),
      performedKey: serializer.fromJson<String?>(json['performedKey']),
      cloudId: serializer.fromJson<String?>(json['cloudId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tuneId': serializer.toJson<int>(tuneId),
      'recordingId': serializer.toJson<int>(recordingId),
      'startTime': serializer.toJson<double?>(startTime),
      'endTime': serializer.toJson<double?>(endTime),
      'performers': serializer.toJson<String?>(performers),
      'performedKey': serializer.toJson<String?>(performedKey),
      'cloudId': serializer.toJson<String?>(cloudId),
    };
  }

  TuneRecordingData copyWith({
    int? tuneId,
    int? recordingId,
    Value<double?> startTime = const Value.absent(),
    Value<double?> endTime = const Value.absent(),
    Value<String?> performers = const Value.absent(),
    Value<String?> performedKey = const Value.absent(),
    Value<String?> cloudId = const Value.absent(),
  }) => TuneRecordingData(
    tuneId: tuneId ?? this.tuneId,
    recordingId: recordingId ?? this.recordingId,
    startTime: startTime.present ? startTime.value : this.startTime,
    endTime: endTime.present ? endTime.value : this.endTime,
    performers: performers.present ? performers.value : this.performers,
    performedKey: performedKey.present ? performedKey.value : this.performedKey,
    cloudId: cloudId.present ? cloudId.value : this.cloudId,
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
      performedKey: data.performedKey.present
          ? data.performedKey.value
          : this.performedKey,
      cloudId: data.cloudId.present ? data.cloudId.value : this.cloudId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TuneRecordingData(')
          ..write('tuneId: $tuneId, ')
          ..write('recordingId: $recordingId, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('performers: $performers, ')
          ..write('performedKey: $performedKey, ')
          ..write('cloudId: $cloudId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    tuneId,
    recordingId,
    startTime,
    endTime,
    performers,
    performedKey,
    cloudId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TuneRecordingData &&
          other.tuneId == this.tuneId &&
          other.recordingId == this.recordingId &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.performers == this.performers &&
          other.performedKey == this.performedKey &&
          other.cloudId == this.cloudId);
}

class TuneRecordingCompanion extends UpdateCompanion<TuneRecordingData> {
  final Value<int> tuneId;
  final Value<int> recordingId;
  final Value<double?> startTime;
  final Value<double?> endTime;
  final Value<String?> performers;
  final Value<String?> performedKey;
  final Value<String?> cloudId;
  final Value<int> rowid;
  const TuneRecordingCompanion({
    this.tuneId = const Value.absent(),
    this.recordingId = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.performers = const Value.absent(),
    this.performedKey = const Value.absent(),
    this.cloudId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TuneRecordingCompanion.insert({
    required int tuneId,
    required int recordingId,
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.performers = const Value.absent(),
    this.performedKey = const Value.absent(),
    this.cloudId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : tuneId = Value(tuneId),
       recordingId = Value(recordingId);
  static Insertable<TuneRecordingData> custom({
    Expression<int>? tuneId,
    Expression<int>? recordingId,
    Expression<double>? startTime,
    Expression<double>? endTime,
    Expression<String>? performers,
    Expression<String>? performedKey,
    Expression<String>? cloudId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tuneId != null) 'tune_id': tuneId,
      if (recordingId != null) 'recording_id': recordingId,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (performers != null) 'performers': performers,
      if (performedKey != null) 'performed_key': performedKey,
      if (cloudId != null) 'cloud_id': cloudId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TuneRecordingCompanion copyWith({
    Value<int>? tuneId,
    Value<int>? recordingId,
    Value<double?>? startTime,
    Value<double?>? endTime,
    Value<String?>? performers,
    Value<String?>? performedKey,
    Value<String?>? cloudId,
    Value<int>? rowid,
  }) {
    return TuneRecordingCompanion(
      tuneId: tuneId ?? this.tuneId,
      recordingId: recordingId ?? this.recordingId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      performers: performers ?? this.performers,
      performedKey: performedKey ?? this.performedKey,
      cloudId: cloudId ?? this.cloudId,
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
      map['start_time'] = Variable<double>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<double>(endTime.value);
    }
    if (performers.present) {
      map['performers'] = Variable<String>(performers.value);
    }
    if (performedKey.present) {
      map['performed_key'] = Variable<String>(performedKey.value);
    }
    if (cloudId.present) {
      map['cloud_id'] = Variable<String>(cloudId.value);
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
          ..write('performedKey: $performedKey, ')
          ..write('cloudId: $cloudId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TuneSetsTable extends TuneSets with TableInfo<$TuneSetsTable, TuneSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TuneSetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modifiedAtMeta = const VerificationMeta(
    'modifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> modifiedAt = GeneratedColumn<DateTime>(
    'modified_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cloudIdMeta = const VerificationMeta(
    'cloudId',
  );
  @override
  late final GeneratedColumn<String> cloudId = GeneratedColumn<String>(
    'cloud_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    createdAt,
    modifiedAt,
    cloudId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tune_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<TuneSet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('modified_at')) {
      context.handle(
        _modifiedAtMeta,
        modifiedAt.isAcceptableOrUnknown(data['modified_at']!, _modifiedAtMeta),
      );
    }
    if (data.containsKey('cloud_id')) {
      context.handle(
        _cloudIdMeta,
        cloudId.isAcceptableOrUnknown(data['cloud_id']!, _cloudIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TuneSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TuneSet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      modifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modified_at'],
      ),
      cloudId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_id'],
      ),
    );
  }

  @override
  $TuneSetsTable createAlias(String alias) {
    return $TuneSetsTable(attachedDatabase, alias);
  }
}

class TuneSet extends DataClass implements Insertable<TuneSet> {
  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime? modifiedAt;
  final String? cloudId;
  const TuneSet({
    required this.id,
    required this.name,
    required this.createdAt,
    this.modifiedAt,
    this.cloudId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || modifiedAt != null) {
      map['modified_at'] = Variable<DateTime>(modifiedAt);
    }
    if (!nullToAbsent || cloudId != null) {
      map['cloud_id'] = Variable<String>(cloudId);
    }
    return map;
  }

  TuneSetsCompanion toCompanion(bool nullToAbsent) {
    return TuneSetsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      modifiedAt: modifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(modifiedAt),
      cloudId: cloudId == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudId),
    );
  }

  factory TuneSet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TuneSet(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      modifiedAt: serializer.fromJson<DateTime?>(json['modifiedAt']),
      cloudId: serializer.fromJson<String?>(json['cloudId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'modifiedAt': serializer.toJson<DateTime?>(modifiedAt),
      'cloudId': serializer.toJson<String?>(cloudId),
    };
  }

  TuneSet copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    Value<DateTime?> modifiedAt = const Value.absent(),
    Value<String?> cloudId = const Value.absent(),
  }) => TuneSet(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    modifiedAt: modifiedAt.present ? modifiedAt.value : this.modifiedAt,
    cloudId: cloudId.present ? cloudId.value : this.cloudId,
  );
  TuneSet copyWithCompanion(TuneSetsCompanion data) {
    return TuneSet(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      modifiedAt: data.modifiedAt.present
          ? data.modifiedAt.value
          : this.modifiedAt,
      cloudId: data.cloudId.present ? data.cloudId.value : this.cloudId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TuneSet(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('cloudId: $cloudId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt, modifiedAt, cloudId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TuneSet &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.modifiedAt == this.modifiedAt &&
          other.cloudId == this.cloudId);
}

class TuneSetsCompanion extends UpdateCompanion<TuneSet> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<DateTime?> modifiedAt;
  final Value<String?> cloudId;
  const TuneSetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.cloudId = const Value.absent(),
  });
  TuneSetsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required DateTime createdAt,
    this.modifiedAt = const Value.absent(),
    this.cloudId = const Value.absent(),
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<TuneSet> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? modifiedAt,
    Expression<String>? cloudId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (modifiedAt != null) 'modified_at': modifiedAt,
      if (cloudId != null) 'cloud_id': cloudId,
    });
  }

  TuneSetsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<DateTime?>? modifiedAt,
    Value<String?>? cloudId,
  }) {
    return TuneSetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      cloudId: cloudId ?? this.cloudId,
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
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (modifiedAt.present) {
      map['modified_at'] = Variable<DateTime>(modifiedAt.value);
    }
    if (cloudId.present) {
      map['cloud_id'] = Variable<String>(cloudId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TuneSetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('cloudId: $cloudId')
          ..write(')'))
        .toString();
  }
}

class $SetTuneTable extends SetTune with TableInfo<$SetTuneTable, SetTuneData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SetTuneTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
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
  static const VerificationMeta _setIdMeta = const VerificationMeta('setId');
  @override
  late final GeneratedColumn<int> setId = GeneratedColumn<int>(
    'set_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tune_sets (id)',
    ),
  );
  static const VerificationMeta _tuneIdMeta = const VerificationMeta('tuneId');
  @override
  late final GeneratedColumn<int> tuneId = GeneratedColumn<int>(
    'tune_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tunes (id)',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cloudIdMeta = const VerificationMeta(
    'cloudId',
  );
  @override
  late final GeneratedColumn<String> cloudId = GeneratedColumn<String>(
    'cloud_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    setId,
    tuneId,
    position,
    key,
    cloudId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'set_tune';
  @override
  VerificationContext validateIntegrity(
    Insertable<SetTuneData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('set_id')) {
      context.handle(
        _setIdMeta,
        setId.isAcceptableOrUnknown(data['set_id']!, _setIdMeta),
      );
    } else if (isInserting) {
      context.missing(_setIdMeta);
    }
    if (data.containsKey('tune_id')) {
      context.handle(
        _tuneIdMeta,
        tuneId.isAcceptableOrUnknown(data['tune_id']!, _tuneIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tuneIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    }
    if (data.containsKey('cloud_id')) {
      context.handle(
        _cloudIdMeta,
        cloudId.isAcceptableOrUnknown(data['cloud_id']!, _cloudIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SetTuneData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SetTuneData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      setId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}set_id'],
      )!,
      tuneId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tune_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      ),
      cloudId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_id'],
      ),
    );
  }

  @override
  $SetTuneTable createAlias(String alias) {
    return $SetTuneTable(attachedDatabase, alias);
  }
}

class SetTuneData extends DataClass implements Insertable<SetTuneData> {
  final int id;
  final int setId;
  final int tuneId;
  final int position;
  final String? key;
  final String? cloudId;
  const SetTuneData({
    required this.id,
    required this.setId,
    required this.tuneId,
    required this.position,
    this.key,
    this.cloudId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['set_id'] = Variable<int>(setId);
    map['tune_id'] = Variable<int>(tuneId);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || key != null) {
      map['key'] = Variable<String>(key);
    }
    if (!nullToAbsent || cloudId != null) {
      map['cloud_id'] = Variable<String>(cloudId);
    }
    return map;
  }

  SetTuneCompanion toCompanion(bool nullToAbsent) {
    return SetTuneCompanion(
      id: Value(id),
      setId: Value(setId),
      tuneId: Value(tuneId),
      position: Value(position),
      key: key == null && nullToAbsent ? const Value.absent() : Value(key),
      cloudId: cloudId == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudId),
    );
  }

  factory SetTuneData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SetTuneData(
      id: serializer.fromJson<int>(json['id']),
      setId: serializer.fromJson<int>(json['setId']),
      tuneId: serializer.fromJson<int>(json['tuneId']),
      position: serializer.fromJson<int>(json['position']),
      key: serializer.fromJson<String?>(json['key']),
      cloudId: serializer.fromJson<String?>(json['cloudId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'setId': serializer.toJson<int>(setId),
      'tuneId': serializer.toJson<int>(tuneId),
      'position': serializer.toJson<int>(position),
      'key': serializer.toJson<String?>(key),
      'cloudId': serializer.toJson<String?>(cloudId),
    };
  }

  SetTuneData copyWith({
    int? id,
    int? setId,
    int? tuneId,
    int? position,
    Value<String?> key = const Value.absent(),
    Value<String?> cloudId = const Value.absent(),
  }) => SetTuneData(
    id: id ?? this.id,
    setId: setId ?? this.setId,
    tuneId: tuneId ?? this.tuneId,
    position: position ?? this.position,
    key: key.present ? key.value : this.key,
    cloudId: cloudId.present ? cloudId.value : this.cloudId,
  );
  SetTuneData copyWithCompanion(SetTuneCompanion data) {
    return SetTuneData(
      id: data.id.present ? data.id.value : this.id,
      setId: data.setId.present ? data.setId.value : this.setId,
      tuneId: data.tuneId.present ? data.tuneId.value : this.tuneId,
      position: data.position.present ? data.position.value : this.position,
      key: data.key.present ? data.key.value : this.key,
      cloudId: data.cloudId.present ? data.cloudId.value : this.cloudId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SetTuneData(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('tuneId: $tuneId, ')
          ..write('position: $position, ')
          ..write('key: $key, ')
          ..write('cloudId: $cloudId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, setId, tuneId, position, key, cloudId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SetTuneData &&
          other.id == this.id &&
          other.setId == this.setId &&
          other.tuneId == this.tuneId &&
          other.position == this.position &&
          other.key == this.key &&
          other.cloudId == this.cloudId);
}

class SetTuneCompanion extends UpdateCompanion<SetTuneData> {
  final Value<int> id;
  final Value<int> setId;
  final Value<int> tuneId;
  final Value<int> position;
  final Value<String?> key;
  final Value<String?> cloudId;
  const SetTuneCompanion({
    this.id = const Value.absent(),
    this.setId = const Value.absent(),
    this.tuneId = const Value.absent(),
    this.position = const Value.absent(),
    this.key = const Value.absent(),
    this.cloudId = const Value.absent(),
  });
  SetTuneCompanion.insert({
    this.id = const Value.absent(),
    required int setId,
    required int tuneId,
    required int position,
    this.key = const Value.absent(),
    this.cloudId = const Value.absent(),
  }) : setId = Value(setId),
       tuneId = Value(tuneId),
       position = Value(position);
  static Insertable<SetTuneData> custom({
    Expression<int>? id,
    Expression<int>? setId,
    Expression<int>? tuneId,
    Expression<int>? position,
    Expression<String>? key,
    Expression<String>? cloudId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (setId != null) 'set_id': setId,
      if (tuneId != null) 'tune_id': tuneId,
      if (position != null) 'position': position,
      if (key != null) 'key': key,
      if (cloudId != null) 'cloud_id': cloudId,
    });
  }

  SetTuneCompanion copyWith({
    Value<int>? id,
    Value<int>? setId,
    Value<int>? tuneId,
    Value<int>? position,
    Value<String?>? key,
    Value<String?>? cloudId,
  }) {
    return SetTuneCompanion(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      tuneId: tuneId ?? this.tuneId,
      position: position ?? this.position,
      key: key ?? this.key,
      cloudId: cloudId ?? this.cloudId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (setId.present) {
      map['set_id'] = Variable<int>(setId.value);
    }
    if (tuneId.present) {
      map['tune_id'] = Variable<int>(tuneId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (cloudId.present) {
      map['cloud_id'] = Variable<String>(cloudId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SetTuneCompanion(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('tuneId: $tuneId, ')
          ..write('position: $position, ')
          ..write('key: $key, ')
          ..write('cloudId: $cloudId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RecordingsTable recordings = $RecordingsTable(this);
  late final $TunesTable tunes = $TunesTable(this);
  late final $TuneRecordingTable tuneRecording = $TuneRecordingTable(this);
  late final $TuneSetsTable tuneSets = $TuneSetsTable(this);
  late final $SetTuneTable setTune = $SetTuneTable(this);
  late final TuneDao tuneDao = TuneDao(this as AppDatabase);
  late final RecordingDao recordingDao = RecordingDao(this as AppDatabase);
  late final TuneRecordingDao tuneRecordingDao = TuneRecordingDao(
    this as AppDatabase,
  );
  late final SetDao setDao = SetDao(this as AppDatabase);
  late final SetTuneDao setTuneDao = SetTuneDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    recordings,
    tunes,
    tuneRecording,
    tuneSets,
    setTune,
  ];
}

typedef $$RecordingsTableCreateCompanionBuilder =
    RecordingsCompanion Function({
      Value<int> id,
      required String name,
      required String url,
      Value<String?> performers,
      required DateTime createdAt,
      Value<DateTime?> modifiedAt,
      Value<String?> cloudId,
    });
typedef $$RecordingsTableUpdateCompanionBuilder =
    RecordingsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> url,
      Value<String?> performers,
      Value<DateTime> createdAt,
      Value<DateTime?> modifiedAt,
      Value<String?> cloudId,
    });

class $$RecordingsTableFilterComposer
    extends Composer<_$AppDatabase, $RecordingsTable> {
  $$RecordingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get performers => $composableBuilder(
    column: $table.performers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudId => $composableBuilder(
    column: $table.cloudId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecordingsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecordingsTable> {
  $$RecordingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get performers => $composableBuilder(
    column: $table.performers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudId => $composableBuilder(
    column: $table.cloudId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecordingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecordingsTable> {
  $$RecordingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get performers => $composableBuilder(
    column: $table.performers,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cloudId =>
      $composableBuilder(column: $table.cloudId, builder: (column) => column);
}

class $$RecordingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecordingsTable,
          Recording,
          $$RecordingsTableFilterComposer,
          $$RecordingsTableOrderingComposer,
          $$RecordingsTableAnnotationComposer,
          $$RecordingsTableCreateCompanionBuilder,
          $$RecordingsTableUpdateCompanionBuilder,
          (
            Recording,
            BaseReferences<_$AppDatabase, $RecordingsTable, Recording>,
          ),
          Recording,
          PrefetchHooks Function()
        > {
  $$RecordingsTableTableManager(_$AppDatabase db, $RecordingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String?> performers = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> modifiedAt = const Value.absent(),
                Value<String?> cloudId = const Value.absent(),
              }) => RecordingsCompanion(
                id: id,
                name: name,
                url: url,
                performers: performers,
                createdAt: createdAt,
                modifiedAt: modifiedAt,
                cloudId: cloudId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String url,
                Value<String?> performers = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> modifiedAt = const Value.absent(),
                Value<String?> cloudId = const Value.absent(),
              }) => RecordingsCompanion.insert(
                id: id,
                name: name,
                url: url,
                performers: performers,
                createdAt: createdAt,
                modifiedAt: modifiedAt,
                cloudId: cloudId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecordingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecordingsTable,
      Recording,
      $$RecordingsTableFilterComposer,
      $$RecordingsTableOrderingComposer,
      $$RecordingsTableAnnotationComposer,
      $$RecordingsTableCreateCompanionBuilder,
      $$RecordingsTableUpdateCompanionBuilder,
      (Recording, BaseReferences<_$AppDatabase, $RecordingsTable, Recording>),
      Recording,
      PrefetchHooks Function()
    >;
typedef $$TunesTableCreateCompanionBuilder =
    TunesCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> abc,
      Value<String?> abcSvg,
      Value<int?> tsId,
      Value<String?> from,
      Value<TuneStatus?> status,
      Value<String?> key,
      Value<TuneType?> type,
      Value<String?> genre,
      required DateTime createdAt,
      Value<DateTime?> modifiedAt,
      Value<String?> cloudId,
    });
typedef $$TunesTableUpdateCompanionBuilder =
    TunesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> abc,
      Value<String?> abcSvg,
      Value<int?> tsId,
      Value<String?> from,
      Value<TuneStatus?> status,
      Value<String?> key,
      Value<TuneType?> type,
      Value<String?> genre,
      Value<DateTime> createdAt,
      Value<DateTime?> modifiedAt,
      Value<String?> cloudId,
    });

final class $$TunesTableReferences
    extends BaseReferences<_$AppDatabase, $TunesTable, Tune> {
  $$TunesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SetTuneTable, List<SetTuneData>>
  _setTuneRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.setTune,
    aliasName: $_aliasNameGenerator(db.tunes.id, db.setTune.tuneId),
  );

  $$SetTuneTableProcessedTableManager get setTuneRefs {
    final manager = $$SetTuneTableTableManager(
      $_db,
      $_db.setTune,
    ).filter((f) => f.tuneId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_setTuneRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TunesTableFilterComposer extends Composer<_$AppDatabase, $TunesTable> {
  $$TunesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get abc => $composableBuilder(
    column: $table.abc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get abcSvg => $composableBuilder(
    column: $table.abcSvg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tsId => $composableBuilder(
    column: $table.tsId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get from => $composableBuilder(
    column: $table.from,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TuneStatus?, TuneStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TuneType?, TuneType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudId => $composableBuilder(
    column: $table.cloudId,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> setTuneRefs(
    Expression<bool> Function($$SetTuneTableFilterComposer f) f,
  ) {
    final $$SetTuneTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setTune,
      getReferencedColumn: (t) => t.tuneId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetTuneTableFilterComposer(
            $db: $db,
            $table: $db.setTune,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TunesTableOrderingComposer
    extends Composer<_$AppDatabase, $TunesTable> {
  $$TunesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get abc => $composableBuilder(
    column: $table.abc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get abcSvg => $composableBuilder(
    column: $table.abcSvg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tsId => $composableBuilder(
    column: $table.tsId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get from => $composableBuilder(
    column: $table.from,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudId => $composableBuilder(
    column: $table.cloudId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TunesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TunesTable> {
  $$TunesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get abc =>
      $composableBuilder(column: $table.abc, builder: (column) => column);

  GeneratedColumn<String> get abcSvg =>
      $composableBuilder(column: $table.abcSvg, builder: (column) => column);

  GeneratedColumn<int> get tsId =>
      $composableBuilder(column: $table.tsId, builder: (column) => column);

  GeneratedColumn<String> get from =>
      $composableBuilder(column: $table.from, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TuneStatus?, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TuneType?, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cloudId =>
      $composableBuilder(column: $table.cloudId, builder: (column) => column);

  Expression<T> setTuneRefs<T extends Object>(
    Expression<T> Function($$SetTuneTableAnnotationComposer a) f,
  ) {
    final $$SetTuneTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setTune,
      getReferencedColumn: (t) => t.tuneId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetTuneTableAnnotationComposer(
            $db: $db,
            $table: $db.setTune,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TunesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TunesTable,
          Tune,
          $$TunesTableFilterComposer,
          $$TunesTableOrderingComposer,
          $$TunesTableAnnotationComposer,
          $$TunesTableCreateCompanionBuilder,
          $$TunesTableUpdateCompanionBuilder,
          (Tune, $$TunesTableReferences),
          Tune,
          PrefetchHooks Function({bool setTuneRefs})
        > {
  $$TunesTableTableManager(_$AppDatabase db, $TunesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TunesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TunesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TunesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> abc = const Value.absent(),
                Value<String?> abcSvg = const Value.absent(),
                Value<int?> tsId = const Value.absent(),
                Value<String?> from = const Value.absent(),
                Value<TuneStatus?> status = const Value.absent(),
                Value<String?> key = const Value.absent(),
                Value<TuneType?> type = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> modifiedAt = const Value.absent(),
                Value<String?> cloudId = const Value.absent(),
              }) => TunesCompanion(
                id: id,
                name: name,
                abc: abc,
                abcSvg: abcSvg,
                tsId: tsId,
                from: from,
                status: status,
                key: key,
                type: type,
                genre: genre,
                createdAt: createdAt,
                modifiedAt: modifiedAt,
                cloudId: cloudId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> abc = const Value.absent(),
                Value<String?> abcSvg = const Value.absent(),
                Value<int?> tsId = const Value.absent(),
                Value<String?> from = const Value.absent(),
                Value<TuneStatus?> status = const Value.absent(),
                Value<String?> key = const Value.absent(),
                Value<TuneType?> type = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> modifiedAt = const Value.absent(),
                Value<String?> cloudId = const Value.absent(),
              }) => TunesCompanion.insert(
                id: id,
                name: name,
                abc: abc,
                abcSvg: abcSvg,
                tsId: tsId,
                from: from,
                status: status,
                key: key,
                type: type,
                genre: genre,
                createdAt: createdAt,
                modifiedAt: modifiedAt,
                cloudId: cloudId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TunesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({setTuneRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (setTuneRefs) db.setTune],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (setTuneRefs)
                    await $_getPrefetchedData<Tune, $TunesTable, SetTuneData>(
                      currentTable: table,
                      referencedTable: $$TunesTableReferences._setTuneRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$TunesTableReferences(db, table, p0).setTuneRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tuneId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TunesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TunesTable,
      Tune,
      $$TunesTableFilterComposer,
      $$TunesTableOrderingComposer,
      $$TunesTableAnnotationComposer,
      $$TunesTableCreateCompanionBuilder,
      $$TunesTableUpdateCompanionBuilder,
      (Tune, $$TunesTableReferences),
      Tune,
      PrefetchHooks Function({bool setTuneRefs})
    >;
typedef $$TuneRecordingTableCreateCompanionBuilder =
    TuneRecordingCompanion Function({
      required int tuneId,
      required int recordingId,
      Value<double?> startTime,
      Value<double?> endTime,
      Value<String?> performers,
      Value<String?> performedKey,
      Value<String?> cloudId,
      Value<int> rowid,
    });
typedef $$TuneRecordingTableUpdateCompanionBuilder =
    TuneRecordingCompanion Function({
      Value<int> tuneId,
      Value<int> recordingId,
      Value<double?> startTime,
      Value<double?> endTime,
      Value<String?> performers,
      Value<String?> performedKey,
      Value<String?> cloudId,
      Value<int> rowid,
    });

class $$TuneRecordingTableFilterComposer
    extends Composer<_$AppDatabase, $TuneRecordingTable> {
  $$TuneRecordingTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get tuneId => $composableBuilder(
    column: $table.tuneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recordingId => $composableBuilder(
    column: $table.recordingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get performers => $composableBuilder(
    column: $table.performers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get performedKey => $composableBuilder(
    column: $table.performedKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudId => $composableBuilder(
    column: $table.cloudId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TuneRecordingTableOrderingComposer
    extends Composer<_$AppDatabase, $TuneRecordingTable> {
  $$TuneRecordingTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get tuneId => $composableBuilder(
    column: $table.tuneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recordingId => $composableBuilder(
    column: $table.recordingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get performers => $composableBuilder(
    column: $table.performers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get performedKey => $composableBuilder(
    column: $table.performedKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudId => $composableBuilder(
    column: $table.cloudId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TuneRecordingTableAnnotationComposer
    extends Composer<_$AppDatabase, $TuneRecordingTable> {
  $$TuneRecordingTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get tuneId =>
      $composableBuilder(column: $table.tuneId, builder: (column) => column);

  GeneratedColumn<int> get recordingId => $composableBuilder(
    column: $table.recordingId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<double> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<String> get performers => $composableBuilder(
    column: $table.performers,
    builder: (column) => column,
  );

  GeneratedColumn<String> get performedKey => $composableBuilder(
    column: $table.performedKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cloudId =>
      $composableBuilder(column: $table.cloudId, builder: (column) => column);
}

class $$TuneRecordingTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TuneRecordingTable,
          TuneRecordingData,
          $$TuneRecordingTableFilterComposer,
          $$TuneRecordingTableOrderingComposer,
          $$TuneRecordingTableAnnotationComposer,
          $$TuneRecordingTableCreateCompanionBuilder,
          $$TuneRecordingTableUpdateCompanionBuilder,
          (
            TuneRecordingData,
            BaseReferences<
              _$AppDatabase,
              $TuneRecordingTable,
              TuneRecordingData
            >,
          ),
          TuneRecordingData,
          PrefetchHooks Function()
        > {
  $$TuneRecordingTableTableManager(_$AppDatabase db, $TuneRecordingTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TuneRecordingTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TuneRecordingTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TuneRecordingTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> tuneId = const Value.absent(),
                Value<int> recordingId = const Value.absent(),
                Value<double?> startTime = const Value.absent(),
                Value<double?> endTime = const Value.absent(),
                Value<String?> performers = const Value.absent(),
                Value<String?> performedKey = const Value.absent(),
                Value<String?> cloudId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TuneRecordingCompanion(
                tuneId: tuneId,
                recordingId: recordingId,
                startTime: startTime,
                endTime: endTime,
                performers: performers,
                performedKey: performedKey,
                cloudId: cloudId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int tuneId,
                required int recordingId,
                Value<double?> startTime = const Value.absent(),
                Value<double?> endTime = const Value.absent(),
                Value<String?> performers = const Value.absent(),
                Value<String?> performedKey = const Value.absent(),
                Value<String?> cloudId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TuneRecordingCompanion.insert(
                tuneId: tuneId,
                recordingId: recordingId,
                startTime: startTime,
                endTime: endTime,
                performers: performers,
                performedKey: performedKey,
                cloudId: cloudId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TuneRecordingTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TuneRecordingTable,
      TuneRecordingData,
      $$TuneRecordingTableFilterComposer,
      $$TuneRecordingTableOrderingComposer,
      $$TuneRecordingTableAnnotationComposer,
      $$TuneRecordingTableCreateCompanionBuilder,
      $$TuneRecordingTableUpdateCompanionBuilder,
      (
        TuneRecordingData,
        BaseReferences<_$AppDatabase, $TuneRecordingTable, TuneRecordingData>,
      ),
      TuneRecordingData,
      PrefetchHooks Function()
    >;
typedef $$TuneSetsTableCreateCompanionBuilder =
    TuneSetsCompanion Function({
      Value<int> id,
      required String name,
      required DateTime createdAt,
      Value<DateTime?> modifiedAt,
      Value<String?> cloudId,
    });
typedef $$TuneSetsTableUpdateCompanionBuilder =
    TuneSetsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<DateTime> createdAt,
      Value<DateTime?> modifiedAt,
      Value<String?> cloudId,
    });

final class $$TuneSetsTableReferences
    extends BaseReferences<_$AppDatabase, $TuneSetsTable, TuneSet> {
  $$TuneSetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SetTuneTable, List<SetTuneData>>
  _setTuneRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.setTune,
    aliasName: $_aliasNameGenerator(db.tuneSets.id, db.setTune.setId),
  );

  $$SetTuneTableProcessedTableManager get setTuneRefs {
    final manager = $$SetTuneTableTableManager(
      $_db,
      $_db.setTune,
    ).filter((f) => f.setId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_setTuneRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TuneSetsTableFilterComposer
    extends Composer<_$AppDatabase, $TuneSetsTable> {
  $$TuneSetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudId => $composableBuilder(
    column: $table.cloudId,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> setTuneRefs(
    Expression<bool> Function($$SetTuneTableFilterComposer f) f,
  ) {
    final $$SetTuneTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setTune,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetTuneTableFilterComposer(
            $db: $db,
            $table: $db.setTune,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TuneSetsTableOrderingComposer
    extends Composer<_$AppDatabase, $TuneSetsTable> {
  $$TuneSetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudId => $composableBuilder(
    column: $table.cloudId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TuneSetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TuneSetsTable> {
  $$TuneSetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cloudId =>
      $composableBuilder(column: $table.cloudId, builder: (column) => column);

  Expression<T> setTuneRefs<T extends Object>(
    Expression<T> Function($$SetTuneTableAnnotationComposer a) f,
  ) {
    final $$SetTuneTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setTune,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetTuneTableAnnotationComposer(
            $db: $db,
            $table: $db.setTune,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TuneSetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TuneSetsTable,
          TuneSet,
          $$TuneSetsTableFilterComposer,
          $$TuneSetsTableOrderingComposer,
          $$TuneSetsTableAnnotationComposer,
          $$TuneSetsTableCreateCompanionBuilder,
          $$TuneSetsTableUpdateCompanionBuilder,
          (TuneSet, $$TuneSetsTableReferences),
          TuneSet,
          PrefetchHooks Function({bool setTuneRefs})
        > {
  $$TuneSetsTableTableManager(_$AppDatabase db, $TuneSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TuneSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TuneSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TuneSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> modifiedAt = const Value.absent(),
                Value<String?> cloudId = const Value.absent(),
              }) => TuneSetsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                modifiedAt: modifiedAt,
                cloudId: cloudId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required DateTime createdAt,
                Value<DateTime?> modifiedAt = const Value.absent(),
                Value<String?> cloudId = const Value.absent(),
              }) => TuneSetsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                modifiedAt: modifiedAt,
                cloudId: cloudId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TuneSetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({setTuneRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (setTuneRefs) db.setTune],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (setTuneRefs)
                    await $_getPrefetchedData<
                      TuneSet,
                      $TuneSetsTable,
                      SetTuneData
                    >(
                      currentTable: table,
                      referencedTable: $$TuneSetsTableReferences
                          ._setTuneRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TuneSetsTableReferences(db, table, p0).setTuneRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.setId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TuneSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TuneSetsTable,
      TuneSet,
      $$TuneSetsTableFilterComposer,
      $$TuneSetsTableOrderingComposer,
      $$TuneSetsTableAnnotationComposer,
      $$TuneSetsTableCreateCompanionBuilder,
      $$TuneSetsTableUpdateCompanionBuilder,
      (TuneSet, $$TuneSetsTableReferences),
      TuneSet,
      PrefetchHooks Function({bool setTuneRefs})
    >;
typedef $$SetTuneTableCreateCompanionBuilder =
    SetTuneCompanion Function({
      Value<int> id,
      required int setId,
      required int tuneId,
      required int position,
      Value<String?> key,
      Value<String?> cloudId,
    });
typedef $$SetTuneTableUpdateCompanionBuilder =
    SetTuneCompanion Function({
      Value<int> id,
      Value<int> setId,
      Value<int> tuneId,
      Value<int> position,
      Value<String?> key,
      Value<String?> cloudId,
    });

final class $$SetTuneTableReferences
    extends BaseReferences<_$AppDatabase, $SetTuneTable, SetTuneData> {
  $$SetTuneTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TuneSetsTable _setIdTable(_$AppDatabase db) => db.tuneSets
      .createAlias($_aliasNameGenerator(db.setTune.setId, db.tuneSets.id));

  $$TuneSetsTableProcessedTableManager get setId {
    final $_column = $_itemColumn<int>('set_id')!;

    final manager = $$TuneSetsTableTableManager(
      $_db,
      $_db.tuneSets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_setIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TunesTable _tuneIdTable(_$AppDatabase db) => db.tunes.createAlias(
    $_aliasNameGenerator(db.setTune.tuneId, db.tunes.id),
  );

  $$TunesTableProcessedTableManager get tuneId {
    final $_column = $_itemColumn<int>('tune_id')!;

    final manager = $$TunesTableTableManager(
      $_db,
      $_db.tunes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tuneIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SetTuneTableFilterComposer
    extends Composer<_$AppDatabase, $SetTuneTable> {
  $$SetTuneTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudId => $composableBuilder(
    column: $table.cloudId,
    builder: (column) => ColumnFilters(column),
  );

  $$TuneSetsTableFilterComposer get setId {
    final $$TuneSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.tuneSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TuneSetsTableFilterComposer(
            $db: $db,
            $table: $db.tuneSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TunesTableFilterComposer get tuneId {
    final $$TunesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tuneId,
      referencedTable: $db.tunes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TunesTableFilterComposer(
            $db: $db,
            $table: $db.tunes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetTuneTableOrderingComposer
    extends Composer<_$AppDatabase, $SetTuneTable> {
  $$SetTuneTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudId => $composableBuilder(
    column: $table.cloudId,
    builder: (column) => ColumnOrderings(column),
  );

  $$TuneSetsTableOrderingComposer get setId {
    final $$TuneSetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.tuneSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TuneSetsTableOrderingComposer(
            $db: $db,
            $table: $db.tuneSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TunesTableOrderingComposer get tuneId {
    final $$TunesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tuneId,
      referencedTable: $db.tunes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TunesTableOrderingComposer(
            $db: $db,
            $table: $db.tunes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetTuneTableAnnotationComposer
    extends Composer<_$AppDatabase, $SetTuneTable> {
  $$SetTuneTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get cloudId =>
      $composableBuilder(column: $table.cloudId, builder: (column) => column);

  $$TuneSetsTableAnnotationComposer get setId {
    final $$TuneSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.tuneSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TuneSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.tuneSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TunesTableAnnotationComposer get tuneId {
    final $$TunesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tuneId,
      referencedTable: $db.tunes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TunesTableAnnotationComposer(
            $db: $db,
            $table: $db.tunes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetTuneTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SetTuneTable,
          SetTuneData,
          $$SetTuneTableFilterComposer,
          $$SetTuneTableOrderingComposer,
          $$SetTuneTableAnnotationComposer,
          $$SetTuneTableCreateCompanionBuilder,
          $$SetTuneTableUpdateCompanionBuilder,
          (SetTuneData, $$SetTuneTableReferences),
          SetTuneData,
          PrefetchHooks Function({bool setId, bool tuneId})
        > {
  $$SetTuneTableTableManager(_$AppDatabase db, $SetTuneTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SetTuneTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SetTuneTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SetTuneTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> setId = const Value.absent(),
                Value<int> tuneId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String?> key = const Value.absent(),
                Value<String?> cloudId = const Value.absent(),
              }) => SetTuneCompanion(
                id: id,
                setId: setId,
                tuneId: tuneId,
                position: position,
                key: key,
                cloudId: cloudId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int setId,
                required int tuneId,
                required int position,
                Value<String?> key = const Value.absent(),
                Value<String?> cloudId = const Value.absent(),
              }) => SetTuneCompanion.insert(
                id: id,
                setId: setId,
                tuneId: tuneId,
                position: position,
                key: key,
                cloudId: cloudId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SetTuneTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({setId = false, tuneId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (setId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.setId,
                                referencedTable: $$SetTuneTableReferences
                                    ._setIdTable(db),
                                referencedColumn: $$SetTuneTableReferences
                                    ._setIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (tuneId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tuneId,
                                referencedTable: $$SetTuneTableReferences
                                    ._tuneIdTable(db),
                                referencedColumn: $$SetTuneTableReferences
                                    ._tuneIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SetTuneTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SetTuneTable,
      SetTuneData,
      $$SetTuneTableFilterComposer,
      $$SetTuneTableOrderingComposer,
      $$SetTuneTableAnnotationComposer,
      $$SetTuneTableCreateCompanionBuilder,
      $$SetTuneTableUpdateCompanionBuilder,
      (SetTuneData, $$SetTuneTableReferences),
      SetTuneData,
      PrefetchHooks Function({bool setId, bool tuneId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RecordingsTableTableManager get recordings =>
      $$RecordingsTableTableManager(_db, _db.recordings);
  $$TunesTableTableManager get tunes =>
      $$TunesTableTableManager(_db, _db.tunes);
  $$TuneRecordingTableTableManager get tuneRecording =>
      $$TuneRecordingTableTableManager(_db, _db.tuneRecording);
  $$TuneSetsTableTableManager get tuneSets =>
      $$TuneSetsTableTableManager(_db, _db.tuneSets);
  $$SetTuneTableTableManager get setTune =>
      $$SetTuneTableTableManager(_db, _db.setTune);
}
