import 'package:floor/floor.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/{{entity_name.snakeCase()}}.dart';
{{#enums}}import '{{{enum_model_import}}}';
{{/enums}}{{#value_objects}}import '{{{vo_import}}}';
{{/value_objects}}
part '{{entity_name.snakeCase()}}_model.g.dart';

@Entity(tableName: '{{entity_name.pascalCase()}}s')
@JsonSerializable()
class {{entity_name.pascalCase()}}Model {
@PrimaryKey(autoGenerate: true)
final int? id;
{{#fields}} final {{model_type}} {{name}};
{{/fields}}
const {{entity_name.pascalCase()}}Model({
required this.id,
{{#fields}} required this.{{name}},
{{/fields}} });

factory {{entity_name.pascalCase()}}Model.fromEntity({{entity_name.pascalCase()}} e) =>
{{entity_name.pascalCase()}}Model(
id: e.id,
{{#fields}} {{name}}: {{{to_model}}},
{{/fields}} );

{{entity_name.pascalCase()}} toEntity() =>
{{entity_name.pascalCase()}}(
id: id,
{{#fields}} {{name}}: {{{to_entity}}},
{{/fields}} );

factory {{entity_name.pascalCase()}}Model.fromJson(Map<String, dynamic> json) =>
_${{entity_name.pascalCase()}}ModelFromJson(json);

Map<String, dynamic> toJson() =>
_${{entity_name.pascalCase()}}ModelToJson(this);
}
