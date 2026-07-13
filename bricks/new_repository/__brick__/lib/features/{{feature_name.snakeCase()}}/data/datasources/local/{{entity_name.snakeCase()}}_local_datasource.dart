import '../../../domain/entities/{{entity_name.snakeCase()}}.dart';

abstract
class {{entity_name.pascalCase()}}LocalDatasource {
{{#methods}} Future<{{{return_type}}}> {{name}}({{#has_param}}{{{param_type}}} {{param_name}}{{/has_param}});
{{/methods}}}
