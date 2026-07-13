import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:volta_gestionale_mercatini/core/utils/data_state.dart';
import 'package:volta_gestionale_mercatini/core/utils/exceptions.dart';
import 'package:volta_gestionale_mercatini/features/{{feature_name.snakeCase()}}/domain/entities/{{entity_name.snakeCase()}}.dart';
import 'package:volta_gestionale_mercatini/features/{{feature_name.snakeCase()}}/data/datasources/local/{{entity_name.snakeCase()}}_local_datasource.dart';
import 'package:volta_gestionale_mercatini/features/{{feature_name.snakeCase()}}/data/repositories/{{entity_name.snakeCase()}}_repository_impl.dart';

class Mock{{entity_name.pascalCase()}}LocalDatasource extends Mock implements {{entity_name.pascalCase()}}LocalDatasource {}

void main() {
  late {{entity_name.pascalCase()}}RepositoryImpl repository;
  late Mock{{entity_name.pascalCase()}}LocalDatasource mockLocalDatasource;

  {{#needs_fallback}}setUpAll(() {
    registerFallbackValue({{{fallback_value}}});
  });
  {{/needs_fallback}}

  setUp(() {
  mockLocalDatasource = Mock{{entity_name.pascalCase()}}LocalDatasource();
    repository = {{entity_name.pascalCase()}}RepositoryImpl(
      localDatasource: mockLocalDatasource,
    );
  });

  group('{{entity_name.pascalCase()}}RepositoryImpl', () {
  {{#methods}}
    group('{{name}}', () {
  test('should_return_DataSuccess_when_datasource_call_succeeds', () async {
        // arrange
        when(() => mockLocalDatasource.{{name}}({{#has_param}}any(){{/has_param}}))
  {{#returns_void}}.thenAnswer((_) async {});{{/returns_void}}{{^returns_void}}.thenAnswer((_) async => {{{dummy_return}}});{{/returns_void}}
        // act
        final result = await repository.{{name}}({{#has_param}}{{{dummy_param}}}{{/has_param}});
        // assert
        expect(result, isA<DataSuccess>());
  verify(() => mockLocalDatasource.{{name}}({{#has_param}}{{{dummy_param}}}{{/has_param}})).called(1);
  verifyNoMoreInteractions(mockLocalDatasource);
      });

  test('should_return_DataFailed_when_datasource_throws', () async {
        // arrange
        when(() => mockLocalDatasource.{{name}}({{#has_param}}any(){{/has_param}}))
      .thenThrow(DatabaseException('test error'));
        // act
  final result = await repository.{{name}}({{#has_param}}{{{dummy_param}}}{{/has_param}});
        // assert
        expect(result, isA<DataFailed>());
  verify(() => mockLocalDatasource.{{name}}({{#has_param}}{{{dummy_param}}}{{/has_param}})).called(1);
  verifyNoMoreInteractions(mockLocalDatasource);
      });
    });
  {{/methods}}
  });
}
