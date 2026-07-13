import 'dart:io';

import 'package:mason/mason.dart';

const _imageExtensions = {
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.svg',
  '.webp',
  '.bmp',
  '.ico',
};

void run(HookContext context) {
  final projectRoot = Directory.current.path;
  final assetsDir = Directory('$projectRoot/assets');

  // Map: subfolder name ('' = root) -> list of file var maps
  final Map<String, List<Map<String, String>>> filesByFolder = {};

  if (assetsDir.existsSync()) {
    for (final entity in assetsDir.listSync(followLinks: false)) {
      if (entity is File) {
        _handleRootFile(entity, filesByFolder);
      } else if (entity is Directory) {
        _handleSubfolder(entity, filesByFolder);
      }
    }
  }

  final subfolders = <Map<String, dynamic>>[];
  final rootFiles = <Map<String, String>>[];

  for (final entry in filesByFolder.entries) {
    if (entry.key.isEmpty) {
      rootFiles.addAll(entry.value);
    } else {
      subfolders.add({
        'class_name': '${entry.key.pascalCase}Images',
        'field_name': entry.key.camelCase,
        'files': entry.value,
      });
    }
  }

  // Sort subfolders by field_name for deterministic output
  subfolders.sort(
    (a, b) => (a['field_name'] as String).compareTo(b['field_name'] as String),
  );

  context.vars['subfolders'] = subfolders;
  context.vars['root_files'] = rootFiles;
  context.vars['has_root'] = rootFiles.isNotEmpty;

  context.logger.info(
    'Found ${subfolders.length} subfolder(s) and ${rootFiles.length} root image(s).',
  );
}

void _handleRootFile(
  File file,
  Map<String, List<Map<String, String>>> filesByFolder,
) {
  final ext = _extension(file.path);
  if (!_imageExtensions.contains(ext)) return;

  filesByFolder.putIfAbsent('', () => []);
  final baseName = _basenameWithoutExtension(file.path);
  filesByFolder['']!.add({
    'field_name': _toFieldName(baseName),
    'path': 'assets/${_basename(file.path)}',
  });
}

void _handleSubfolder(
  Directory dir,
  Map<String, List<Map<String, String>>> filesByFolder,
) {
  final subfolderName = _basename(dir.path);
  // Skip hidden folders
  if (subfolderName.startsWith('.')) return;

  final files = <Map<String, String>>[];
  for (final entity in dir.listSync(followLinks: false)) {
    if (entity is! File) continue;
    final ext = _extension(entity.path);
    if (!_imageExtensions.contains(ext)) continue;

    final baseName = _basenameWithoutExtension(entity.path);
    files.add({
      'field_name': _toFieldName(baseName),
      'path': 'assets/$subfolderName/${_basename(entity.path)}',
    });
  }

  if (files.isNotEmpty) {
    files.sort((a, b) => (a['field_name']!).compareTo(b['field_name']!));
    filesByFolder[subfolderName] = files;
  }
}

/// Returns the lowercase file extension including the dot, e.g. `.png`.
String _extension(String path) {
  final dot = path.lastIndexOf('.');
  if (dot == -1) return '';
  return path.substring(dot).toLowerCase();
}

/// Returns the last path segment (filename).
String _basename(String path) {
  return path.split(Platform.pathSeparator).last;
}

/// Returns the filename without its extension.
String _basenameWithoutExtension(String path) {
  final base = _basename(path);
  final dot = base.lastIndexOf('.');
  if (dot == -1) return base;
  return base.substring(0, dot);
}

/// Converts a filename stem to a valid camelCase Dart identifier.
/// Replaces any non-alphanumeric characters with underscores before casing.
String _toFieldName(String stem) {
  // Replace hyphens, dots, spaces with underscores for reliable recase
  final sanitised = stem.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  return sanitised.camelCase;
}
