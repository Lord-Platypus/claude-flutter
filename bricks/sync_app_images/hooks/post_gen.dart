import 'dart:io';

import 'package:mason/mason.dart';

Future<void> run(HookContext context) async {
  final filePath =
      '${Directory.current.path}/lib/theme/token/light_app_images.dart';
  final progress = context.logger.progress('Formatting generated file...');
  final result = await Process.run(
    'dart',
    ['format', filePath],
    runInShell: true,
    workingDirectory: Directory.current.path,
  );
  if (result.exitCode != 0) {
    progress.fail('dart format failed:\n${result.stderr}');
  } else {
    progress.complete('Generated lib/theme/token/light_app_images.dart');
  }
}
