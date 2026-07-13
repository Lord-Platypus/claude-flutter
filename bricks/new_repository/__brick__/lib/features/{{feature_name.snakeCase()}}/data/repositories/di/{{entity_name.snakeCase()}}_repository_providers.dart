import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../domain/repositories/{{entity_name.snakeCase()}}_repository.dart';
{{#methods}}import '../../../domain/usecases/{{#snakeCase}}{{name}}{{/snakeCase}}_{{entity_name.snakeCase()}}_use_case/{{#snakeCase}}{{name}}{{/snakeCase}}_{{entity_name.snakeCase()}}_use_case.dart';
{{/methods}}import '../../datasources/local/di/{{entity_name.snakeCase()}}_local_datasource_providers.dart';
import '../../datasources/local/{{entity_name.snakeCase()}}_local_datasource.dart';
import '../{{entity_name.snakeCase()}}_repository_impl.dart';

SingleChildWidget {{entity_name.camelCase()}}RepositoryProvider() {
  return ProxyProvider<{{entity_name.pascalCase()}}LocalDatasource, {{entity_name.pascalCase()}}Repository>(
    update: (_, ds, _) => {{entity_name.pascalCase()}}RepositoryImpl(localDatasource: ds),
  );
}

List<SingleChildWidget> {{entity_name.camelCase()}}UseCaseProviders() {
  return [
  {{#methods}}ProxyProvider<{{entity_name.pascalCase()}}Repository, {{#pascalCase}}{{name}}{{/pascalCase}}{{entity_name.pascalCase()}}UseCase>(
  update: (_, repo, _) => {{#pascalCase}}{{name}}{{/pascalCase}}{{entity_name.pascalCase()}}UseCase(repo),
  ),
  {{/methods}}];
}

List<SingleChildWidget> {{entity_name.camelCase()}}Providers() {
  return [
    {{entity_name.camelCase()}}LocalDatasourceProvider(),
    {{entity_name.camelCase()}}RepositoryProvider(),
    ...{{entity_name.camelCase()}}UseCaseProviders(),
  ];
}

