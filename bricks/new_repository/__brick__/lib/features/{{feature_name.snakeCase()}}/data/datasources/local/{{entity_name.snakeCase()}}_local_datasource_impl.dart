import '../../dao/{{entity_name.snakeCase()}}_dao.dart';
import '../../../domain/entities/{{entity_name.snakeCase()}}.dart';
import '{{entity_name.snakeCase()}}_local_datasource.dart';

class {{entity_name.pascalCase()}}LocalDatasourceImpl
implements {{entity_name.pascalCase()}}LocalDatasource {
final {{entity_name.pascalCase()}}Dao dao;

{{entity_name.pascalCase()}}LocalDatasourceImpl({required this.dao});

{{#methods}} @override
Future<{{{return_type}}}> {{name}}({{#has_param}}{{{param_type}}} {{param_name}}{{/has_param}}){{{dao_call}}}

{{/methods}}}
