import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
{{#pages}}import '../{{#snakeCase}}{{page_name}}{{/snakeCase}}/ui/{{#snakeCase}}{{page_name}}{{/snakeCase}}_page.dart';
{{/pages}}import '../../data/repositories/di/{{entity_name.snakeCase()}}_repository_providers.dart';
import '{{feature_name.snakeCase()}}_destinations.dart';

RouteBase {{feature_name.camelCase()}}RouteProvider(
    {List<RouteBase> childRoutes = const []}) {
  return GoRoute(
    path: {{feature_name.pascalCase()}}Destination.{{#camelCase}}
    {{root_destination_name}}{{/camelCase}}.path,
    pageBuilder: (context, state) =>
        MaterialPage(
            child: MultiProvider(
                providers: {{entity_name.camelCase()}}Providers(),
            child: const {{#pascalCase}}{{root_page_name}}{{/pascalCase}}Page(),
  ),
  ),
  routes: [
  {{#sub_pages}}GoRoute(
  path: '{{{relative_path}}}',
  pageBuilder: (context, state) => MaterialPage(
  child: MultiProvider(
  providers: {{entity_name.camelCase()}}Providers(),
  child: const {{#pascalCase}}{{page_name}}{{/pascalCase}}Page(),
  ),
  ),
  ),
  {{/sub_pages}}...
  childRoutes
  ,
  ]
  ,
  );
}
