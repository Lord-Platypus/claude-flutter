import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../../../../../core/database/app_database.dart';
import '../{{entity_name.snakeCase()}}_local_datasource.dart';
import '../{{entity_name.snakeCase()}}_local_datasource_impl.dart';

SingleChildWidget {{entity_name.camelCase()}}LocalDatasourceProvider() {
  return ProxyProvider < AppDatabase
  , {{entity_name.pascalCase()}}LocalDatasource>(
  update: (_, db, _) => {{entity_name.pascalCase()}}LocalDatasourceImpl(dao: db.{{entity_name.camelCase()}}Dao
  )
  ,
  );
}

