import 'package:equatable/equatable.dart';
{{#enums}}import '{{{enum_entity_import}}}';
{{/enums}}{{#value_objects}}import '{{{vo_import}}}';
{{/value_objects}}
class {{entity_name.pascalCase()}} extends Equatable {
final int? id;
{{#fields}} final {{type}} {{name}};
{{/fields}}
{{#has_invariants}}
const {{entity_name.pascalCase()}}._({
required this.id,
{{#fields}} required this.{{name}},
{{/fields}} });

factory {{entity_name.pascalCase()}}({
required int? id,
{{#fields}} required {{type}} {{name}},
{{/fields}} }) {
{{#invariants}} if ({{{condition}}}) {
throw ArgumentError.value({{field}}, '{{field}}', '{{{message}}}');
}
{{/invariants}} return {{entity_name.pascalCase()}}._(
id: id,
{{#fields}} {{name}}: {{name}},
{{/fields}} );
}
{{/has_invariants}}
{{^has_invariants}}
const {{entity_name.pascalCase()}}({
required this.id,
{{#fields}} required this.{{name}},
{{/fields}} });
{{/has_invariants}}
{{entity_name.pascalCase()}} copyWith({
int? id,
{{#fields}} {{copy_with_type}} {{name}},
{{/fields}} }) {
return {{entity_name.pascalCase()}}(
id: id ?? this.id,
{{#fields}} {{name}}: {{name}} ?? this.{{name}},
{{/fields}} );
}

@override
List<Object?> get props => [
id,
{{#fields}} {{name}},
{{/fields}} ];
}
