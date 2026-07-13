# Mason / Code Generation Conventions

Read this **before running any `mason make` command** or touching `bricks/`.

For brick parameter schemas, see `docs/bricks.md`.

---

## 1. Mason-First Code Generation Policy (Zero Tolerance)

**Core rule:** Never manually create any file that a Mason brick can generate. If the desired
artifact maps to one of the bricks listed below, the brick **must** be used. No exceptions.

### Covered bricks

| Brick                      | Use when creating…                                                                 |
|----------------------------|------------------------------------------------------------------------------------|
| `feature_complete`         | A brand-new feature (entity + repo + pages + BLoCs)                                |
| `new_repository`           | A new entity + repository in an existing feature                                   |
| `new_entity`               | Only the entity, Floor model, and DAO                                              |
| `new_page`                 | A new page + BLoC in an existing feature (BLoC delegated to `new_bloc`)            |
| `new_bloc`                 | A standalone BLoC (bloc + event + state) in an existing feature, no page           |
| `new_usecase`              | A no-parameter usecase                                                             |
| `new_usecase_with_request` | A parameterised usecase (has request object)                                       |
| `new_usecase_test`         | A unit test for a usecase (auto-chained by `new_repository`, also standalone)      |
| `new_bloc_test`            | A bloc_test for a BLoC (auto-chained by `new_page`, also standalone)               |
| `new_repository_test`      | A unit test for RepositoryImpl (auto-chained by `new_repository`, also standalone) |
| `sync_app_images`          | Regenerate `lib/theme/token/light_app_images.dart` from the `assets/` folder       |

---

## 2. Mandatory Workflow (strict order — do NOT skip or reorder steps)

1. **Select brick & build config** — Read `docs/bricks.md` to identify the correct brick and
   construct the JSON variables object.
2. **Write the JSON config to disk** — Use:
   ```bash
   cat > /tmp/<name>_vars.json << 'EOF'
   { ... }
   EOF
   ```
   Never call `mason make` before the file exists.
3. **Run the brick:**
   ```bash
   mason make <brick> --output-dir . --on-conflict skip --config-path /tmp/<name>_vars.json
   ```
4. **Verify generated files** — Run `find lib/features/<feature_name> -type f` and
   `find test/features/<feature_name> -type f` and confirm the expected files were created.
   If any are missing, **stop and ask the user**.
5. **Edit generated stubs** — Only now may you open the generated files and fill in business
   logic, widget trees, DAO queries, route registration, etc. DI registration in
   `injection.dart` and entity/DAO registration in `app_database.dart` are handled
   automatically by the brick hooks. For standalone `new_usecase` /
   `new_usecase_with_request`, add a `ProxyProvider` entry manually to
   `repositories/di/{entity}_repository_providers.dart`. Then, if any Floor (`@Entity`,
   `@dao`) or JSON (`@JsonSerializable`) annotations were added or changed, regenerate
   `.g.dart`:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
6. **Run tests** — `flutter test test/features/<feature_name>/` to verify scaffolded tests
   pass. If they fail, fix the generated code or tests until they pass.
7. **Write additional manual tests** — Only for edge-case business logic or non-scaffoldable
   scenarios. If the usecase was created standalone (`new_usecase` /
   `new_usecase_with_request`), manually invoke `mason make new_usecase_test` with matching
   vars.
8. **Run tests again** — `flutter test test/features/<feature_name>/`.
9. **Fix failures** — Iterate on steps 6–8 until every test is green.
10. **Confirm green** — Never report a task as done unless all tests pass
    (`flutter test` exits 0).

---

## 3. Format Safety — `bricks/` and `*.g.dart`

### ⚠️ Never run `dart format` on `bricks/`

Brick template files (`bricks/**/__brick__/**/*.dart`) embed Mustache syntax (`{{variable}}`,
`{{#section}}...{{/section}}`) directly inside `.dart` files. `dart format` treats these
files as Dart source and **will corrupt every `{{...}}` tag**, splitting `{{` into separate
lines. Mason's Mustache parser then fails silently and outputs the raw template as file
content — the generated file will contain literal `{{feature_name.snakeCase()}}` strings
instead of rendered values.

**Forbidden — will corrupt brick templates:**

```bash
dart format .
flutter format .
dart format bricks/
```

**Always scope formatting to source directories only:**

```bash
dart format lib/ test/
```

### ⚠️ Never run `dart format` on `*.g.dart` files

Generated files (`*.g.dart`) are produced by `build_runner` and must not be reformatted.
`dart format lib/ test/` will touch them if run on directories — they end up with cosmetic
diffs that add noise to commits and obscure real changes.

**After running `dart format`, revert any `.g.dart` changes:**

```bash
git restore '*.g.dart'
# or target a specific file
git restore lib/features/<feature>/data/models/<entity>_model.g.dart
```

Never stage or commit a `.g.dart` diff that contains only formatting changes. Re-run
`build_runner` if the file actually needs updating.

### IDE auto-format on save

`bricks/**` is excluded in `analysis_options.yaml`, which prevents the Dart analyser from
indexing those files and causes most JetBrains / VS Code configurations to skip
auto-format-on-save for them. Verify your IDE's "Format on Save" scope does not include
`bricks/`.

---

## 4. Detecting & Fixing Brick Corruption

A generated file has been corrupted if it contains literal Mustache strings like
`{{feature_name.snakeCase()}}` or `{{entity_name.pascalCase()}}` instead of rendered values
(e.g. `products`, `Product`).

**Fix:**

1. Restore every broken `{{ }}` tag back to a **single-line** form in the template file.
2. Delete the malformed generated file(s).
3. Re-run the relevant brick with `--on-conflict overwrite`.
4. Fill in any scaffolded TODO stubs and run `flutter test` until all green.

---

## 5. No Brick Exists for the Artifact

If the artifact you need is reusable / structural but no brick covers it:

1. **Stop.** Do not create the file manually.
2. **Ask the user** whether a new brick should be created first.
3. Explain what the brick would generate and why it would be useful.

The agent may only create the file manually if the user explicitly approves.

### Pre-approved manual artifacts (no brick required)

| Artifact                    | Path                                                                 | Reason                                                      |
|-----------------------------|----------------------------------------------------------------------|-------------------------------------------------------------|
| Feature-specific exceptions | `lib/features/{feature}/domain/exceptions/{feature}_exceptions.dart` | Pure Dart; feature-scoped; no structural scaffolding needed |
| Feature-scoped extensions   | `lib/features/{feature}/presentation/extensions/*.dart`              | Pure Dart; no template needed                               |
| Core-scoped extensions      | `lib/core/extensions/*.dart`                                         | Pure Dart; no template needed                               |

---

## 6. Failure Handling

If `mason make` fails for any reason:

1. **Stop.** Do not fall back to manual file creation.
2. **Report the full error** to the user.
3. **Wait for instructions** before proceeding.
