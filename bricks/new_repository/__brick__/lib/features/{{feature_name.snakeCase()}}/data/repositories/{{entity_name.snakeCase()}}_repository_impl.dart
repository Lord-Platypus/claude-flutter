import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/data_state.dart';
import '../../../../core/utils/exceptions.dart';
import '../../domain/entities/{{entity_name.snakeCase()}}.dart';
import '../../domain/repositories/{{entity_name.snakeCase()}}_repository.dart';
import '../datasources/local/{{entity_name.snakeCase()}}_local_datasource.dart';

class {{entity_name.pascalCase()}}RepositoryImpl implements {{entity_name.pascalCase()}}Repository {
final {{entity_name.pascalCase()}}LocalDatasource localDatasource;

{{entity_name.pascalCase()}}RepositoryImpl({required this.localDatasource});

{{#methods}} @override
Future<DataState<{{{return_type}}}>> {{name}}({{#has_param}}{{{param_type}}} {{param_name}}{{/has_param}}) async {
try {
final result = await localDatasource.{{name}}({{#has_param}}{{param_name}}{{/has_param}});
return DataSuccess(result);
} catch (e, s) {
AppLogger.exception('{{entity_name.pascalCase()}}RepositoryImpl', '{{name}}', e, s);
return DataFailed(DatabaseException(e.toString()));
}
}

{{/methods}}}
