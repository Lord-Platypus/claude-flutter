# Presentation — Navigation

Split out of `presentation.md` (which stays the index of presentation-layer rules). Read this
**before editing any route, destinations enum, or `go_router` wiring** under
`lib/features/*/presentation/navigation/` or `lib/core/navigation/`. Section number kept stable
(§4) so existing cross-references resolve.

Companion documents:
- `docs/conventions/presentation.md` — strings, no-logic-in-UI, BLoC rules (§1–§3)
- `docs/conventions/presentation-design-system.md` — `App*` widgets, theme, file size (§5–§12)

---

## 4. Navigation (Zero Tolerance — `pushNamed`, never `.replaceFirst`)

### Every page renders inside the dashboard shell (sidebar always visible) — Zero Tolerance

There is exactly **one** top-level route: `dashboardRouteProvider()` (a
`StatefulShellRoute.indexedStack`). Every feature is one **branch** of that shell, so the
sidebar (`SidebarNavigation`) is always visible and the active feature renders in the content
area — exactly like the customers (Venditori) list. **Never** register a feature route at the
top level of `AppRouter`; that renders the page full-screen with no sidebar.

```dart
// ✅ correct — lib/features/dashboard/presentation/navigation/dashboard_route_provider.dart
// Branch order MUST match DashboardDestination.values (the sidebar maps index → branch).
RouteBase dashboardRouteProvider() {
  return StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) =>
        DashboardShellPage(navigationShell: navigationShell),
    branches: [
      StatefulShellBranch(routes: [cashRegisterRouteProvider()]),
      StatefulShellBranch(routes: [consignmentsRouteProvider()]),
      StatefulShellBranch(routes: [itemsRouteProvider()]),
      StatefulShellBranch(routes: [customersRouteProvider()]),
      StatefulShellBranch(routes: [salesRouteProvider()]),
      StatefulShellBranch(routes: [businessRegisterRouteProvider()]),
      StatefulShellBranch(routes: [settingsRouteProvider()]),
    ],
  );
}

// lib/core/navigation/router.dart — the ONLY top-level route is the shell.
GoRouter(
  initialLocation: DashboardDestination.cashRegister.path,
  routes: [dashboardRouteProvider()],
);
```

```dart
// ❌ wrong — feature route at the top level: renders with NO sidebar
GoRouter(
  routes: [
    dashboardRouteProvider(),
    itemsRouteProvider(),        // ← full-screen, sidebar gone
    consignmentsRouteProvider(), // ←
  ],
);

// ❌ wrong — branch builds a one-off page instead of the feature's route provider
StatefulShellBranch(routes: [
  GoRoute(path: '/items', builder: (c, s) => const PlaceholderPage(title: '...')),
]),
```

Rules that follow from this:
- **Sub-pages stay inside their branch.** Detail / edit / intake pages are **child routes**
  (`routes:`) of the feature's root route, reached via `pushNamed`. Pushing a child route stays
  on the branch's navigator, so the sidebar persists (e.g. consignments `load-products` and
  `new-seller` nest under `select-seller`; customers `:id` and `edit` nest under the list).
- **`DashboardDestination.path` must equal the branch's root route path** (e.g. `products` →
  `'/items'`, `vendors` → `'/customers'`). The sidebar selects branches by **index**
  (`navigationShell.goBranch(index)`), but the path drives `initialLocation` and active-branch
  detection, so keep them in sync.
- Adding a feature = add a `DashboardDestination` enum value **and** a branch at the matching
  index. Do not add it anywhere else.

### Destinations enum carries `path`, `name`, and `segment`

The `path` is the **absolute** route (used for `initialLocation` and any param-less external
reference). The `segment` getter derives the **relative** segment for nested `GoRoute`
children — `go_router` joins parent + child internally and rejects absolute child paths.

```dart
// ✅ correct — lib/features/customers/presentation/navigation/customers_destinations.dart
enum CustomersDestination {
  customersList('/customers', 'customersList'),
  customerNew('/customers/new', 'customerNew'),
  customerDetail('/customers/:id', 'customerDetail'),
  customerEdit('/customers/:id/edit', 'customerEdit');

  const CustomersDestination(this.path, this.name);
  final String path;
  final String name;

  String get segment => path.split('/').last;
}
```

- `customersList.path` → `'/customers'` (absolute, top-level).
- `customerNew.segment` → `'new'` (relative, nests under `/customers`).
- `customerDetail.segment` → `':id'`.
- `customerEdit.segment` → `'edit'` (nests under `:id`).

### `GoRoute` uses `.segment` for child routes, `.path` for the root

```dart
// ✅ correct
GoRoute(
  path: CustomersDestination.customersList.path,       // absolute, root
  name: CustomersDestination.customersList.name,
  routes: [
    GoRoute(
      path: CustomersDestination.customerNew.segment,  // 'new' — relative
      name: CustomersDestination.customerNew.name,
      // ...
    ),
    GoRoute(
      path: CustomersDestination.customerDetail.segment,  // ':id' — relative
      name: CustomersDestination.customerDetail.name,
      pageBuilder: (context, state) => MaterialPage(
        child: MultiProvider(
          providers: customerProviders(),
          child: CustomerDetailPage(
            customerId: int.parse(state.pathParameters['id']!),
          ),
        ),
      ),
      routes: [
        GoRoute(
          path: CustomersDestination.customerEdit.segment,  // 'edit'
          name: CustomersDestination.customerEdit.name,
          // ...
        ),
      ],
    ),
  ],
)
```

```dart
// ❌ wrong — hardcoded relative string, drifts from enum
GoRoute(path: 'new', name: CustomersDestination.customerNew.name, ...)

// ❌ wrong — absolute path on a child route; go_router will either error or double-prefix
GoRoute(path: CustomersDestination.customerNew.path, ...)
```

### Navigation with parameters uses `pushNamed` / `goNamed`

```dart
// ✅ GOOD
context.pushNamed(
  CustomersDestination.customerDetail.name,
  pathParameters: {'id': customer.id.toString()},
);

// ❌ BAD — hardcoded string
context.push('/customers/${customer.id}');

// ❌ BAD — brittle hack
context.push(
  CustomersDestination.customerDetail.path.replaceFirst(':id', customer.id.toString()),
);
```

`initialLocation` and any param-less reference still uses `.path`:

```dart
initialLocation: DashboardDestination.cashRegister.path
```

### Route provider shape

- Top-level function returning `RouteBase` — never a class.
- Routes use `pageBuilder:` wrapping pages with
  `MaterialPage(child: MultiProvider(providers: {entity}Providers(), child: Page()))`.
- BLoCs **never** injected at the route level — they stay in page widgets.
- Path params from `go_router` arrive as `String`. **Parse at the `pageBuilder` boundary** and
  pass the typed result to the page constructor. The page itself must accept the typed value
  (`int`, `int?`, etc.), never a raw `String` path parameter.

### "New" vs "Edit" — typed nullable, never sentinel strings (Zero Tolerance)

The page **never** knows the create-vs-edit decision via a magic string.

- Route enum exposes two paths: `/{feature}/new` and `/{feature}/:id/edit`.
- The edit page accepts **`int? customerId`** (nullable). `null` means create-mode.
- The route's `pageBuilder` does the conversion **once**:

```dart
GoRoute(
  path: 'new',
  name: CustomersDestination.customerNew.name,
  pageBuilder: (ctx, state) => MaterialPage(
    child: MultiProvider(
      providers: customerProviders(),
      child: const CustomerEditPage(customerId: null),   // ✅ null = create
    ),
  ),
),
GoRoute(
  path: ':id/edit',
  name: CustomersDestination.customerEdit.name,
  pageBuilder: (ctx, state) => MaterialPage(
    child: MultiProvider(
      providers: customerProviders(),
      child: CustomerEditPage(
        customerId: int.parse(state.pathParameters['id']!),
      ),
    ),
  ),
),
```

- BLoC owns the mode decision:
  ```dart
  class CustomerEditBloc extends Bloc<...> {
    final int? _customerId;
    bool get _isNew => _customerId == null;
  }
  ```
- The UI gets all mode-dependent labels/behaviour from BLoC state.

**Forbidden patterns:**

```dart
// ❌ sentinel string + UI branching
final String customerId;
final isNew = widget.customerId == 'new';

// ❌ page parses path parameter itself
id: widget.customerId == 'new' ? 0 : int.parse(widget.customerId),

// ❌ alternative sentinels like -1 or "" are equally wrong
final customerId = id == -1 ? null : id;
```
