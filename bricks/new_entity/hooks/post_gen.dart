import 'dart:io';

import 'package:mason/mason.dart';

Future<void> run(HookContext context) async {
  final featureName = (context.vars['feature_name'] as String).snakeCase;
  final entityName = context.vars['entity_name'] as String;
  final entitySnake = entityName.snakeCase;
  final entityPascal = entityName.pascalCase;
  final entityCamel = entityName.camelCase;

  // ── 1. Register entity and DAO in app_database.dart ───────────────────────
  final dbPath =
      '${Directory.current.path}/lib/core/database/app_database.dart';
  final dbFile = File(dbPath);

  if (dbFile.existsSync()) {
    var content = await dbFile.readAsString();

    final daoImport =
        "import '../../features/$featureName/data/dao/${entitySnake}_dao.dart';";

    if (!content.contains(daoImport)) {
      final modelImport =
          "import '../../features/$featureName/data/models/${entitySnake}_model.dart';";

      // Insert imports before 'part' directive
      content = content.replaceFirst(
        "part 'app_database.g.dart';",
        "$daoImport\n$modelImport\n\npart 'app_database.g.dart';",
      );

      // Append entity to @Database entities list
      final entitiesRegex = RegExp(r'entities:\s*\[([^\]]*)\]');
      content = content.replaceFirstMapped(entitiesRegex, (match) {
        final existing = match.group(1)!.trim();
        if (existing.isEmpty) {
          return 'entities: [${entityPascal}Model]';
        }
        return 'entities: [$existing, ${entityPascal}Model]';
      });

      // Add DAO getter before closing }
      final lastBrace = content.lastIndexOf('}');
      content =
      '${content.substring(
          0, lastBrace)}  ${entityPascal}Dao get ${entityCamel}Dao;\n}\n';

      await dbFile.writeAsString(content);

      // Format the modified file
      await Process.run(
        'dart',
        ['format', dbPath],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );

      context.logger.success(
        'Registered ${entityPascal}Model and ${entityPascal}Dao in app_database.dart',
      );
    } else {
      context.logger.info(
        '${entityPascal}Dao already registered in app_database.dart – skipping.',
      );
    }
  } else {
    context.logger
        .warn('app_database.dart not found – skipping DB registration.');
  }

  // ── 2. Run build_runner ───────────────────────────────────────────────────
  final progress = context.logger.progress(
    'Running build_runner to generate .g.dart files...',
  );

  final result = await Process.run(
    'dart',
    ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
    runInShell: true,
    workingDirectory: Directory.current.path,
  );

  if (result.exitCode != 0) {
    progress.fail('build_runner failed:\n${result.stderr}');
  } else {
    progress.complete('build_runner done.');
  }
}
