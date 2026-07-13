import 'dart:convert';
import 'dart:io';

import 'package:mason/mason.dart';

Future<void> run(HookContext context) async {
  context.vars['open_brace'] = '{';
  context.vars['close_brace'] = '}';

  final featureName = context.vars['feature_name'] as String;
  final pages = context.vars['pages'] as List<dynamic>;

  // Call new_page for each page. Nav files do not exist yet at this point,
  // so new_page's post_gen will skip the nav update step — that is expected.
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
      'entity_name': '',
      'page_path': page['path'] as String? ?? '',
    };

    final pageConfigPath =
        '/tmp/presentation_feature_page_${pageName.toLowerCase()}_vars.json';
    await File(pageConfigPath).writeAsString(jsonEncode(pageVars));

    context.logger.info('[$featureName] Running new_page for $pageName...');
    final result = await Process.run(
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

    if (result.exitCode != 0) {
      context.logger.warn(
        '[$featureName] new_page ($pageName) failed:\n${result.stderr}',
      );
    } else {
      context.logger.success('[$featureName] new_page ($pageName) done.');
    }
  }

  // Compute navigation variables for the template files.
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
