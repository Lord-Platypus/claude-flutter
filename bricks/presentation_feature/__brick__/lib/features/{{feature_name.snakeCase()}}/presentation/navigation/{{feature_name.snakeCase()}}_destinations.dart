enum {{feature_name.pascalCase()}}Destination {
{{#destinations}} {{#camelCase}}{{name}}{{/camelCase}}('{{{path}}}'),
{{/destinations}} ;

const {{feature_name.pascalCase()}}Destination(this.path);
final String path;
}
