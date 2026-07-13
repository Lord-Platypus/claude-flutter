{{#has_entity_import}}import 'package:volta_gestionale_mercatini/features/{{feature_name.snakeCase()}}/domain/entities/{{entity_name.snakeCase()}}.dart';

{{/has_entity_import}}class {{request_type_name.pascalCase()}} {
{{#request_fields}} final {{type}} {{name}};
{{/request_fields}}
const {{request_type_name.pascalCase()}}({
{{#request_fields}} required this.{{name}},
{{/request_fields}} });
}