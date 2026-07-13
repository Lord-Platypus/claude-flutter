import 'package:floor/floor.dart';
import '../models/{{entity_name.snakeCase()}}_model.dart';

@dao
abstract
class {{entity_name.pascalCase()}}Dao {
static const String tableName = '{{entity_name.pascalCase()}}s';

@Query('SELECT * FROM $tableName')
Future<List<{{entity_name.pascalCase()}}Model>> getAll();

@Query('SELECT * FROM $tableName')
Stream<List<{{entity_name.pascalCase()}}Model>> getAllAsStream();

@Query('SELECT * FROM $tableName WHERE id = :id')
Future<{{entity_name.pascalCase()}}Model?> getById(int id);

@insert
Future<int> insertOne({{entity_name.pascalCase()}}Model model);

@insert
Future<void> insertMany(List<{{entity_name.pascalCase()}}Model> models);

@update
Future<void> updateOne({{entity_name.pascalCase()}}Model model);

@update
Future<void> updateMany(List<{{entity_name.pascalCase()}}Model> models);

@delete
Future<void> deleteOne({{entity_name.pascalCase()}}Model model);

@delete
Future<void> deleteMany(List<{{entity_name.pascalCase()}}Model> models);

@Query('DELETE FROM $tableName')
Future<void> deleteAll();

@transaction
Future<void> replaceAll(List<{{entity_name.pascalCase()}}Model> models) async {
await deleteAll();
await insertMany(models);
}
}
