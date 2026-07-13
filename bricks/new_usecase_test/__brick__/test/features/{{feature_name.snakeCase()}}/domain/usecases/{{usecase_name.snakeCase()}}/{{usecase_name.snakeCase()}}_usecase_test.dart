import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:volta_gestionale_mercatini/core/utils/data_state.dart';
import 'package:volta_gestionale_mercatini/features/{{feature_name.snakeCase()}}/domain/entities/{{entity_name.snakeCase()}}.dart';
import 'package:volta_gestionale_mercatini/features/{{feature_name.snakeCase()}}/domain/repositories/{{entity_name.snakeCase()}}_repository.dart';
import 'package:volta_gestionale_mercatini/features/{{feature_name.snakeCase()}}/domain/usecases/{{usecase_name.snakeCase()}}/{{usecase_name.snakeCase()}}.dart';
{{#has_param}}import 'package:volta_gestionale_mercatini/features/{{feature_name.snakeCase()}}/domain/usecases/{{usecase_name.snakeCase()}}/model/{{request_type_snake}}.dart';
{{/has_param}}

class Mock{{entity_name.pascalCase()}}Repository extends Mock implements {{entity_name.pascalCase()}}Repository {}

void main() {
  late {{usecase_name.pascalCase()}} usecase;
  late Mock{{entity_name.pascalCase()}}Repository mockRepository;

  {{#needs_fallback}}setUpAll(() {
    registerFallbackValue({{{fallback_value}}});
  });
  {{/needs_fallback}}

  setUp(() {
  mockRepository = Mock{{entity_name.pascalCase()}}Repository();
    usecase = {{usecase_name.pascalCase()}}(mockRepository);
  });

  group('{{usecase_name.pascalCase()}}', () {
  {{^has_param}}
  test('should_return_DataSuccess_when_repository_call_succeeds', () async {
  // arrange
  when(() => mockRepository.{{repository_method_name}}())
      .thenAnswer((_) async => DataSuccess({{{dummy_return_value}}}));
  // act
  final result = await usecase();
  // assert
  expect(result, isA<DataSuccess>());
  verify(() => mockRepository.{{repository_method_name}}()).called(1);
  verifyNoMoreInteractions(mockRepository);
    });

  test('should_return_DataFailed_when_repository_call_fails', () async {
  // arrange
  final exception = Exception('test error');
  when(() => mockRepository.{{repository_method_name}}())
      .thenAnswer((_) async => DataFailed(exception));
  // act
  final result = await usecase();
  // assert
  expect(result, isA<DataFailed>());
  verify(() => mockRepository.{{repository_method_name}}()).called(1);
  verifyNoMoreInteractions(mockRepository);
    });
  {{/has_param}}{{#has_param}}
  test('should_return_DataSuccess_when_repository_call_succeeds', () async {
  // arrange
  when(() => mockRepository.{{repository_method_name}}(any()))
      .thenAnswer((_) async => DataSuccess({{{dummy_return_value}}}));
  final request = {{request_type_name.pascalCase()}}({{param_name}}: {{{dummy_param_value}}});
  // act
  final result = await usecase(request);
  // assert
  expect(result, isA<DataSuccess>());
  verify(() => mockRepository.{{repository_method_name}}({{{dummy_param_value}}})).called(1);
  verifyNoMoreInteractions(mockRepository);
    });

  test('should_return_DataFailed_when_repository_call_fails', () async {
  // arrange
  final exception = Exception('test error');
  when(() => mockRepository.{{repository_method_name}}(any()))
      .thenAnswer((_) async => DataFailed(exception));
  final request = {{request_type_name.pascalCase()}}({{param_name}}: {{{dummy_param_value}}});
  // act
  final result = await usecase(request);
  // assert
  expect(result, isA<DataFailed>());
  verify(() => mockRepository.{{repository_method_name}}({{{dummy_param_value}}})).called(1);
  verifyNoMoreInteractions(mockRepository);
    });
  {{/has_param}}
  });
}
