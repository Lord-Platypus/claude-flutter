# Data Layer Conventions

Read this **before editing any file under `lib/features/*/data/`**.

Covers: repositories, datasources, models, Floor schema/migrations, error logging.

---

## 1. Layer Chain

`DAO → LocalDatasource (abstract) → LocalDatasourceImpl → RepositoryImpl → UseCase`

- The DAO is **read inline** as `db.xDao` inside the LocalDatasource — there is no separate
  DAO provider.
- The `LocalDatasource` is an abstract class, `LocalDatasourceImpl` implements it.
- `RepositoryImpl` injects the abstract `LocalDatasource`, not the impl, not the DAO.
- Tests mock the `LocalDatasource`.

> **Note:** `docs/architecture/templates.md §6` and `§9` show `RepositoryImpl` injecting
> `AppDatabase` + DAO directly. Those templates are outdated. Follow the brick-generated
> pattern above.

---

## 2. Error Handling

### Repository pattern (Zero Tolerance)

Every `RepositoryImpl` method follows this pattern:

```dart
Future<DataState<Customer?>> getById(GetByIdCustomerRequest request) async {
  try {
    final result = await _localDatasource.getById(request.id);
    return DataSuccess(result);
  } catch (e, s) {
    AppLogger.exception('CustomerRepositoryImpl', 'getById', e, s);
    return DataFailed(DatabaseException(e.toString()));
  }
}
```

- **`AppLogger.exception(...)` first**, then `DataFailed`. Import from
  `lib/core/utils/app_logger.dart`. **Never use raw `debugPrint`** in a repository catch
  block — `AppLogger` is the only sanctioned logging entry point here.
- Signature: `AppLogger.exception(String source, String operation, Object error,
  [StackTrace? stackTrace])` — pass the repository class name as `source` and the method
  name as `operation`.
- `AppLogger` is console-only today (wraps `debugPrint`, same
  `[Source] op error: $e\n$s` output). It is the **single place to change** when
  server-side or structured logging is introduced later.
- The `new_repository` brick generates this call automatically. Hand-written catch blocks
  must match this format exactly.
- Wrap in a **typed exception** (`DatabaseException`, etc.), never raw `Exception`.

### Typed exceptions

Defined in two locations:

- `lib/core/utils/exceptions.dart` — infrastructure exceptions reusable across features
  (e.g. `DatabaseException`, `NetworkException`). Both extend `Exception`.
- `lib/features/{feature}/domain/exceptions/{feature}_exceptions.dart` — domain-specific
  exceptions (e.g. `MarketNotFoundException`). Pure Dart only. Created manually
  (pre-approved, see mason.md).

Feature-specific exceptions should only be created when the domain logic meaningfully
distinguishes that error case — do not create them speculatively.

---

## 3. Floor Schema Migration Policy

After ANY `@Entity` addition, field change, or DAO query change that alters the schema:

1. Increment `version` in `@Database(version: N)` in `app_database.dart`.
2. Write a `Migration(from: N, to: N+1)` OR document that `destroyOnOpen()` is acceptable
   for dev.
3. Delete the dev database to force recreation:
   ```bash
   rm .dart_tool/sqflite_common_ffi/databases/volta_gestionale.db
   ```
4. Launch the app (`flutter run -d linux`) and navigate to every affected feature. Verify no
   errors appear — in the UI, in the console, or in the Flutter error overlay.

**Tests cannot catch this:** they mock the datasource layer and never open the real SQLite
file. "All tests green" does NOT mean the feature works. The app run in step 4 is mandatory
before declaring done.

---

## 4. Floor / Desktop Setup

- **Desktop DB init:** `sqfliteFfiInit()` (from `sqflite_common_ffi`) must be called before
  `$FloorAppDatabase.databaseBuilder(...)` in `initGlobalProviders()`. Already wired; do not
  remove.
- Entity and DAO registration in `app_database.dart` is handled automatically by the mason
  brick hooks. Do not edit manually unless the brick missed something.

---

## 5. Models / `.g.dart`

- After adding or changing Floor (`@Entity`, `@dao`) or JSON (`@JsonSerializable`)
  annotations, regenerate:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```
- **Never** format `.g.dart` files. See mason.md §3.
- Never stage or commit a `.g.dart` diff that contains only formatting changes.

### Model ↔ entity mapping (Zero Tolerance)

A `Model` **does not `extends` the domain entity.** It is a standalone class that declares
its own columns and maps to/from the entity with explicit `fromEntity` / `toEntity`:

- Identity is **DB-owned**: the model's id field is
  `@PrimaryKey(autoGenerate: true) final int? id;` and `@Entity(tableName: '...')` carries
  **no** `primaryKeys:` list (`autoGenerate` is field-level only — the class-level list has
  no autoGenerate flag).
- The domain entity's `id` is `int?` (`null` = not yet persisted).
- The datasource maps both directions: `Model.fromEntity(entity)` on write,
  `model.toEntity()` on read. It never returns the model up as if it were the entity.

```dart
// ✅ correct — data/models/customer_model.dart
@Entity(tableName: 'customers')
@JsonSerializable()
class CustomerModel {
  @PrimaryKey(autoGenerate: true)
  final int? id;
  // ... own field for every column ...
  const CustomerModel({required this.id, /* ... */});

  factory CustomerModel.fromEntity(Customer e) => CustomerModel(id: e.id, /* ... */);
  Customer toEntity() => Customer(id: id, /* ... */);
}
```

Why not `extends Customer`? The id field needs `@PrimaryKey(autoGenerate: true)`, but the id
lives on the pure-Dart entity where Floor annotations are banned (`layers.md §2`). The model
must own its own annotated field — hence the decoupling. The `new_entity` brick emits this
pattern.

`@insert` returns `Future<int>` (the generated rowid); `LocalDatasource.create` returns
`Future<int>`, `Repository.create` returns `DataState<int>`.

---

## 6. DI Wiring (data layer providers)

```
ProxyProvider<AppDatabase, XLocalDatasource>           [data/datasources/local/di/]
ProxyProvider<XLocalDatasource, XRepository>           [data/repositories/di/]
ProxyProvider<XRepository, GetAllXUseCase>             (one per usecase)
```

- `{entity}Providers()` in `data/repositories/di/{entity}_repository_providers.dart` chains
  datasource + repository + all usecases.
- `feature_complete` / `new_repository` Mason bricks generate the full chain.
- Standalone `new_usecase` / `new_usecase_with_request` do **NOT** register the
  `ProxyProvider`. Agent must manually append it to `{entity}_repository_providers.dart`.
  Verify with `analyzeFiles` after.

See `architecture.md §3` for the full DI flow diagram.
