part of '{{bloc_name.snakeCase()}}_bloc.dart';

sealed
class {{bloc_name.pascalCase()}}Event extends Equatable {
const {{bloc_name.pascalCase()}}Event();

@override
List<Object?> get props => [];
}

class Started{{bloc_name.pascalCase()}}Event extends {{bloc_name.pascalCase()}}Event {
const Started{{bloc_name.pascalCase()}}Event();
}
{{#bloc_events}}
class {{#pascalCase}}{{.}}{{/pascalCase}} extends {{bloc_name.pascalCase()}}Event {
const {{#pascalCase}}{{.}}{{/pascalCase}}();
}
{{/bloc_events}}
