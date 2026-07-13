import '../../../../core/utils/data_state.dart';
import '../entities/{{entity_name.snakeCase()}}.dart';

abstract
class {{entity_name.pascalCase()}}Repository {
{{#methods}} Future<DataState<{{{return_type}}}>> {{name}}({{#has_param}}{{{param_type}}} {{param_name}}{{/has_param}});
{{/methods}}}
