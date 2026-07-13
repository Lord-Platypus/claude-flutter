import 'package:mason/mason.dart';

void run(HookContext context) {
  final fields = context.vars['fields'] as List<dynamic>;

  final formattedFields = fields
      .map((field) {
        final name = (field['name'] as String).camelCase;
        final type = field['type'] as String;
        final kind = field['kind'] as String?; // only 'enum' is explicit
        final nullable = type.endsWith('?');
        final base = nullable ? type.substring(0, type.length - 1) : type;

        final isEnum = kind == 'enum';
        final isMoney = kind == 'money';
        final isQuantity = kind == 'quantity';
        final isDateTime = base == 'DateTime';
        final isBool = base == 'bool';

        // model_type: the storage type on the Floor model.
        // enum/DateTime persist as TEXT, bool as INTEGER, Money/Quantity as
        // INTEGER (cents / count); others unchanged.
        String modelType;
        // to_model: entity field -> model field expression (subject `e`).
        String toModel;
        // to_entity: model field -> entity field expression (bare field name).
        String toEntity;

        if (isEnum) {
          modelType = nullable ? 'String?' : 'String';
          toModel = nullable ? 'e.$name?.name' : 'e.$name.name';
          toEntity = nullable
              ? '$name == null ? null : $base.values.byName($name!)'
              : '$base.values.byName($name)';
        } else if (isDateTime) {
          modelType = nullable ? 'String?' : 'String';
          toModel =
              nullable ? 'e.$name?.toIso8601String()' : 'e.$name.toIso8601String()';
          toEntity = nullable
              ? '$name == null ? null : DateTime.parse($name!)'
              : 'DateTime.parse($name)';
        } else if (isBool) {
          modelType = nullable ? 'int?' : 'int';
          toModel = nullable ? 'e.$name == null ? null : (e.$name! ? 1 : 0)' : 'e.$name ? 1 : 0';
          toEntity = nullable ? '$name == null ? null : $name == 1' : '$name == 1';
        } else if (isMoney) {
          // Money is cents-backed; persist the raw int cents.
          modelType = nullable ? 'int?' : 'int';
          toModel = nullable ? 'e.$name?.cents' : 'e.$name.cents';
          toEntity = nullable
              ? '$name == null ? null : Money.fromCents($name!)'
              : 'Money.fromCents($name)';
        } else if (isQuantity) {
          // Quantity is count-backed; persist the raw int value.
          modelType = nullable ? 'int?' : 'int';
          toModel = nullable ? 'e.$name?.value' : 'e.$name.value';
          toEntity = nullable
              ? '$name == null ? null : Quantity($name!)'
              : 'Quantity($name)';
        } else {
          modelType = type;
          toModel = 'e.$name';
          toEntity = name;
        }

        return {
          'name': name,
          'type': type,
          // For copyWith parameters: nullable types (String?) must not get an extra '?'
          // e.g. String -> String?, String? -> String?
          'copy_with_type': nullable ? type : '$type?',
          'model_type': modelType,
          'to_model': toModel,
          'to_entity': toEntity,
          'is_enum': isEnum,
          'enum_base': isEnum ? base : null,
          // VO class name ('Money'/'Quantity') when this field is a value
          // object, else null. Drives the colocated VO import collection below.
          'vo_base': isMoney
              ? 'Money'
              : isQuantity
                  ? 'Quantity'
                  : null,
        };
      })
      .where((f) => f['name'] != 'id') // id is hardcoded as @primaryKey
      .toList();

  // Unique enum imports. Enum files are colocated, hand-authored in domain/entities/ —
  // the brick imports them, it does not generate them.
  final seen = <String>{};
  final enums = <Map<String, String>>[];
  for (final f in formattedFields) {
    if (f['is_enum'] != true) continue;
    final base = f['enum_base'] as String;
    if (!seen.add(base)) continue;
    final snake = base.snakeCase;
    enums.add({
      'enum_entity_import': '$snake.dart',
      'enum_model_import': '../../domain/entities/$snake.dart',
    });
  }

  // Unique value-object imports. Money/Quantity live in core/value_objects/ —
  // entity and model files sit at the same depth, so the relative path is
  // identical for both. The brick imports them; it does not generate them.
  final voSeen = <String>{};
  final valueObjects = <Map<String, String>>[];
  for (final f in formattedFields) {
    final voBase = f['vo_base'] as String?;
    if (voBase == null) continue;
    if (!voSeen.add(voBase)) continue;
    valueObjects.add({
      'vo_import': '../../../../core/value_objects/${voBase.snakeCase}.dart',
    });
  }

  final invariants = (context.vars['invariants'] as List<dynamic>?) ?? const [];

  context.vars['fields'] = formattedFields;
  context.vars['enums'] = enums;
  context.vars['value_objects'] = valueObjects;
  context.vars['has_invariants'] = invariants.isNotEmpty;
  context.vars['invariants'] = invariants;
}
