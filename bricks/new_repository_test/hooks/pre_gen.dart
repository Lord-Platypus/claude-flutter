import 'package:mason/mason.dart';

/// Builds a full const entity constructor from entity name + non-id fields.
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
  final rawMethods = context.vars['methods'] as List<dynamic>? ?? [];
  final rawFields = context.vars['fields'] as List<dynamic>? ?? [];
  final entityPascal = entityName.pascalCase;

  var needsFallback = false;
  var fallbackValue = '';

  final methods = rawMethods.map((m) {
    final map = m as Map<String, dynamic>;
    final hasParam = (map['has_param'] as bool?) ?? false;
    final methodName = (map['name'] as String).camelCase;
    final returnType = map['return_type'] as String;
    final paramName = hasParam ? (map['param_name'] as String).camelCase : '';
    final paramType = hasParam ? (map['param_type'] as String) : '';

    final bool returnsVoid = returnType == 'void';

    // Build dummy return value for datasource mock
    final String dummyReturn;
    if (returnsVoid) {
      dummyReturn = 'null';
    } else if (returnType.startsWith('List<')) {
      dummyReturn = 'const []';
    } else if (returnType == 'int') {
      dummyReturn = '1';
    } else if (returnType == 'String') {
      dummyReturn = "'test'";
    } else {
      dummyReturn = _buildEntityDummy(entityPascal, rawFields);
    }

    // Build dummy param value
    String dummyParam = '';
    if (hasParam) {
      if (paramType == 'int') {
        dummyParam = '1';
      } else if (paramType == 'String') {
        dummyParam = "'test'";
      } else if (paramType == entityPascal) {
        dummyParam = _buildEntityDummy(entityPascal, rawFields);
        needsFallback = true;
        fallbackValue = dummyParam;
      } else {
        dummyParam = 'const $paramType()';
      }
    }

    return {
      'name': methodName,
      'return_type': returnType,
      'has_param': hasParam,
      'param_name': paramName,
      'param_type': paramType,
      'returns_void': returnsVoid,
      'dummy_return': dummyReturn,
      'dummy_param': dummyParam,
    };
  }).toList();

  context.vars['methods'] = methods;
  context.vars['needs_fallback'] = needsFallback;
  context.vars['fallback_value'] = fallbackValue;
}
