import 'dart:io';

import 'package:mason/mason.dart';

Future<void> run(HookContext context) async {
  // Mustache rendering leaves the bloc templates un-indented; format only the
  // generated bloc folder (never the whole project — that would touch *.g.dart
  // and risk bricks/). If the folder does not exist (throwaway output-dir),
  // dart format simply no-ops.
  final featureSnake = (context.vars['feature_name'] as String).snakeCase;
  final blocPathRaw = (context.vars['bloc_path'] as String?) ?? '';
  final blocName = context.vars['bloc_name'] as String;
  final blocPathSnake = blocPathRaw.isEmpty
      ? blocName.snakeCase
      : blocPathRaw.snakeCase;

  final blocDir =
      'lib/features/$featureSnake/presentation/$blocPathSnake/bloc';

  await Process.run(
    'dart',
    ['format', blocDir],
    runInShell: true,
    workingDirectory: Directory.current.path,
  );
}
