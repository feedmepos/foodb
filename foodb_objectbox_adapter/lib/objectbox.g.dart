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
      id: const IdUid(1, 3021689570106315131),
      name: 'AllDocViewDocMetaEntity',
      lastPropertyId: const IdUid(3, 5835498232873122842),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 8540705624692014378),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 6009736315792442070),
            name: 'key',
            type: 9,
            flags: 8,
            indexId: const IdUid(1, 2825065807747879183)),
        ModelProperty(
            id: const IdUid(3, 5835498232873122842),
            name: 'value',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(2, 1918954271703562383),
      name: 'AllDocViewKeyMetaEntity',
      lastPropertyId: const IdUid(3, 8357916780370056873),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 8238863236660611782),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 8733103804834214230),
            name: 'key',
            type: 9,
            flags: 8,
            indexId: const IdUid(2, 1811533003850621028)),
        ModelProperty(
            id: const IdUid(3, 8357916780370056873),
            name: 'value',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(3, 1973590831734400514),
      name: 'DocEntity',
      lastPropertyId: const IdUid(3, 6339596475273150250),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 4473326181232707341),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 7769416710097771877),
            name: 'key',
            type: 9,
            flags: 8,
            indexId: const IdUid(3, 6316172100194881292)),
        ModelProperty(
            id: const IdUid(3, 6339596475273150250),
            name: 'value',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(4, 3804723916077735283),
      name: 'LocalDocEntity',
      lastPropertyId: const IdUid(3, 8875595387812754771),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 5998574570340171509),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 355961173367513538),
            name: 'key',
            type: 9,
            flags: 8,
            indexId: const IdUid(4, 8069809380969902740)),
        ModelProperty(
            id: const IdUid(3, 8875595387812754771),
            name: 'value',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(5, 1816147773067204699),
      name: 'SequenceEntity',
      lastPropertyId: const IdUid(3, 1233092651565240139),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 8821304901228835362),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 3938403028721403539),
            name: 'key',
            type: 6,
            flags: 8,
            indexId: const IdUid(5, 4041288449147310125)),
        ModelProperty(
            id: const IdUid(3, 1233092651565240139),
            name: 'value',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(6, 3148046912633900126),
      name: 'ViewDocMetaEntity',
      lastPropertyId: const IdUid(3, 3518627672935492769),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 1043593640599501789),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 9221473796516660758),
            name: 'key',
            type: 9,
            flags: 8,
            indexId: const IdUid(6, 7585772069821342328)),
        ModelProperty(
            id: const IdUid(3, 3518627672935492769),
            name: 'value',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(7, 5065999665789497311),
      name: 'ViewKeyMetaEntity',
      lastPropertyId: const IdUid(3, 8587698246806716331),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 8600873610745864091),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 1142135877991697735),
            name: 'key',
            type: 9,
            flags: 8,
            indexId: const IdUid(7, 4735860562603714514)),
        ModelProperty(
            id: const IdUid(3, 8587698246806716331),
            name: 'value',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(8, 7863331895491057739),
      name: 'ViewMetaEntity',
      lastPropertyId: const IdUid(3, 6354903701505548316),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 4951339630311620382),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 7100843868053499823),
            name: 'key',
            type: 9,
            flags: 8,
            indexId: const IdUid(8, 6063552904137448282)),
        ModelProperty(
            id: const IdUid(3, 6354903701505548316),
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
      lastEntityId: const IdUid(8, 7863331895491057739),
      lastIndexId: const IdUid(8, 6063552904137448282),
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
    AllDocViewDocMetaEntity: EntityDefinition<AllDocViewDocMetaEntity>(
        model: _entities[0],
        toOneRelations: (AllDocViewDocMetaEntity object) => [],
        toManyRelations: (AllDocViewDocMetaEntity object) => {},
        getId: (AllDocViewDocMetaEntity object) => object.id,
        setId: (AllDocViewDocMetaEntity object, int id) {
          object.id = id;
        },
        objectToFB: (AllDocViewDocMetaEntity object, fb.Builder fbb) {
          final keyOffset = fbb.writeString(object.key);
          final valueOffset = fbb.writeString(object.value);
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

          final object = AllDocViewDocMetaEntity(
              id: const fb.Int64Reader().vTableGet(buffer, rootOffset, 4, 0),
              key: const fb.StringReader().vTableGet(buffer, rootOffset, 6, ''),
              value:
                  const fb.StringReader().vTableGet(buffer, rootOffset, 8, ''));

          return object;
        }),
    AllDocViewKeyMetaEntity: EntityDefinition<AllDocViewKeyMetaEntity>(
        model: _entities[1],
        toOneRelations: (AllDocViewKeyMetaEntity object) => [],
        toManyRelations: (AllDocViewKeyMetaEntity object) => {},
        getId: (AllDocViewKeyMetaEntity object) => object.id,
        setId: (AllDocViewKeyMetaEntity object, int id) {
          object.id = id;
        },
        objectToFB: (AllDocViewKeyMetaEntity object, fb.Builder fbb) {
          final keyOffset = fbb.writeString(object.key);
          final valueOffset = fbb.writeString(object.value);
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

          final object = AllDocViewKeyMetaEntity(
              id: const fb.Int64Reader().vTableGet(buffer, rootOffset, 4, 0),
              key: const fb.StringReader().vTableGet(buffer, rootOffset, 6, ''),
              value:
                  const fb.StringReader().vTableGet(buffer, rootOffset, 8, ''));

          return object;
        }),
    DocEntity: EntityDefinition<DocEntity>(
        model: _entities[2],
        toOneRelations: (DocEntity object) => [],
        toManyRelations: (DocEntity object) => {},
        getId: (DocEntity object) => object.id,
        setId: (DocEntity object, int id) {
          object.id = id;
        },
        objectToFB: (DocEntity object, fb.Builder fbb) {
          final keyOffset = fbb.writeString(object.key);
          final valueOffset = fbb.writeString(object.value);
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
              value:
                  const fb.StringReader().vTableGet(buffer, rootOffset, 8, ''));

          return object;
        }),
    LocalDocEntity: EntityDefinition<LocalDocEntity>(
        model: _entities[3],
        toOneRelations: (LocalDocEntity object) => [],
        toManyRelations: (LocalDocEntity object) => {},
        getId: (LocalDocEntity object) => object.id,
        setId: (LocalDocEntity object, int id) {
          object.id = id;
        },
        objectToFB: (LocalDocEntity object, fb.Builder fbb) {
          final keyOffset = fbb.writeString(object.key);
          final valueOffset = fbb.writeString(object.value);
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
              value:
                  const fb.StringReader().vTableGet(buffer, rootOffset, 8, ''));

          return object;
        }),
    SequenceEntity: EntityDefinition<SequenceEntity>(
        model: _entities[4],
        toOneRelations: (SequenceEntity object) => [],
        toManyRelations: (SequenceEntity object) => {},
        getId: (SequenceEntity object) => object.id,
        setId: (SequenceEntity object, int id) {
          object.id = id;
        },
        objectToFB: (SequenceEntity object, fb.Builder fbb) {
          final valueOffset = fbb.writeString(object.value);
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
              value:
                  const fb.StringReader().vTableGet(buffer, rootOffset, 8, ''));

          return object;
        }),
    ViewDocMetaEntity: EntityDefinition<ViewDocMetaEntity>(
        model: _entities[5],
        toOneRelations: (ViewDocMetaEntity object) => [],
        toManyRelations: (ViewDocMetaEntity object) => {},
        getId: (ViewDocMetaEntity object) => object.id,
        setId: (ViewDocMetaEntity object, int id) {
          object.id = id;
        },
        objectToFB: (ViewDocMetaEntity object, fb.Builder fbb) {
          final keyOffset = fbb.writeString(object.key);
          final valueOffset = fbb.writeString(object.value);
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
              value:
                  const fb.StringReader().vTableGet(buffer, rootOffset, 8, ''));

          return object;
        }),
    ViewKeyMetaEntity: EntityDefinition<ViewKeyMetaEntity>(
        model: _entities[6],
        toOneRelations: (ViewKeyMetaEntity object) => [],
        toManyRelations: (ViewKeyMetaEntity object) => {},
        getId: (ViewKeyMetaEntity object) => object.id,
        setId: (ViewKeyMetaEntity object, int id) {
          object.id = id;
        },
        objectToFB: (ViewKeyMetaEntity object, fb.Builder fbb) {
          final keyOffset = fbb.writeString(object.key);
          final valueOffset = fbb.writeString(object.value);
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
              value:
                  const fb.StringReader().vTableGet(buffer, rootOffset, 8, ''));

          return object;
        }),
    ViewMetaEntity: EntityDefinition<ViewMetaEntity>(
        model: _entities[7],
        toOneRelations: (ViewMetaEntity object) => [],
        toManyRelations: (ViewMetaEntity object) => {},
        getId: (ViewMetaEntity object) => object.id,
        setId: (ViewMetaEntity object, int id) {
          object.id = id;
        },
        objectToFB: (ViewMetaEntity object, fb.Builder fbb) {
          final keyOffset = fbb.writeString(object.key);
          final valueOffset = fbb.writeString(object.value);
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
              value:
                  const fb.StringReader().vTableGet(buffer, rootOffset, 8, ''));

          return object;
        })
  };

  return ModelDefinition(model, bindings);
}

/// [AllDocViewDocMetaEntity] entity fields to define ObjectBox queries.
class AllDocViewDocMetaEntity_ {
  /// see [AllDocViewDocMetaEntity.id]
  static final id =
      QueryIntegerProperty<AllDocViewDocMetaEntity>(_entities[0].properties[0]);

  /// see [AllDocViewDocMetaEntity.key]
  static final key =
      QueryStringProperty<AllDocViewDocMetaEntity>(_entities[0].properties[1]);

  /// see [AllDocViewDocMetaEntity.value]
  static final value =
      QueryStringProperty<AllDocViewDocMetaEntity>(_entities[0].properties[2]);
}

/// [AllDocViewKeyMetaEntity] entity fields to define ObjectBox queries.
class AllDocViewKeyMetaEntity_ {
  /// see [AllDocViewKeyMetaEntity.id]
  static final id =
      QueryIntegerProperty<AllDocViewKeyMetaEntity>(_entities[1].properties[0]);

  /// see [AllDocViewKeyMetaEntity.key]
  static final key =
      QueryStringProperty<AllDocViewKeyMetaEntity>(_entities[1].properties[1]);

  /// see [AllDocViewKeyMetaEntity.value]
  static final value =
      QueryStringProperty<AllDocViewKeyMetaEntity>(_entities[1].properties[2]);
}

/// [DocEntity] entity fields to define ObjectBox queries.
class DocEntity_ {
  /// see [DocEntity.id]
  static final id = QueryIntegerProperty<DocEntity>(_entities[2].properties[0]);

  /// see [DocEntity.key]
  static final key = QueryStringProperty<DocEntity>(_entities[2].properties[1]);

  /// see [DocEntity.value]
  static final value =
      QueryStringProperty<DocEntity>(_entities[2].properties[2]);
}

/// [LocalDocEntity] entity fields to define ObjectBox queries.
class LocalDocEntity_ {
  /// see [LocalDocEntity.id]
  static final id =
      QueryIntegerProperty<LocalDocEntity>(_entities[3].properties[0]);

  /// see [LocalDocEntity.key]
  static final key =
      QueryStringProperty<LocalDocEntity>(_entities[3].properties[1]);

  /// see [LocalDocEntity.value]
  static final value =
      QueryStringProperty<LocalDocEntity>(_entities[3].properties[2]);
}

/// [SequenceEntity] entity fields to define ObjectBox queries.
class SequenceEntity_ {
  /// see [SequenceEntity.id]
  static final id =
      QueryIntegerProperty<SequenceEntity>(_entities[4].properties[0]);

  /// see [SequenceEntity.key]
  static final key =
      QueryIntegerProperty<SequenceEntity>(_entities[4].properties[1]);

  /// see [SequenceEntity.value]
  static final value =
      QueryStringProperty<SequenceEntity>(_entities[4].properties[2]);
}

/// [ViewDocMetaEntity] entity fields to define ObjectBox queries.
class ViewDocMetaEntity_ {
  /// see [ViewDocMetaEntity.id]
  static final id =
      QueryIntegerProperty<ViewDocMetaEntity>(_entities[5].properties[0]);

  /// see [ViewDocMetaEntity.key]
  static final key =
      QueryStringProperty<ViewDocMetaEntity>(_entities[5].properties[1]);

  /// see [ViewDocMetaEntity.value]
  static final value =
      QueryStringProperty<ViewDocMetaEntity>(_entities[5].properties[2]);
}

/// [ViewKeyMetaEntity] entity fields to define ObjectBox queries.
class ViewKeyMetaEntity_ {
  /// see [ViewKeyMetaEntity.id]
  static final id =
      QueryIntegerProperty<ViewKeyMetaEntity>(_entities[6].properties[0]);

  /// see [ViewKeyMetaEntity.key]
  static final key =
      QueryStringProperty<ViewKeyMetaEntity>(_entities[6].properties[1]);

  /// see [ViewKeyMetaEntity.value]
  static final value =
      QueryStringProperty<ViewKeyMetaEntity>(_entities[6].properties[2]);
}

/// [ViewMetaEntity] entity fields to define ObjectBox queries.
class ViewMetaEntity_ {
  /// see [ViewMetaEntity.id]
  static final id =
      QueryIntegerProperty<ViewMetaEntity>(_entities[7].properties[0]);

  /// see [ViewMetaEntity.key]
  static final key =
      QueryStringProperty<ViewMetaEntity>(_entities[7].properties[1]);

  /// see [ViewMetaEntity.value]
  static final value =
      QueryStringProperty<ViewMetaEntity>(_entities[7].properties[2]);
}
