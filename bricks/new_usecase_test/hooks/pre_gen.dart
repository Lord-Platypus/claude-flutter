import 'package:mason/mason.dart';

/// Builds a full const entity constructor from entity name + non-id fields.
/// Falls back to `const Entity(id: 1)` when fields list is empty (standalone invocation).
String _buildEntityDummy(String entityPascal, List<dynamic> fields) {
  if (fields.isEmpty) return 'const $entityPascal(id: 1)';
  final args = <String>['id: 1'];
  for (final raw in fields) {
    final f = raw as Map<String, dynamic>;
    final name = f['name'] as String;
    final type = f['type'] as String;
    // Nullable types (e.g. String?) use null as the test value
    if (type.endsWith('?')) {
      args.add('$name: null');
    } else {
      switch (type) {
        case 'String':
          args.add("$name: 'test'");
        case 'int':
          args.add('$name: 0');
        case 'double':
          args.add('$name: 0.0');
        case 'bool':
          args.add('$name: false');
        default:
          args.add('$name: const $type()');
      }
    }
  }
  return 'const $entityPascal(${args.join(', ')})';
}

void run(HookContext context) {
  final entityName = context.vars['entity_name'] as String? ?? '';
  final usecaseName = context.vars['usecase_name'] as String? ?? '';
  final hasParam = context.vars['has_param'] as bool? ?? false;
  final paramName = context.vars['param_name'] as String? ?? '';
  final paramType = context.vars['param_type'] as String? ?? '';
  final returnType = context.vars['return_type_name'] as String? ?? '';
  final rawFields = context.vars['fields'] as List<dynamic>? ?? [];

  // Default repository_method_name from usecase_name if not provided
  var repoMethod = context.vars['repository_method_name'] as String? ?? '';
  if (repoMethod.isEmpty) {
    var base = usecaseName;
    if (base.endsWith('UseCase')) {
      base = base.substring(0, base.length - 7);
    }
    repoMethod = base.camelCase;
  }
  context.vars['repository_method_name'] = repoMethod;

  // Compute the request type name for parameterised usecases
  if (hasParam) {
    var base = usecaseName;
    if (base.endsWith('UseCase')) {
      base = base.substring(0, base.length - 7);
    }
    context.vars['request_type_name'] = '${base.pascalCase}Request';
    context.vars['request_type_snake'] = '${base.snakeCase}_request';
  }

  context.vars['returns_void'] = returnType == 'void';

  // Build dummy return value
  final String dummyValue;
  if (returnType == 'void') {
    dummyValue = 'null';
  } else if (returnType.startsWith('List<')) {
    dummyValue = 'const []';
  } else if (returnType == 'int') {
    dummyValue = '1';
  } else if (returnType == 'double') {
    dummyValue = '1.0';
  } else if (returnType == 'String') {
    dummyValue = "'test'";
  } else if (returnType == 'bool') {
    dummyValue = 'true';
  } else {
    dummyValue = _buildEntityDummy(entityName.pascalCase, rawFields);
  }
  context.vars['dummy_return_value'] = dummyValue;

  // Build dummy param value + fallback registration flag
  var needsFallback = false;
  if (hasParam) {
    final String dummyParam;
    if (paramType == 'int') {
      dummyParam = '1';
    } else if (paramType == 'double') {
      dummyParam = '1.0';
    } else if (paramType == 'String') {
      dummyParam = "'test'";
    } else if (paramType == 'bool') {
      dummyParam = 'true';
    } else if (paramType == entityName.pascalCase) {
      dummyParam = _buildEntityDummy(entityName.pascalCase, rawFields);
      needsFallback = true;
    } else {
      dummyParam = 'const $paramType()';
    }
    context.vars['dummy_param_value'] = dummyParam;
    context.vars['fallback_value'] = dummyParam;
  }
  context.vars['needs_fallback'] = needsFallback;
}
