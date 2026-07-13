# Feature Implementation Templates

Use the following User feature example as the strict template for creating new features.

# 1️⃣ EXAMPLE COMPLETE FEATURE (Template)

## Structure

```
features/users/
├── presentation/
│    ├── navigation/
│    │    ├── users_destinations.dart
│    │    └── users_route_provider.dart
│    └── users_list/
│         ├── bloc/
│         │    ├── users_list_bloc.dart
│         │    ├── users_list_event.dart
│         │    └── users_list_state.dart
│         └── ui/
│              ├── users_list_page.dart
│              └── widgets/
│                   └── user_card.dart
│
├── domain/
│    ├── entities/
│    │    └── user.dart
│    ├── repositories/
│    │    └── user_repository.dart
│    └── usecases/
│         ├── get_users_usecase/
│         │    ├── models/
│         │    │    └── get_users_params.dart
│         │    └── get_users_usecase.dart
│         └── create_user_usecase.dart
│
└── data/
     ├── dao/
     │    └── user_dao.dart
     ├── datasources/
     │    ├── local/
     │    │    ├── user_local_datasource.dart
     │    │    └── user_local_datasource_impl.dart
     │    └── remote/
     │         ├── user_remote_datasource.dart
     │         ├── user_remote_datasource_impl.dart
     │         ├── requests/
     │         │    └── get_users/
     │         │         ├── get_users_request.dart
     │         │         └── get_users_request.g.dart
     │         └── responses/
     │              └── get_users/
     │                   ├── get_users_response.dart
     │                   └── get_users_response.g.dart
     ├── models/
     │    └── user_model.dart
     └── repositories/
          └── user_repository_impl.dart
```

---

# 2️⃣ ENTITY (Domain)

```dart
class User extends Equatable {
  final int id;
  final String name;

  const User({
    required this.id,
    required this.name,
  });

  User copyWith({
    int? id,
    String? name,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  List<Object?> get props => [id, name];
}
```

---

# 3️⃣ MODEL (Data)

```dart
@JsonSerializable()
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.name,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}
```

---

# 4️⃣ DAO

```dart
import 'package:floor/floor.dart';

@dao
abstract class TaskDao {
  @Query('SELECT * FROM Task')
  Future<List<Task>> findAllTasks();

  @Query('SELECT * FROM Task WHERE id = :id')
  Future<Task?> findTaskById(int id);

  @Query('SELECT * FROM Task')
  Stream<List<Task>> findAllTasksAsStream();

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertTask(Task task);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertTasks(List<Task> tasks);

  @update
  Future<void> updateTask(Task task);

  @delete
  Future<void> deleteTask(Task task);

  @Query('DELETE FROM Task')
  Future<void> deleteAllTasks();
}
```

---

# 5️⃣ REPOSITORY (Domain)

```dart
abstract class UserRepository {
  Future<DataState<List<User>>> getUsers();
  Future<DataState<void>> createUser(User user);
}
```

---

# 6️⃣ REPOSITORY IMPL (Data)

```dart
import 'package:flutter/foundation.dart';

class UserRepositoryImpl implements UserRepository {
  final UserLocalDatasource localDatasource;

  UserRepositoryImpl({required this.localDatasource});

  @override
  Future<DataState<List<User>>> getUsers() async {
    try {
      final result = await localDatasource.getAll();
      return DataSuccess(result);
    } catch (e, s) {
      debugPrint('[UserRepositoryImpl] getUsers error: $e\n$s');
      return DataFailed(DatabaseException(e.toString()));
    }
  }

  @override
  Future<DataState<void>> createUser(User user) async {
    try {
      await localDatasource.create(UserModel(id: user.id, name: user.name));
      return const DataSuccess(null);
    } catch (e, s) {
      debugPrint('[UserRepositoryImpl] createUser error: $e\n$s');
      return DataFailed(DatabaseException(e.toString()));
    }
  }
}
```

---

# 7️⃣ USECASE

```dart
class GetUsersUseCase extends UseCaseBase<List<User>> {
  final UserRepository repository;

  GetUsersUseCase(this.repository);

  @override
  Future<DataState<List<User>>> call() {
    return repository.getUsers();
  }
}
```

---

# 8️⃣ BLOC

> Event/state naming, initial state, and field visibility all match the `new_page` brick exactly.
> See CLAUDE.md §14 for the cheat-sheet.

## Event

Event class name pattern: `{Action.Pascal}{BlocName.Pascal}Event`. The auto-fire event for a
page is `Started{BlocName.Pascal}Event` (matches the brick).

```dart
sealed class UsersListEvent extends Equatable {
  const UsersListEvent();

  @override
  List<Object?> get props => [];
}

class StartedUsersListEvent extends UsersListEvent {
  const StartedUsersListEvent();
}
```

---

## State (Sealed, Never Enum)

```dart
// ✅ correct — error carries Exception, never a pre-translated String
sealed class UsersListState extends Equatable {
  const UsersListState();

  @override
  List<Object?> get props => [];
}

class UsersListLoading extends UsersListState {}

class UsersListSuccess extends UsersListState {
  final List<User> users;

  const UsersListSuccess(this.users);

  @override
  List<Object?> get props => [users];
}

class UsersListError extends UsersListState {
  final Exception exception;

  const UsersListError(this.exception);

  @override
  List<Object?> get props => [exception];
}
```

---

## Bloc

- Inject usecases as **private underscore-prefixed** fields, assigned in the initialiser list.
- **Never inject `AppLocalizations`.** See `docs/architecture/bloc-rules.md` §1.
- Initial state = `XLoading()` when the page fires `Started…Event` on mount; otherwise `XInitial()`.

```dart
// ✅ correct — pattern-match DataState, emit Exception on failure
class UsersListBloc extends Bloc<UsersListEvent, UsersListState> {
  final GetAllUserUseCase _getAllUserUseCase;

  UsersListBloc({
    required GetAllUserUseCase getAllUserUseCase,
  })  : _getAllUserUseCase = getAllUserUseCase,
        super(UsersListLoading()) {
    on<StartedUsersListEvent>(_onStarted);
  }

  Future<void> _onStarted(
    StartedUsersListEvent event,
    Emitter<UsersListState> emit,
  ) async {
    emit(UsersListLoading());

    final result = await _getAllUserUseCase();

    if (result case DataFailed(:final exception)) {
      emit(UsersListError(exception));
      return;
    }

    emit(UsersListSuccess((result as DataSuccess).data));
  }
}
```

---

# 9️⃣ PROVIDER DI REGISTRATION

## Global providers (core/di/injection.dart)

```dart
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/app_database.dart';

Future<List<SingleChildWidget>> initGlobalProviders() async {
  sqfliteFfiInit();
  final database = await $FloorAppDatabase
      .databaseBuilder('app.db')
      .build();

  return [
    Provider<AppDatabase>.value(value: database),
  ];
}
```

## Feature datasource providers (data/datasources/local/di/)

The DAO is created inline — no separate DAO provider is registered.

```dart
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

SingleChildWidget userLocalDatasourceProvider() {
  return ProxyProvider<AppDatabase, UserLocalDatasource>(
    update: (_, db, __) => UserLocalDatasourceImpl(dao: db.userDao),
  );
}
```

## Feature repository providers (data/repositories/di/)

```dart
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

SingleChildWidget userRepositoryProvider() {
  return ProxyProvider<UserLocalDatasource, UserRepository>(
    update: (_, ds, __) => UserRepositoryImpl(localDatasource: ds),
  );
}

List<SingleChildWidget> userUseCaseProviders() {
  return [
    ProxyProvider<UserRepository, GetAllUserUseCase>(
      update: (_, repo, __) => GetAllUserUseCase(repo),
    ),
  ];
}

List<SingleChildWidget> userProviders() {
  return [
    userLocalDatasourceProvider(),
    userRepositoryProvider(),
    ...userUseCaseProviders(),
  ];
}
```

---

# 🔟 NAVIGATION

## Destinations Enum

```dart
enum UsersDestination {
  usersList('/users'),
  userDetail('/users/:id'),
  ;

  const UsersDestination(this.path);

  final String path;
}
```

## Route Provider (single page)

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/di/user_repository_providers.dart';
import '../users_list/ui/users_list_page.dart';
import 'users_destinations.dart';

RouteBase usersRouteProvider({List<RouteBase> childRoutes = const []}) {
  return GoRoute(
    path: UsersDestination.usersList.path,
    pageBuilder: (context, state) =>
        MaterialPage(
          child: MultiProvider(
            providers: userProviders(),
            child: const UsersListPage(),
          ),
        ),
    routes: [
      ...childRoutes,
    ],
  );
}
```

## Route Provider (multi-page)

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/di/user_repository_providers.dart';
import '../users_list/ui/users_list_page.dart';
import '../user_detail/ui/user_detail_page.dart';
import 'users_destinations.dart';

RouteBase usersRouteProvider({List<RouteBase> childRoutes = const []}) {
  return GoRoute(
    path: UsersDestination.usersList.path,
    pageBuilder: (context, state) =>
        MaterialPage(
          child: MultiProvider(
            providers: userProviders(),
            child: const UsersListPage(),
          ),
    ),
    routes: [
      GoRoute(
        path: ':id',
        pageBuilder: (context, state) =>
            MaterialPage(
              child: MultiProvider(
                providers: userProviders(),
                child: const UserDetailPage(),
              ),
            ),
      ),
      ...childRoutes,
    ],
  );
}
```

## Cross-feature composition in AppRouter

```dart
AppRouter
(): _router = GoRouter
(
initialLocation: UsersDestination.usersList.path,
routes: [
usersRouteProvider(
childRoutes: [
ordersRouteProvider(),
],
)
,
]
,
);
```
