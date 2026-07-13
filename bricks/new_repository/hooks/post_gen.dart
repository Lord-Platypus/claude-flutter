import 'dart:io';

import 'package:mason/mason.dart';

Future<void> run(HookContext context) async {
  // ── 1. Format generated files ─────────────────────────────────────────────
  context.logger.info('Formatting generated files...');
  await Process.run(
    'dart',
    ['format', 'lib'],
    runInShell: true,
    workingDirectory: Directory.current.path,
  );
  await Process.run(
    'dart',
    ['format', 'test'],
    runInShell: true,
    workingDirectory: Directory.current.path,
  );
  context.logger.success('Formatting done.');
}
