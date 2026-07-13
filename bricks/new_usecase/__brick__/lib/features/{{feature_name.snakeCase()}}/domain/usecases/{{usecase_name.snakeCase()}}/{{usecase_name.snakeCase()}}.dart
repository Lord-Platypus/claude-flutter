import '../../../../../core/utils/data_state.dart';
import '../../../../../core/utils/use_case.dart';
{{#has_entity}}import '../../entities/{{entity_name.snakeCase()}}.dart';
import '../../repositories/{{entity_name.snakeCase()}}_repository.dart';
{{/has_entity}}
class {{usecase_name.pascalCase()}} extends UseCaseBase<{{{return_type_name}}}> {
{{#has_entity}} final {{entity_name.pascalCase()}}Repository _{{entity_name.camelCase()}}Repository;

{{usecase_name.pascalCase()}}(this._{{entity_name.camelCase()}}Repository);

@override
Future<DataState<{{{return_type_name}}}>> call() async {
return _{{entity_name.camelCase()}}Repository.{{repository_method_name}}();
}
{{/has_entity}}{{^has_entity}} @override
Future<DataState<{{{return_type_name}}}>> call() async {
// TODO: Implement {{usecase_name.pascalCase()}} logic
throw UnimplementedError();
}
{{/has_entity}}}
