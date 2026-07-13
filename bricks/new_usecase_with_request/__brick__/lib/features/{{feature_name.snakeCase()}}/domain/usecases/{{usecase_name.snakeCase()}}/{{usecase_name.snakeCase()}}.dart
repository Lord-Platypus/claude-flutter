import '../../../../../core/utils/data_state.dart';
import '../../../../../core/utils/use_case.dart';
{{#has_entity}}import '../../entities/{{entity_name.snakeCase()}}.dart';
import '../../repositories/{{entity_name.snakeCase()}}_repository.dart';
{{/has_entity}}{{^has_entity}}import '../../entities/{{return_type_name.snakeCase()}}.dart';
{{/has_entity}}import 'model/{{request_type_name.snakeCase()}}.dart';

class {{usecase_name.pascalCase()}} extends UseCaseWithRequest<{{{return_type_name}}}, {{request_type_name.pascalCase()}}> {
{{#has_entity}} final {{entity_name.pascalCase()}}Repository _{{entity_name.camelCase()}}Repository;

{{usecase_name.pascalCase()}}(this._{{entity_name.camelCase()}}Repository);

@override
Future<DataState<{{{return_type_name}}}>> call({{request_type_name.pascalCase()}} request) async {
return _{{entity_name.camelCase()}}Repository.{{repository_method_name}}({{{request_call_args}}});
}
{{/has_entity}}{{^has_entity}} @override
Future<DataState<{{{return_type_name}}}>> call({{request_type_name.pascalCase()}} request) async {
// TODO: Implement {{usecase_name.pascalCase()}} logic
throw UnimplementedError();
}
{{/has_entity}}}
