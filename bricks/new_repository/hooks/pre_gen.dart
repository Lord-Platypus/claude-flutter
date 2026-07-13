import 'dart:convert';
import 'dart:io';

import 'package:mason/mason.dart';

Future<void> run(HookContext context) async {
  // ── 1. Normalise fields ────────────────────────────────────────────────────
  final rawFields = context.vars['fields'] as List<dynamic>? ?? [];
  final fields = rawFields
      .map((f) {
        final map = f as Map<String, dynamic>;
        return {
          'name': (map['name'] as String).camelCase,
          'type': map['type'] as String,
        };
      })
      .where((f) => f['name'] != 'id')
      .toList();
  context.vars['fields'] = fields;

  final entityName = context.vars['entity_name'] as String;
  final entityPascal = entityName.pascalCase;

  // ── 2. Normalise methods and compute dao_call for each ────────────────────
  final rawMethods = context.vars['methods'] as List<dynamic>? ?? [];
  final methods = rawMethods.map((m) {
    final map = m as Map<String, dynamic>;
    final hasParam = (map['has_param'] as bool?) ?? false;
    final methodName = (map['name'] as String).camelCase;
    final returnType = map['return_type'] as String;
    final paramName = hasParam ? (map['param_name'] as String).camelCase : '';
    final paramType = hasParam ? (map['param_type'] as String) : '';

    final bool returnsVoid = returnType == 'void';
    final bool returnsList = returnType.startsWith('List<');
    final bool paramIsEntity = hasParam && paramType == entityPascal;

    final String daoCall;
    if (!hasParam) {
      daoCall = ' => dao.getAll();';
    } else if (paramIsEntity) {
      final isUpdate = methodName.toLowerCase().contains('update');
      final daoOp = isUpdate ? 'updateOne' : 'insertOne';
      // Build full field list: id + all non-id fields
      final fieldLines = <String>['      id: $paramName.id,'];
      for (final f in fields) {
        final fname = f['name'] as String;
        fieldLines.add('      $fname: $paramName.$fname,');
      }
      final fieldMapping = fieldLines.join('\n');
      daoCall = ''' async {
    await dao.$daoOp(${entityPascal}Model(
$fieldMapping
    ));
  }''';
    } else if (returnsVoid) {
      daoCall = ''' async {
    final model = await dao.getById($paramName);
    if (model == null) throw Exception('$entityPascal not found: \$$paramName');
    await dao.deleteOne(model);
  }''';
    } else if (returnsList) {
      daoCall = ''' async {
    // TODO: add a @Query method to DAO for this filter
    return dao.getAll();
  }''';
    } else {
      daoCall = ''' async {
    final model = await dao.getById($paramName);
    if (model == null) throw Exception('$entityPascal not found: \$$paramName');
    return model;
  }''';
    }

    return {
      'name': methodName,
      'return_type': returnType,
      'has_param': hasParam,
      'param_name': paramName,
      'param_type': paramType,
      'dao_call': daoCall,
    };
  }).toList();
  context.vars['methods'] = methods;

  final featureName = context.vars['feature_name'] as String;

  // ── 3. Shell out: mason make new_entity ───────────────────────────────────
  final entityVars = jsonEncode({
    'feature_name': featureName,
    'entity_name': entityName,
    'fields': fields,
  });
  final entityConfig = File('/tmp/new_entity_vars.json');
  await entityConfig.writeAsString(entityVars);

  context.logger.info('Running new_entity brick...');
  final entityResult = await Process.run(
    'mason',
    [
      'make',
      'new_entity',
      '--output-dir',
      '.',
      '--on-conflict',
      'skip',
      '--config-path',
      '/tmp/new_entity_vars.json',
    ],
    runInShell: true,
    workingDirectory: Directory.current.path,
  );
  if (entityResult.exitCode != 0) {
    context.logger.warn(
        'new_entity failed (${entityResult.exitCode}): ${entityResult.stderr}');
  } else {
    context.logger.success('new_entity done.');
  }

  // ── 4. Generate usecases via bricks (one per method) ─────────────────────
  for (final method in methods) {
    final methodName = method['name'] as String;
    final returnType = method['return_type'] as String;
    final hasParam = method['has_param'] as bool;
    final paramName = method['param_name'] as String;
    final paramType = method['param_type'] as String;

    final usecasePascal = methodName.pascalCase;
    final usecaseFullName = '${usecasePascal}${entityPascal}UseCase';

    if (hasParam) {
      // Use new_usecase_with_request brick
      final requestTypeName = '${usecasePascal}${entityPascal}Request';
      final usecaseVars = jsonEncode({
        'feature_name': featureName,
        'usecase_name': usecaseFullName,
        'return_type_name': returnType,
        'request_type_name': requestTypeName,
        'request_fields': [
          {'name': paramName, 'type': paramType},
        ],
        'entity_name': entityName,
        'repository_method_name': methodName,
      });

      final usecaseConfigPath =
          '/tmp/new_repo_usecase_${methodName.toLowerCase()}_vars.json';
      await File(usecaseConfigPath).writeAsString(usecaseVars);

      context.logger.info(
          '[$featureName] Running new_usecase_with_request for $usecasePascal...');
      final usecaseResult = await Process.run(
        'mason',
        [
          'make',
          'new_usecase_with_request',
          '--output-dir',
          '.',
          '--on-conflict',
          'skip',
          '--config-path',
          usecaseConfigPath,
        ],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );

      if (usecaseResult.exitCode != 0) {
        context.logger.warn(
          '[$featureName] new_usecase_with_request ($usecasePascal) failed '
          '(${usecaseResult.exitCode}):\n${usecaseResult.stderr}',
        );
      } else {
        context.logger.success(
            '[$featureName] new_usecase_with_request ($usecasePascal) done.');
      }
    } else {
      // Use new_usecase brick
      final usecaseVars = jsonEncode({
        'feature_name': featureName,
        'usecase_name': usecaseFullName,
        'return_type_name': returnType,
        'entity_name': entityName,
        'repository_method_name': methodName,
      });

      final usecaseConfigPath =
          '/tmp/new_repo_usecase_${methodName.toLowerCase()}_vars.json';
      await File(usecaseConfigPath).writeAsString(usecaseVars);

      context.logger
          .info('[$featureName] Running new_usecase for $usecasePascal...');
      final usecaseResult = await Process.run(
        'mason',
        [
          'make',
          'new_usecase',
          '--output-dir',
          '.',
          '--on-conflict',
          'skip',
          '--config-path',
          usecaseConfigPath,
        ],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );

      if (usecaseResult.exitCode != 0) {
        context.logger.warn(
          '[$featureName] new_usecase ($usecasePascal) failed '
          '(${usecaseResult.exitCode}):\n${usecaseResult.stderr}',
        );
      } else {
        context.logger
            .success('[$featureName] new_usecase ($usecasePascal) done.');
      }
    }
  }

  // ── 5. Generate usecase tests (one per method) ────────────────────────────
  for (final method in methods) {
    final methodName = method['name'] as String;
    final returnType = method['return_type'] as String;
    final hasParam = method['has_param'] as bool;
    final paramName = method['param_name'] as String;
    final paramType = method['param_type'] as String;

    final usecaseFullName = '${methodName.pascalCase}${entityPascal}UseCase';

    final testVars = jsonEncode({
      'feature_name': featureName,
      'entity_name': entityName,
      'fields': fields,
      'usecase_name': usecaseFullName,
      'return_type_name': returnType,
      'repository_method_name': methodName,
      'has_param': hasParam,
      'param_name': paramName,
      'param_type': paramType,
    });

    final testConfigPath =
        '/tmp/new_repo_usecase_test_${methodName.toLowerCase()}_vars.json';
    await File(testConfigPath).writeAsString(testVars);

    context.logger.info(
        '[$featureName] Running new_usecase_test for $usecaseFullName...');
    final testResult = await Process.run(
      'mason',
      [
        'make',
        'new_usecase_test',
        '--output-dir',
        '.',
        '--on-conflict',
        'skip',
        '--config-path',
        testConfigPath,
      ],
      runInShell: true,
      workingDirectory: Directory.current.path,
    );

    if (testResult.exitCode != 0) {
      context.logger.warn(
        '[$featureName] new_usecase_test ($usecaseFullName) failed '
        '(${testResult.exitCode}):\n${testResult.stderr}',
      );
    } else {
      context.logger
          .success('[$featureName] new_usecase_test ($usecaseFullName) done.');
    }
  }

  // ── 6. Generate repository test ───────────────────────────────────────────
  final repoTestVars = jsonEncode({
    'feature_name': featureName,
    'entity_name': entityName,
    'fields': fields,
    'methods': methods,
  });

  const repoTestConfigPath = '/tmp/new_repo_test_vars.json';
  await File(repoTestConfigPath).writeAsString(repoTestVars);

  context.logger.info('[$featureName] Running new_repository_test...');
  final repoTestResult = await Process.run(
    'mason',
    [
      'make',
      'new_repository_test',
      '--output-dir',
      '.',
      '--on-conflict',
      'skip',
      '--config-path',
      repoTestConfigPath,
    ],
    runInShell: true,
    workingDirectory: Directory.current.path,
  );

  if (repoTestResult.exitCode != 0) {
    context.logger.warn(
      '[$featureName] new_repository_test failed '
      '(${repoTestResult.exitCode}):\n${repoTestResult.stderr}',
    );
  } else {
    context.logger.success('[$featureName] new_repository_test done.');
  }
}
