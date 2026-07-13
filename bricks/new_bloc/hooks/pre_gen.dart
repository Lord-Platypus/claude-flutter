import 'package:mason/mason.dart';

Future<void> run(HookContext context) async {
  // Inject literal brace characters as variables so that templates can emit
  // { and } without clashing with Mustache's own delimiters.
  context.vars['open_brace'] = '{';
  context.vars['close_brace'] = '}';

  // bloc_path defaults to the bloc name when not supplied. Resolving it here
  // (before generation) lets the template file-path interpolation use it.
  final blocPath = (context.vars['bloc_path'] as String?) ?? '';
  if (blocPath.isEmpty) {
    final blocName = context.vars['bloc_name'] as String;
    context.vars['bloc_path'] = blocName.snakeCase;
  }
}
