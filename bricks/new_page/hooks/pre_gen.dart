import 'package:mason/mason.dart';

Future<void> run(HookContext context) async {
  // Inject literal brace characters as variables so that templates
  // can emit { and } without clashing with Mustache's own delimiters.
  context.vars['open_brace'] = '{';
  context.vars['close_brace'] = '}';
}
