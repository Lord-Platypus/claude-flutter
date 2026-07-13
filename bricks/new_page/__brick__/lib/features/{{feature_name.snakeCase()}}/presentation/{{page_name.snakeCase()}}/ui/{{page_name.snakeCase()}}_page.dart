import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
{{#usecases}}import '../../../domain/usecases/{{#snakeCase}}{{.}}{{/snakeCase}}/{{#snakeCase}}{{.}}{{/snakeCase}}.dart';
{{/usecases}}import '../../../../../core/app_design_system/widgets/app_error_widget.dart';
import '../../../../../core/app_design_system/widgets/app_loader.dart';
import '../../../../../core/extensions/app_localizations_extensions.dart';
import '../../../../../core/localization/extension/build_context.dart';
import '../bloc/{{bloc_name.snakeCase()}}_bloc.dart';

class {{page_name.pascalCase()}}Page extends StatelessWidget {
const {{page_name.pascalCase()}}Page({super.key});

@override
Widget build(BuildContext context) {
return BlocProvider(
create: (ctx) => {{bloc_name.pascalCase()}}Bloc(
{{#usecases}} {{#camelCase}}{{.}}{{/camelCase}}: ctx.read<{{#pascalCase}}{{.}}{{/pascalCase}}>(),
{{/usecases}})
..add(const Started{{bloc_name.pascalCase()}}Event()),
child: BlocConsumer<{{bloc_name.pascalCase()}}Bloc, {{bloc_name.pascalCase()}}State>(
listener: (context, state) {
if (state is {{bloc_name.pascalCase()}}Error) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(
context.appLocalization.translateException(state.exception),
),
),
);
}
},
builder: (context, state) {
return switch (state) {
{{bloc_name.pascalCase()}}Loading() => const Scaffold(body: AppLoader()),
{{bloc_name.pascalCase()}}Error() => Scaffold(
body: AppErrorWidget(
message: context.appLocalization.translateException(state.exception),
),
),
{{bloc_name.pascalCase()}}Success() => _build{{page_name.pascalCase()}}Content(context),
};
},
),
);
}

Widget _build{{page_name.pascalCase()}}Content(BuildContext context) {
return const Scaffold(
body: SizedBox.expand(),
);
}
}
