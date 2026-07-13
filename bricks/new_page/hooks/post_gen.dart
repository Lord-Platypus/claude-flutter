import 'dart:convert';
import 'dart:io';

import 'package:mason/mason.dart';

Future<void> run(HookContext context) async {
  // ── 1. Format lib ─────────────────────────────────────────────────────────
  await Process.run(
    'dart',
    ['format', 'lib'],
    runInShell: true,
    workingDirectory: Directory.current.path,
  );

  // ── 2. Generate bloc test ─────────────────────────────────────────────────
  final featureName = context.vars['feature_name'] as String;
  final pageName = context.vars['page_name'] as String;
  final blocName = context.vars['bloc_name'] as String;
  final blocEvents = context.vars['bloc_events'] as List<dynamic>? ?? [];
  final usecases = context.vars['usecases'] as List<dynamic>? ?? [];
  final entityName = context.vars['entity_name'] as String? ?? '';

  // ── 1b. Generate the BLoC via the new_bloc brick ──────────────────────────
  // The bloc/event/state templates live in new_bloc only (single source of
  // truth). new_page nests the bloc under the page folder by passing the page
  // name as bloc_path → presentation/{page}/bloc/.
  final blocVars = jsonEncode({
    'feature_name': featureName,
    'bloc_name': blocName,
    'bloc_path': pageName,
    'bloc_events': blocEvents,
    'usecases': usecases,
  });

  final blocConfigPath = '/tmp/new_page_bloc_${blocName.toLowerCase()}_vars.json';
  await File(blocConfigPath).writeAsString(blocVars);

  context.logger.info('[$featureName] Running new_bloc for $blocName...');
  final blocResult = await Process.run(
    'mason',
    [
      'make',
      'new_bloc',
      '--output-dir',
      '.',
      '--on-conflict',
      'skip',
      '--config-path',
      blocConfigPath,
    ],
    runInShell: true,
    workingDirectory: Directory.current.path,
  );

  if (blocResult.exitCode != 0) {
    context.logger.warn(
      '[$featureName] new_bloc ($blocName) failed '
      '(${blocResult.exitCode}):\n${blocResult.stderr}',
    );
  } else {
    context.logger.success('[$featureName] new_bloc ($blocName) done.');
  }

  final testVars = jsonEncode({
    'feature_name': featureName,
    'entity_name': entityName,
    'page_name': pageName,
    'bloc_name': blocName,
    'bloc_events': blocEvents,
    'usecases': usecases,
  });

  final testConfigPath =
      '/tmp/new_page_bloc_test_${blocName.toLowerCase()}_vars.json';
  await File(testConfigPath).writeAsString(testVars);

  context.logger.info('[$featureName] Running new_bloc_test for $blocName...');
  final testResult = await Process.run(
    'mason',
    [
      'make',
      'new_bloc_test',
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
      '[$featureName] new_bloc_test ($blocName) failed '
      '(${testResult.exitCode}):\n${testResult.stderr}',
    );
  } else {
    context.logger.success('[$featureName] new_bloc_test ($blocName) done.');
  }

  // Format test files too
  await Process.run(
    'dart',
    ['format', 'test'],
    runInShell: true,
    workingDirectory: Directory.current.path,
  );

  // ── 3. Auto-update navigation files ───────────────────────────────────────
  final featureSnake = featureName.snakeCase;
  final pageSnake = pageName.snakeCase;
  final entitySnake = entityName.snakeCase;
  final entityCamel = entityName.camelCase;

  final destinationsPath =
      '${Directory.current
      .path}/lib/features/$featureSnake/presentation/navigation/${featureSnake}_destinations.dart';
  final routeProviderPath =
      '${Directory.current
      .path}/lib/features/$featureSnake/presentation/navigation/${featureSnake}_route_provider.dart';

  final destinationsFile = File(destinationsPath);
  final routeProviderFile = File(routeProviderPath);

  if (!destinationsFile.existsSync() || !routeProviderFile.existsSync()) {
    context.logger.info(
      'Navigation files not found – skipping route registration. '
          'Run feature_complete to generate them.',
    );
    return;
  }

  final pagePascal = pageName.pascalCase;
  final pageCamel = pageName.camelCase;

  // Derive full path: use page_path if provided, else /{feature}/{page_snake}
  final customPath = context.vars['page_path'] as String? ?? '';
  final fullPath =
  customPath.isNotEmpty ? customPath : '/$featureSnake/$pageSnake';

  // Derive relative path from full path
  final rootPathPrefix = '/$featureSnake/';
  final relativePath = fullPath.startsWith(rootPathPrefix)
      ? fullPath.substring(rootPathPrefix.length)
      : pageSnake;

  // ── 3a. Update destinations enum ──────────────────────────────────────────
  var destContent = await destinationsFile.readAsString();
  final destValue = "  $pageCamel('$fullPath'),";
  if (!destContent.contains("$pageCamel(")) {
    final semiOnOwnLine = RegExp(r'^  ;$', multiLine: true);

    if (semiOnOwnLine.hasMatch(destContent)) {
      destContent = destContent.replaceFirst(semiOnOwnLine, '$destValue\n  ;');
    } else {
      destContent = destContent.replaceFirst(
        RegExp(r"\);\s*\n(\s*\n\s*const)"),
        '),\n$destValue;\n\n  const',
      );
    }
    await destinationsFile.writeAsString(destContent);
    context.logger.success('Added $pageCamel destination.');
  }

  // ── 3b. Update route provider ─────────────────────────────────────────────
  var routeContent = await routeProviderFile.readAsString();
  final pageImport =
      "import '../$pageSnake/ui/${pageSnake}_page.dart';";
  if (!routeContent.contains(pageImport)) {
    routeContent = routeContent.replaceFirst(
      "import '${featureSnake}_destinations.dart';",
      "$pageImport\nimport '${featureSnake}_destinations.dart';",
    );
  }

  // Ensure provider + material imports exist
  if (!routeContent.contains("import 'package:provider/provider.dart';")) {
    routeContent = routeContent.replaceFirst(
      "import 'package:go_router/go_router.dart';",
      "import 'package:flutter/material.dart';\nimport 'package:go_router/go_router.dart';\nimport 'package:provider/provider.dart';",
    );
  }

  // Ensure repository providers import exists
  final repoProvidersImport =
      "import '../../data/repositories/di/${entitySnake}_repository_providers.dart';";
  if (entityName.isNotEmpty && !routeContent.contains(repoProvidersImport)) {
    routeContent = routeContent.replaceFirst(
      "import '${featureSnake}_destinations.dart';",
      "$repoProvidersImport\nimport '${featureSnake}_destinations.dart';",
    );
  }

  final providersExpr = entityCamel.isNotEmpty
      ? '${entityCamel}Providers()'
      : 'const []';

  final newRoute =
      "      GoRoute(\n"
      "        path: '$relativePath',\n"
      "        pageBuilder: (context, state) => MaterialPage(\n"
      "          child: MultiProvider(\n"
      "            providers: $providersExpr,\n"
      "            child: const ${pagePascal}Page(),\n"
      "          ),\n"
      "        ),\n"
      "      ),";
  if (!routeContent.contains('${pagePascal}Page()')) {
    routeContent = routeContent.replaceFirst(
      '      ...childRoutes,',
      '$newRoute\n      ...childRoutes,',
    );
  }

  await routeProviderFile.writeAsString(routeContent);

  // Format navigation files
  await Process.run(
    'dart',
    ['format', destinationsPath, routeProviderPath],
    runInShell: true,
    workingDirectory: Directory.current.path,
  );

  context.logger.success(
    'Added ${pagePascal}Page route to navigation.',
  );
}
