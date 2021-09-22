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
      id: const IdUid(1, 6622174301463535485),
      name: 'DocObject',
      lastPropertyId: const IdUid(4, 1163700573801916292),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 1781864446410536219),
            name: 'id',
            type: 6,
            flags: 129),
        ModelProperty(
            id: const IdUid(3, 4226611598113381983),
            name: 'value',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(4, 1163700573801916292),
            name: 'key',
            type: 9,
            flags: 2048,
            indexId: const IdUid(8, 6635848602395745881))
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(2, 8429717446124032204),
      name: 'LocalDocObject',
      lastPropertyId: const IdUid(4, 2662669015074907462),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 3935624190090915669),
            name: 'id',
            type: 6,
            flags: 129),
        ModelProperty(
            id: const IdUid(3, 684882806072693233),
            name: 'value',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(4, 2662669015074907462),
            name: 'key',
            type: 9,
            flags: 2048,
            indexId: const IdUid(9, 279971503199994650))
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(3, 7563831767817202335),
      name: 'SequenceObject',
      lastPropertyId: const IdUid(4, 7660747485539849916),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 5953570059821218213),
            name: 'id',
            type: 6,
            flags: 129),
        ModelProperty(
            id: const IdUid(3, 8689971109704308935),
            name: 'value',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(4, 7660747485539849916),
            name: 'key',
            type: 9,
            flags: 2048,
            indexId: const IdUid(10, 3826840651276068019))
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(4, 746405745216575659),
      name: 'ViewIdObject',
      lastPropertyId: const IdUid(4, 2663949986019418151),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 2851309909731352415),
            name: 'id',
            type: 6,
            flags: 129),
        ModelProperty(
            id: const IdUid(3, 5487010102948749176),
            name: 'value',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(4, 2663949986019418151),
            name: 'key',
            type: 9,
            flags: 2048,
            indexId: const IdUid(11, 1100169669688902450))
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(5, 4276919897303836959),
      name: 'ViewKeyObject',
      lastPropertyId: const IdUid(4, 8683450472321783788),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 5455334887915348687),
            name: 'id',
            type: 6,
            flags: 129),
        ModelProperty(
            id: const IdUid(3, 2769170428104305903),
            name: 'value',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(4, 8683450472321783788),
            name: 'key',
            type: 9,
            flags: 2048,
            indexId: const IdUid(12, 2944651458473695848))
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(6, 6738579724716991720),
      name: 'ViewMetaObject',
      lastPropertyId: const IdUid(4, 5232102712710831581),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 2903015649845273127),
            name: 'id',
            type: 6,
            flags: 129),
        ModelProperty(
            id: const IdUid(3, 2511425265660318828),
            name: 'value',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(4, 5232102712710831581),
            name: 'key',
            type: 9,
            flags: 2048,
            indexId: const IdUid(13, 6556323116993261429))
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
      lastEntityId: const IdUid(9, 8885801200855639251),
      lastIndexId: const IdUid(14, 6675191802812265413),
      lastRelationId: const IdUid(0, 0),
      lastSequenceId: const IdUid(0, 0),
      retiredEntityUids: const [
        8842027470902956381,
        2504612080459907327,
        8885801200855639251
      ],
      retiredIndexUids: const [
        2217445087064918579,
        7700873384517221477,
        7939697965383828459,
        1281371319672271839,
        6019366859744502701,
        3354992963094360112
      ],
      retiredPropertyUids: const [
        4279795125970217286,
        7179168706175075876,
        938973070722999951,
        8613433438281843076,
        4228196814866234055,
        4450188941046813122,
        749149001067822069,
        4990794649388996325,
        3885460492299160645,
        8336902243284899585,
        8900985955392074497,
        5167927408010917924,
        2281881436387328474
      ],
      retiredRelationUids: const [],
      modelVersion: 5,
      modelVersionParserMinimum: 5,
      version: 1);

  final bindings = <Type, EntityDefinition>{
    DocObject: EntityDefinition<DocObject>(
        model: _entities[0],
        toOneRelations: (DocObject object) => [],
        toManyRelations: (DocObject object) => {},
        getId: (DocObject object) => object.id,
        setId: (DocObject object, int id) {
          object.id = id;
        },
        objectToFB: (DocObject object, fb.Builder fbb) {
          final valueOffset =
              object.value == null ? null : fbb.writeString(object.value!);
          final keyOffset =
              object.key == null ? null : fbb.writeString(object.key!);
          fbb.startTable(5);
          fbb.addInt64(0, object.id);
          fbb.addOffset(2, valueOffset);
          fbb.addOffset(3, keyOffset);
          fbb.finish(fbb.endTable());
          return object.id;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = DocObject(
              id: const fb.Int64Reader().vTableGet(buffer, rootOffset, 4, 0),
              key: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 10),
              value: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8));

          return object;
        }),
    LocalDocObject: EntityDefinition<LocalDocObject>(
        model: _entities[1],
        toOneRelations: (LocalDocObject object) => [],
        toManyRelations: (LocalDocObject object) => {},
        getId: (LocalDocObject object) => object.id,
        setId: (LocalDocObject object, int id) {
          object.id = id;
        },
        objectToFB: (LocalDocObject object, fb.Builder fbb) {
          final valueOffset =
              object.value == null ? null : fbb.writeString(object.value!);
          final keyOffset =
              object.key == null ? null : fbb.writeString(object.key!);
          fbb.startTable(5);
          fbb.addInt64(0, object.id);
          fbb.addOffset(2, valueOffset);
          fbb.addOffset(3, keyOffset);
          fbb.finish(fbb.endTable());
          return object.id;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = LocalDocObject(
              id: const fb.Int64Reader().vTableGet(buffer, rootOffset, 4, 0),
              key: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 10),
              value: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8));

          return object;
        }),
    SequenceObject: EntityDefinition<SequenceObject>(
        model: _entities[2],
        toOneRelations: (SequenceObject object) => [],
        toManyRelations: (SequenceObject object) => {},
        getId: (SequenceObject object) => object.id,
        setId: (SequenceObject object, int id) {
          object.id = id;
        },
        objectToFB: (SequenceObject object, fb.Builder fbb) {
          final valueOffset =
              object.value == null ? null : fbb.writeString(object.value!);
          final keyOffset =
              object.key == null ? null : fbb.writeString(object.key!);
          fbb.startTable(5);
          fbb.addInt64(0, object.id);
          fbb.addOffset(2, valueOffset);
          fbb.addOffset(3, keyOffset);
          fbb.finish(fbb.endTable());
          return object.id;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = SequenceObject(
              id: const fb.Int64Reader().vTableGet(buffer, rootOffset, 4, 0),
              key: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 10),
              value: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8));

          return object;
        }),
    ViewIdObject: EntityDefinition<ViewIdObject>(
        model: _entities[3],
        toOneRelations: (ViewIdObject object) => [],
        toManyRelations: (ViewIdObject object) => {},
        getId: (ViewIdObject object) => object.id,
        setId: (ViewIdObject object, int id) {
          object.id = id;
        },
        objectToFB: (ViewIdObject object, fb.Builder fbb) {
          final valueOffset =
              object.value == null ? null : fbb.writeString(object.value!);
          final keyOffset =
              object.key == null ? null : fbb.writeString(object.key!);
          fbb.startTable(5);
          fbb.addInt64(0, object.id);
          fbb.addOffset(2, valueOffset);
          fbb.addOffset(3, keyOffset);
          fbb.finish(fbb.endTable());
          return object.id;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = ViewIdObject(
              id: const fb.Int64Reader().vTableGet(buffer, rootOffset, 4, 0),
              key: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 10),
              value: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8));

          return object;
        }),
    ViewKeyObject: EntityDefinition<ViewKeyObject>(
        model: _entities[4],
        toOneRelations: (ViewKeyObject object) => [],
        toManyRelations: (ViewKeyObject object) => {},
        getId: (ViewKeyObject object) => object.id,
        setId: (ViewKeyObject object, int id) {
          object.id = id;
        },
        objectToFB: (ViewKeyObject object, fb.Builder fbb) {
          final valueOffset =
              object.value == null ? null : fbb.writeString(object.value!);
          final keyOffset =
              object.key == null ? null : fbb.writeString(object.key!);
          fbb.startTable(5);
          fbb.addInt64(0, object.id);
          fbb.addOffset(2, valueOffset);
          fbb.addOffset(3, keyOffset);
          fbb.finish(fbb.endTable());
          return object.id;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = ViewKeyObject(
              id: const fb.Int64Reader().vTableGet(buffer, rootOffset, 4, 0),
              key: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 10),
              value: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8));

          return object;
        }),
    ViewMetaObject: EntityDefinition<ViewMetaObject>(
        model: _entities[5],
        toOneRelations: (ViewMetaObject object) => [],
        toManyRelations: (ViewMetaObject object) => {},
        getId: (ViewMetaObject object) => object.id,
        setId: (ViewMetaObject object, int id) {
          object.id = id;
        },
        objectToFB: (ViewMetaObject object, fb.Builder fbb) {
          final valueOffset =
              object.value == null ? null : fbb.writeString(object.value!);
          final keyOffset =
              object.key == null ? null : fbb.writeString(object.key!);
          fbb.startTable(5);
          fbb.addInt64(0, object.id);
          fbb.addOffset(2, valueOffset);
          fbb.addOffset(3, keyOffset);
          fbb.finish(fbb.endTable());
          return object.id;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = ViewMetaObject(
              id: const fb.Int64Reader().vTableGet(buffer, rootOffset, 4, 0),
              key: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 10),
              value: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8));

          return object;
        })
  };

  return ModelDefinition(model, bindings);
}

/// [DocObject] entity fields to define ObjectBox queries.
class DocObject_ {
  /// see [DocObject.id]
  static final id = QueryIntegerProperty<DocObject>(_entities[0].properties[0]);

  /// see [DocObject.value]
  static final value =
      QueryStringProperty<DocObject>(_entities[0].properties[1]);

  /// see [DocObject.key]
  static final key = QueryStringProperty<DocObject>(_entities[0].properties[2]);
}

/// [LocalDocObject] entity fields to define ObjectBox queries.
class LocalDocObject_ {
  /// see [LocalDocObject.id]
  static final id =
      QueryIntegerProperty<LocalDocObject>(_entities[1].properties[0]);

  /// see [LocalDocObject.value]
  static final value =
      QueryStringProperty<LocalDocObject>(_entities[1].properties[1]);

  /// see [LocalDocObject.key]
  static final key =
      QueryStringProperty<LocalDocObject>(_entities[1].properties[2]);
}

/// [SequenceObject] entity fields to define ObjectBox queries.
class SequenceObject_ {
  /// see [SequenceObject.id]
  static final id =
      QueryIntegerProperty<SequenceObject>(_entities[2].properties[0]);

  /// see [SequenceObject.value]
  static final value =
      QueryStringProperty<SequenceObject>(_entities[2].properties[1]);

  /// see [SequenceObject.key]
  static final key =
      QueryStringProperty<SequenceObject>(_entities[2].properties[2]);
}

/// [ViewIdObject] entity fields to define ObjectBox queries.
class ViewIdObject_ {
  /// see [ViewIdObject.id]
  static final id =
      QueryIntegerProperty<ViewIdObject>(_entities[3].properties[0]);

  /// see [ViewIdObject.value]
  static final value =
      QueryStringProperty<ViewIdObject>(_entities[3].properties[1]);

  /// see [ViewIdObject.key]
  static final key =
      QueryStringProperty<ViewIdObject>(_entities[3].properties[2]);
}

/// [ViewKeyObject] entity fields to define ObjectBox queries.
class ViewKeyObject_ {
  /// see [ViewKeyObject.id]
  static final id =
      QueryIntegerProperty<ViewKeyObject>(_entities[4].properties[0]);

  /// see [ViewKeyObject.value]
  static final value =
      QueryStringProperty<ViewKeyObject>(_entities[4].properties[1]);

  /// see [ViewKeyObject.key]
  static final key =
      QueryStringProperty<ViewKeyObject>(_entities[4].properties[2]);
}

/// [ViewMetaObject] entity fields to define ObjectBox queries.
class ViewMetaObject_ {
  /// see [ViewMetaObject.id]
  static final id =
      QueryIntegerProperty<ViewMetaObject>(_entities[5].properties[0]);

  /// see [ViewMetaObject.value]
  static final value =
      QueryStringProperty<ViewMetaObject>(_entities[5].properties[1]);

  /// see [ViewMetaObject.key]
  static final key =
      QueryStringProperty<ViewMetaObject>(_entities[5].properties[2]);
}
