import 'dart:convert';
import 'dart:io';

import 'package:mason/mason.dart';

Future<void> run(HookContext context) async {
  final featureName = context.vars['feature_name'] as String;
  final entityName = context.vars['entity_name'] as String;
  final fields = context.vars['fields'] as List<dynamic>;
  final methods = context.vars['methods'] as List<dynamic>;
  final pages = context.vars['pages'] as List<dynamic>;

  // ── 1. new_repository (also calls new_entity internally) ──────────────────
  final repoVars = {
    'feature_name': featureName,
    'entity_name': entityName,
    'fields': fields,
    'methods': methods,
  };

  const repoConfigPath = '/tmp/feature_complete_repo_vars.json';
  await File(repoConfigPath).writeAsString(jsonEncode(repoVars));

  context.logger.info('[$featureName] Running new_repository brick...');
  final repoResult = await Process.run(
    'mason',
    [
      'make',
      'new_repository',
      '--output-dir',
      '.',
      '--on-conflict',
      'skip',
      '--config-path',
      repoConfigPath,
    ],
    runInShell: true,
    workingDirectory: Directory.current.path,
  );

  if (repoResult.exitCode != 0) {
    context.logger.warn(
      '[$featureName] new_repository failed (${repoResult.exitCode}):\n${repoResult.stderr}',
    );
  } else {
    context.logger.success('[$featureName] new_repository done.');
  }

  // ── 2. new_page – one call per page entry ─────────────────────────────────
  for (final raw in pages) {
    final page = raw as Map<String, dynamic>;
    final pageName = page['page_name'] as String;
    final blocName = page['bloc_name'] as String;
    final blocEvents = page['bloc_events'] as List<dynamic>? ?? [];
    final usecases = page['usecases'] as List<dynamic>? ?? [];

    final pageVars = {
      'feature_name': featureName,
      'page_name': pageName,
      'bloc_name': blocName,
      'bloc_events': blocEvents,
      'usecases': usecases,
      'entity_name': entityName,
      'page_path': page['path'] as String? ?? '',
    };

    final pageConfigPath =
        '/tmp/feature_complete_page_${pageName.toLowerCase()}_vars.json';
    await File(pageConfigPath).writeAsString(jsonEncode(pageVars));

    context.logger
        .info('[$featureName] Running new_page brick for $pageName...');
    final pageResult = await Process.run(
      'mason',
      [
        'make',
        'new_page',
        '--output-dir',
        '.',
        '--on-conflict',
        'skip',
        '--config-path',
        pageConfigPath,
      ],
      runInShell: true,
      workingDirectory: Directory.current.path,
    );

    if (pageResult.exitCode != 0) {
      context.logger.warn(
        '[$featureName] new_page ($pageName) failed (${pageResult.exitCode}):\n${pageResult.stderr}',
      );
    } else {
      context.logger.success('[$featureName] new_page ($pageName) done.');
    }
  }

  // ── 3. Compute navigation variables ─────────────────────────────────────
  final featureSnake = featureName.snakeCase;
  final destinations = <Map<String, dynamic>>[];
  final subPages = <Map<String, dynamic>>[];

  for (int i = 0; i < pages.length; i++) {
    final page = pages[i] as Map<String, dynamic>;
    final pageName = page['page_name'] as String;
    final pageSnake = pageName.snakeCase;
    final customPath = page['path'] as String?;

    if (i == 0) {
      final path = customPath ?? '/$featureSnake';
      destinations.add({'name': pageName, 'path': path});
      context.vars['root_destination_name'] = pageName;
      context.vars['root_page_name'] = pageName;
    } else {
      final path = customPath ?? '/$featureSnake/$pageSnake';
      destinations.add({'name': pageName, 'path': path});

      // Derive relative path from the full path
      final rootPath = destinations[0]['path'] as String;
      final relativePath = path.startsWith('$rootPath/')
          ? path.substring(rootPath.length + 1)
          : pageSnake;
      subPages.add({'page_name': pageName, 'relative_path': relativePath});
    }
  }

  context.vars['destinations'] = destinations;
  context.vars['sub_pages'] = subPages;
}
