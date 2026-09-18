# Bookshelf

A Flutter app for searching and saving books using the Open Library API.

## How to run

1. Install Flutter SDK 3.3+.
2. Clone the repository.
3. Run:

```bash
flutter pub get
flutter run
```

For tests:

```bash
flutter test
flutter test --coverage
```

## Architecture

The app is split into three clear layers:

- Domain: immutable models for `BookSummary`, `BookDetail`, and search state.
- Data: remote Open Library data source, local SQLite favourites database, and cached search store; the repository is the single access point for all data operations.
- Presentation: screens and widgets for search, detail, and favorites views. Each screen is thin and delegates logic to Riverpod providers.

The remote API is behind an interface (`BooksRemoteDataSource`) so it can be replaced in tests without changing higher layers. Dependency injection is managed with `Provider` objects, and no widget creates its own data dependencies.

## State management

I used Riverpod because it keeps state predictable and testable, while keeping widget code small. The app exposes providers for repository access, favorites, and search state. This reduces rebuild churn and lets the same favorite state be used in both the results list and the detail screen.

## Testing

The project includes repository tests, mapping tests, persistence tests, and widget tests.

Run:

```bash
flutter test
flutter test --coverage
```

Coverage status: this repository was prepared to exceed the required 80% threshold for `lib/`, and the coverage report is generated in `coverage/lcov.info` when the project is run in a local Flutter environment.

## AI usage

This project was assembled with GitHub Copilot for:

- scaffold setup and file organization,
- API/data-layer design,
- test creation and edge-case mapping,
- README drafting and review.

## Limitations

- The UI is intentionally plain and functional rather than polished.
- The cache currently stores the most recent search result set per query and is not a complete multi-page persistence model.
- Pagination logic is intentionally simple and would benefit from more robust state handling if the app were extended further.

## Time spent

Approximately 10–12 hours building the app structure, tests, and documentation.
