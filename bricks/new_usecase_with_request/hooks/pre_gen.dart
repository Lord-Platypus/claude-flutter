import 'package:mason/mason.dart';

void run(HookContext context) {
  final fields = context.vars['request_fields'] as List<dynamic>? ?? [];

  final formattedFields = fields.map((field) {
    return {
      'name': (field['name'] as String).camelCase,
      'type': field['type'] as String,
    };
  }).toList();

  context.vars['request_fields'] = formattedFields;

  // Set has_entity flag for conditional template rendering (usecase wiring)
  final entityName = context.vars['entity_name'] as String? ?? '';
  context.vars['has_entity'] = entityName.isNotEmpty;

  // has_entity_import: only emit the entity import in the request model when
  // at least one request field is actually of the entity type.
  final entityPascal = entityName.pascalCase;
  final hasEntityField = formattedFields.any((f) => f['type'] == entityPascal);
  context.vars['has_entity_import'] = entityName.isNotEmpty && hasEntityField;

  // Build the call arguments string for wired mode: "request.field1, request.field2"
  if (entityName.isNotEmpty && formattedFields.isNotEmpty) {
    final args = formattedFields.map((f) => 'request.${f['name']}').join(', ');
    context.vars['request_call_args'] = args;
  } else {
    context.vars['request_call_args'] = '';
  }
}
