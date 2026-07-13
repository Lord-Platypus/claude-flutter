import 'package:mason/mason.dart';

void run(HookContext context) {
  // Inject literal brace characters so templates can emit { and }
  context.vars['open_brace'] = '{';
  context.vars['close_brace'] = '}';
}
