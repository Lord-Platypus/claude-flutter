import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
{{#usecases}}import '../../../domain/usecases/{{#snakeCase}}{{.}}{{/snakeCase}}/{{#snakeCase}}{{.}}{{/snakeCase}}.dart';
{{/usecases}}
part '{{bloc_name.snakeCase()}}_event.dart';
part '{{bloc_name.snakeCase()}}_state.dart';

class {{bloc_name.pascalCase()}}Bloc extends Bloc<{{bloc_name.pascalCase()}}Event, {{bloc_name.pascalCase()}}State> {
{{#usecases}} final {{#pascalCase}}{{.}}{{/pascalCase}} _{{#camelCase}}{{.}}{{/camelCase}};
{{/usecases}}
{{bloc_name.pascalCase()}}Bloc({{#usecases.0}}{{{open_brace}}}{{/usecases.0}}
{{#usecases}} required {{#pascalCase}}{{.}}{{/pascalCase}} {{#camelCase}}{{.}}{{/camelCase}},
{{/usecases}} {{#usecases.0}}{{{close_brace}}}{{/usecases.0}}) :
{{#usecases}} _{{#camelCase}}{{.}}{{/camelCase}} = {{#camelCase}}{{.}}{{/camelCase}},
{{/usecases}} super({{bloc_name.pascalCase()}}Loading()) {
on<Started{{bloc_name.pascalCase()}}Event>(_onStarted);
{{#bloc_events}} on<{{#pascalCase}}{{.}}{{/pascalCase}}>(_on{{#pascalCase}}{{.}}{{/pascalCase}});
{{/bloc_events}} }

Future<void> _onStarted(
Started{{bloc_name.pascalCase()}}Event event,
Emitter<{{bloc_name.pascalCase()}}State> emit,
) async {
emit({{bloc_name.pascalCase()}}Loading());
//TODO : implement the logic for the started event
}
{{#bloc_events}}
Future<void> _on{{#pascalCase}}{{.}}{{/pascalCase}}(
{{#pascalCase}}{{.}}{{/pascalCase}} event,
Emitter<{{bloc_name.pascalCase()}}State> emit,
) async {
final currentState = state;
if (currentState is {{bloc_name.pascalCase()}}Success) {
emit({{bloc_name.pascalCase()}}Loading());
//TODO : implement the logic for the {{#pascalCase}}{{.}}{{/pascalCase}} event
} else {
throw Exception('Invalid state: $currentState');
}
}
{{/bloc_events}}}
