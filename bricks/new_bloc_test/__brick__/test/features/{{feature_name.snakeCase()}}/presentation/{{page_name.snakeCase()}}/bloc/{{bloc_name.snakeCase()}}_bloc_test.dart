import 'package:flutter_test/flutter_test.dart';
{{#usecases.0}}import 'package:mocktail/mocktail.dart';
{{/usecases.0}}{{#usecases}}import 'package:volta_gestionale_mercatini/features/{{feature_name.snakeCase()}}/domain/usecases/{{#snakeCase}}{{.}}{{/snakeCase}}/{{#snakeCase}}{{.}}{{/snakeCase}}.dart';
{{/usecases}}import 'package:volta_gestionale_mercatini/features/{{feature_name.snakeCase()}}/presentation/{{page_name.snakeCase()}}/bloc/{{bloc_name.snakeCase()}}_bloc.dart';

{{#usecases}}class Mock{{#pascalCase}}{{.}}{{/pascalCase}} extends Mock implements {{#pascalCase}}{{.}}{{/pascalCase}} {}
{{/usecases}}
void main() {
  late {{bloc_name.pascalCase()}}Bloc bloc;
  {{#usecases}}late Mock{{#pascalCase}}{{.}}{{/pascalCase}} mock{{#pascalCase}}{{.}}{{/pascalCase}};
  {{/usecases}}
  setUp(() {
  {{#usecases}}mock{{#pascalCase}}{{.}}{{/pascalCase}} = Mock{{#pascalCase}}{{.}}{{/pascalCase}}();
  {{/usecases}}bloc = {{bloc_name.pascalCase()}}Bloc(
  {{#usecases}}{{#camelCase}}{{.}}{{/camelCase}}: mock{{#pascalCase}}{{.}}{{/pascalCase}},
  {{/usecases}});
  });

  tearDown(() {
  bloc.close();
  });

  group('{{bloc_name.pascalCase()}}Bloc', () {
  test('should_have_Loading_as_initial_state', () {
  expect(bloc.state, isA<{{bloc_name.pascalCase()}}Loading>());
  });

  test('should_emit_Loading_when_Started_event_is_added', () async {
  final states = <{{bloc_name.pascalCase()}}State>[];
  final sub = bloc.stream.listen(states.add);
  bloc.add(const Started{{bloc_name.pascalCase()}}Event());
  await Future<void>.delayed(Duration.zero);
  expect(states, [isA<{{bloc_name.pascalCase()}}Loading>()]);
  await sub.cancel();
  });
  {{#bloc_events}}
  // TODO: Implement specific test for {{#pascalCase}}{{.}}{{/pascalCase}}
  // test('should_emit_expected_states_when_{{.}}_is_added', () async {
  //   // Seed the bloc into the expected prior state, then:
  //   final states = <{{bloc_name.pascalCase()}}State>[];
  //   final sub = bloc.stream.listen(states.add);
  //
  //   bloc.add(const {{#pascalCase}}{{.}}{{/pascalCase}}());
  //   await Future<void>.delayed(Duration.zero);
  //
  //   expect(states, [isA<{{bloc_name.pascalCase()}}Loading>()]);
  //   await sub.cancel();
  // });
      {{/bloc_events}}
  });
}
