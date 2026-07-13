import 'package:mason/mason.dart';

void run(HookContext context) {
  // Set has_entity flag for conditional template rendering
  final entityName = context.vars['entity_name'] as String? ?? '';
  context.vars['has_entity'] = entityName.isNotEmpty;
}
