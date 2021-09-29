// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: camel_case_types

import 'dart:typed_data';

import 'package:objectbox/flatbuffers/flat_buffers.dart' as fb;
import 'package:objectbox/internal.dart'; // generated code can access "internal" functionality
import 'package:objectbox/objectbox.dart';
import 'package:objectbox_flutter_libs/objectbox_flutter_libs.dart';

import 'object_box_entity.dart';

export 'package:objectbox/objectbox.dart'; // so that callers only have to import this file

final _entities = <ModelEntity>[
  ModelEntity(
      id: const IdUid(1, 4854730747853972500),
      name: 'DocEntity',
      lastPropertyId: const IdUid(3, 1752656350797282282),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 3560900380125780084),
            name: 'id',
            type: 6,
            flags: 129),
        ModelProperty(
            id: const IdUid(2, 8649292410431973453),
            name: 'key',
            type: 9,
            flags: 2048,
            indexId: const IdUid(1, 8705665511744785782)),
        ModelProperty(
            id: const IdUid(3, 1752656350797282282),
            name: 'value',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(2, 5653666955598801934),
      name: 'LocalDocEntity',
      lastPropertyId: const IdUid(3, 603761560879078782),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 8783753655029484921),
            name: 'id',
            type: 6,
            flags: 129),
        ModelProperty(
            id: const IdUid(2, 8202346143928025691),
            name: 'key',
            type: 9,
            flags: 2048,
            indexId: const IdUid(2, 8514582379727866698)),
        ModelProperty(
            id: const IdUid(3, 603761560879078782),
            name: 'value',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(3, 3091503247941740088),
      name: 'SequenceEntity',
      lastPropertyId: const IdUid(3, 3498585876108965148),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 8971544107699572723),
            name: 'id',
            type: 6,
            flags: 129),
        ModelProperty(
            id: const IdUid(2, 2539298652646182720),
            name: 'key',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 3498585876108965148),
            name: 'value',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(4, 641085905396968232),
      name: 'ViewDocMetaEntity',
      lastPropertyId: const IdUid(3, 2870714443298554116),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 2139584183479834493),
            name: 'id',
            type: 6,
            flags: 129),
        ModelProperty(
            id: const IdUid(2, 206341734760607277),
            name: 'key',
            type: 9,
            flags: 2048,
            indexId: const IdUid(3, 8598412494874542398)),
        ModelProperty(
            id: const IdUid(3, 2870714443298554116),
            name: 'value',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(5, 5267071683743213251),
      name: 'ViewKeyMetaEntity',
      lastPropertyId: const IdUid(3, 7449931206461472570),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 6619617028869102825),
            name: 'id',
            type: 6,
            flags: 129),
        ModelProperty(
            id: const IdUid(2, 5242110540656940172),
            name: 'key',
            type: 9,
            flags: 2048,
            indexId: const IdUid(4, 7758849780118126889)),
        ModelProperty(
            id: const IdUid(3, 7449931206461472570),
            name: 'value',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(6, 820739159260059303),
      name: 'ViewMetaEntity',
      lastPropertyId: const IdUid(3, 4570345311730615598),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 5830120471729097525),
            name: 'id',
            type: 6,
            flags: 129),
        ModelProperty(
            id: const IdUid(2, 9015251116945556721),
            name: 'key',
            type: 9,
            flags: 2048,
            indexId: const IdUid(5, 327414111484451485)),
        ModelProperty(
            id: const IdUid(3, 4570345311730615598),
            name: 'value',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[])
];

/// Open an ObjectBox store with the model declared in this file.
Future<Store> openStore(
        {String? directory,
        int? maxDBSizeInKB,
        int? fileMode,
        int? maxReaders,
        bool queriesCaseSensitiveDefault = true,
        String? macosApplicationGroup}) async =>
    Store(getObjectBoxModel(),
        directory: directory ?? (await defaultStoreDirectory()).path,
        maxDBSizeInKB: maxDBSizeInKB,
        fileMode: fileMode,
        maxReaders: maxReaders,
        queriesCaseSensitiveDefault: queriesCaseSensitiveDefault,
        macosApplicationGroup: macosApplicationGroup);

/// ObjectBox model definition, pass it to [Store] - Store(getObjectBoxModel())
ModelDefinition getObjectBoxModel() {
  final model = ModelInfo(
      entities: _entities,
      lastEntityId: const IdUid(6, 820739159260059303),
      lastIndexId: const IdUid(5, 327414111484451485),
      lastRelationId: const IdUid(0, 0),
      lastSequenceId: const IdUid(0, 0),
      retiredEntityUids: const [],
      retiredIndexUids: const [],
      retiredPropertyUids: const [],
      retiredRelationUids: const [],
      modelVersion: 5,
      modelVersionParserMinimum: 5,
      version: 1);

  final bindings = <Type, EntityDefinition>{
    DocEntity: EntityDefinition<DocEntity>(
        model: _entities[0],
        toOneRelations: (DocEntity object) => [],
        toManyRelations: (DocEntity object) => {},
        getId: (DocEntity object) => object.id,
        setId: (DocEntity object, int id) {
          object.id = id;
        },
        objectToFB: (DocEntity object, fb.Builder fbb) {
          final keyOffset = fbb.writeString(object.key);
          final valueOffset =
              object.value == null ? null : fbb.writeString(object.value!);
          fbb.startTable(4);
          fbb.addInt64(0, object.id);
          fbb.addOffset(1, keyOffset);
          fbb.addOffset(2, valueOffset);
          fbb.finish(fbb.endTable());
          return object.id;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = DocEntity(
              id: const fb.Int64Reader().vTableGet(buffer, rootOffset, 4, 0),
              key: const fb.StringReader().vTableGet(buffer, rootOffset, 6, ''),
              value: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8));

          return object;
        }),
    LocalDocEntity: EntityDefinition<LocalDocEntity>(
        model: _entities[1],
        toOneRelations: (LocalDocEntity object) => [],
        toManyRelations: (LocalDocEntity object) => {},
        getId: (LocalDocEntity object) => object.id,
        setId: (LocalDocEntity object, int id) {
          object.id = id;
        },
        objectToFB: (LocalDocEntity object, fb.Builder fbb) {
          final keyOffset = fbb.writeString(object.key);
          final valueOffset =
              object.value == null ? null : fbb.writeString(object.value!);
          fbb.startTable(4);
          fbb.addInt64(0, object.id);
          fbb.addOffset(1, keyOffset);
          fbb.addOffset(2, valueOffset);
          fbb.finish(fbb.endTable());
          return object.id;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = LocalDocEntity(
              id: const fb.Int64Reader().vTableGet(buffer, rootOffset, 4, 0),
              key: const fb.StringReader().vTableGet(buffer, rootOffset, 6, ''),
              value: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8));

          return object;
        }),
    SequenceEntity: EntityDefinition<SequenceEntity>(
        model: _entities[2],
        toOneRelations: (SequenceEntity object) => [],
        toManyRelations: (SequenceEntity object) => {},
        getId: (SequenceEntity object) => object.id,
        setId: (SequenceEntity object, int id) {
          object.id = id;
        },
        objectToFB: (SequenceEntity object, fb.Builder fbb) {
          final valueOffset =
              object.value == null ? null : fbb.writeString(object.value!);
          fbb.startTable(4);
          fbb.addInt64(0, object.id);
          fbb.addInt64(1, object.key);
          fbb.addOffset(2, valueOffset);
          fbb.finish(fbb.endTable());
          return object.id;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = SequenceEntity(
              id: const fb.Int64Reader().vTableGet(buffer, rootOffset, 4, 0),
              key: const fb.Int64Reader().vTableGet(buffer, rootOffset, 6, 0),
              value: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8));

          return object;
        }),
    ViewDocMetaEntity: EntityDefinition<ViewDocMetaEntity>(
        model: _entities[3],
        toOneRelations: (ViewDocMetaEntity object) => [],
        toManyRelations: (ViewDocMetaEntity object) => {},
        getId: (ViewDocMetaEntity object) => object.id,
        setId: (ViewDocMetaEntity object, int id) {
          object.id = id;
        },
        objectToFB: (ViewDocMetaEntity object, fb.Builder fbb) {
          final keyOffset = fbb.writeString(object.key);
          final valueOffset =
              object.value == null ? null : fbb.writeString(object.value!);
          fbb.startTable(4);
          fbb.addInt64(0, object.id);
          fbb.addOffset(1, keyOffset);
          fbb.addOffset(2, valueOffset);
          fbb.finish(fbb.endTable());
          return object.id;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = ViewDocMetaEntity(
              id: const fb.Int64Reader().vTableGet(buffer, rootOffset, 4, 0),
              key: const fb.StringReader().vTableGet(buffer, rootOffset, 6, ''),
              value: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8));

          return object;
        }),
    ViewKeyMetaEntity: EntityDefinition<ViewKeyMetaEntity>(
        model: _entities[4],
        toOneRelations: (ViewKeyMetaEntity object) => [],
        toManyRelations: (ViewKeyMetaEntity object) => {},
        getId: (ViewKeyMetaEntity object) => object.id,
        setId: (ViewKeyMetaEntity object, int id) {
          object.id = id;
        },
        objectToFB: (ViewKeyMetaEntity object, fb.Builder fbb) {
          final keyOffset = fbb.writeString(object.key);
          final valueOffset =
              object.value == null ? null : fbb.writeString(object.value!);
          fbb.startTable(4);
          fbb.addInt64(0, object.id);
          fbb.addOffset(1, keyOffset);
          fbb.addOffset(2, valueOffset);
          fbb.finish(fbb.endTable());
          return object.id;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = ViewKeyMetaEntity(
              id: const fb.Int64Reader().vTableGet(buffer, rootOffset, 4, 0),
              key: const fb.StringReader().vTableGet(buffer, rootOffset, 6, ''),
              value: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8));

          return object;
        }),
    ViewMetaEntity: EntityDefinition<ViewMetaEntity>(
        model: _entities[5],
        toOneRelations: (ViewMetaEntity object) => [],
        toManyRelations: (ViewMetaEntity object) => {},
        getId: (ViewMetaEntity object) => object.id,
        setId: (ViewMetaEntity object, int id) {
          object.id = id;
        },
        objectToFB: (ViewMetaEntity object, fb.Builder fbb) {
          final keyOffset = fbb.writeString(object.key);
          final valueOffset =
              object.value == null ? null : fbb.writeString(object.value!);
          fbb.startTable(4);
          fbb.addInt64(0, object.id);
          fbb.addOffset(1, keyOffset);
          fbb.addOffset(2, valueOffset);
          fbb.finish(fbb.endTable());
          return object.id;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = ViewMetaEntity(
              id: const fb.Int64Reader().vTableGet(buffer, rootOffset, 4, 0),
              key: const fb.StringReader().vTableGet(buffer, rootOffset, 6, ''),
              value: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8));

          return object;
        })
  };

  return ModelDefinition(model, bindings);
}

/// [DocEntity] entity fields to define ObjectBox queries.
class DocEntity_ {
  /// see [DocEntity.id]
  static final id = QueryIntegerProperty<DocEntity>(_entities[0].properties[0]);

  /// see [DocEntity.key]
  static final key = QueryStringProperty<DocEntity>(_entities[0].properties[1]);

  /// see [DocEntity.value]
  static final value =
      QueryStringProperty<DocEntity>(_entities[0].properties[2]);
}

/// [LocalDocEntity] entity fields to define ObjectBox queries.
class LocalDocEntity_ {
  /// see [LocalDocEntity.id]
  static final id =
      QueryIntegerProperty<LocalDocEntity>(_entities[1].properties[0]);

  /// see [LocalDocEntity.key]
  static final key =
      QueryStringProperty<LocalDocEntity>(_entities[1].properties[1]);

  /// see [LocalDocEntity.value]
  static final value =
      QueryStringProperty<LocalDocEntity>(_entities[1].properties[2]);
}

/// [SequenceEntity] entity fields to define ObjectBox queries.
class SequenceEntity_ {
  /// see [SequenceEntity.id]
  static final id =
      QueryIntegerProperty<SequenceEntity>(_entities[2].properties[0]);

  /// see [SequenceEntity.key]
  static final key =
      QueryIntegerProperty<SequenceEntity>(_entities[2].properties[1]);

  /// see [SequenceEntity.value]
  static final value =
      QueryStringProperty<SequenceEntity>(_entities[2].properties[2]);
}

/// [ViewDocMetaEntity] entity fields to define ObjectBox queries.
class ViewDocMetaEntity_ {
  /// see [ViewDocMetaEntity.id]
  static final id =
      QueryIntegerProperty<ViewDocMetaEntity>(_entities[3].properties[0]);

  /// see [ViewDocMetaEntity.key]
  static final key =
      QueryStringProperty<ViewDocMetaEntity>(_entities[3].properties[1]);

  /// see [ViewDocMetaEntity.value]
  static final value =
      QueryStringProperty<ViewDocMetaEntity>(_entities[3].properties[2]);
}

/// [ViewKeyMetaEntity] entity fields to define ObjectBox queries.
class ViewKeyMetaEntity_ {
  /// see [ViewKeyMetaEntity.id]
  static final id =
      QueryIntegerProperty<ViewKeyMetaEntity>(_entities[4].properties[0]);

  /// see [ViewKeyMetaEntity.key]
  static final key =
      QueryStringProperty<ViewKeyMetaEntity>(_entities[4].properties[1]);

  /// see [ViewKeyMetaEntity.value]
  static final value =
      QueryStringProperty<ViewKeyMetaEntity>(_entities[4].properties[2]);
}

/// [ViewMetaEntity] entity fields to define ObjectBox queries.
class ViewMetaEntity_ {
  /// see [ViewMetaEntity.id]
  static final id =
      QueryIntegerProperty<ViewMetaEntity>(_entities[5].properties[0]);

  /// see [ViewMetaEntity.key]
  static final key =
      QueryStringProperty<ViewMetaEntity>(_entities[5].properties[1]);

  /// see [ViewMetaEntity.value]
  static final value =
      QueryStringProperty<ViewMetaEntity>(_entities[5].properties[2]);
}
