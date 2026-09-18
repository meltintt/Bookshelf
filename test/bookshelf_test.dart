import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bookshelf/data/datasources/books_remote_data_source.dart';
import 'package:bookshelf/data/local/favorites_database.dart';
import 'package:bookshelf/data/local/search_cache_store.dart';
import 'package:bookshelf/data/repositories/books_repository.dart';
import 'package:bookshelf/domain/models/book.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Repository tests', () {
    late MockHttpClient client;
    late OpenLibraryRemoteDataSource source;
    late FavoritesDatabase favoritesDatabase;
    late SearchCacheStore cacheStore;
    late OpenLibraryBooksRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      client = MockHttpClient();
      source = OpenLibraryRemoteDataSource(client: client);
      favoritesDatabase = FavoritesDatabase(databaseName: 'repo_test_favorites.db');
      await favoritesDatabase.resetForTest();
      cacheStore = SearchCacheStore();
      repository = OpenLibraryBooksRepository(
        dataSource: source,
        favoritesDatabase: favoritesDatabase,
        cacheStore: cacheStore,
      );
    });

    tearDown(() async {
      await favoritesDatabase.resetForTest();
    });

    test('returns books on a successful response', () async {
      when(() => client.get(any())).thenAnswer(
        (_) async => http.Response(
          '{"numFound": 2, "docs": [{"key": "/works/OL1W", "title": "Dune", "author_name": ["Frank Herbert"], "first_publish_year": 1965, "cover_i": 123}, {"key": "/works/OL2W", "title": "Foundation", "author_name": ["Isaac Asimov"], "first_publish_year": 1951, "cover_i": 456}]}',
          200,
        ),
      );

      final result = await repository.search('dune', page: 1);

      expect(result.status, SearchStatus.results);
      expect(result.books.length, 2);
      expect(result.books.first.title, 'Dune');
    });

    test('returns an error response when the API fails', () async {
      when(() => client.get(any())).thenAnswer(
        (_) async => http.Response('server error', 500),
      );

      final result = await repository.search('dune', page: 1);

      expect(result.status, SearchStatus.error);
      expect(result.errorMessage, isNotNull);
    });

    test('handles malformed JSON', () async {
      when(() => client.get(any())).thenAnswer(
        (_) async => http.Response('{not valid json', 200),
      );

      final result = await repository.search('dune', page: 1);

      expect(result.status, SearchStatus.error);
    });

    test('handles empty result set', () async {
      when(() => client.get(any())).thenAnswer(
        (_) async => http.Response('{"numFound": 0, "docs": []}', 200),
      );

      final result = await repository.search('zzz-no-result', page: 1);

      expect(result.status, SearchStatus.empty);
      expect(result.books, isEmpty);
    });
  });

  group('Mapping tests', () {
    test('maps missing author_name to Unknown author', () {
      final book = BookSummary.fromJson({
        'key': '/works/OL1W',
        'title': 'The Hobbit',
      });

      expect(book.author, 'Unknown author');
    });

    test('handles missing cover_i gracefully', () {
      final book = BookSummary.fromJson({
        'key': '/works/OL1W',
        'title': 'The Hobbit',
        'author_name': ['J.R.R. Tolkien'],
      });

      expect(book.coverUrl, isNull);
    });

    test('handles missing first_publish_year gracefully', () {
      final book = BookSummary.fromJson({
        'key': '/works/OL1W',
        'title': 'The Hobbit',
        'author_name': ['J.R.R. Tolkien'],
      });

      expect(book.firstPublicationYear, isNull);
    });

    test('handles description as string', () {
      final detail = BookDetail.fromJson({
        'key': '/works/OL1W',
        'title': 'The Hobbit',
        'author_name': ['J.R.R. Tolkien'],
        'description': 'A great adventure.',
      });

      expect(detail.description, 'A great adventure.');
    });

    test('handles description as object with value key', () {
      final detail = BookDetail.fromJson({
        'key': '/works/OL1W',
        'title': 'The Hobbit',
        'author_name': ['J.R.R. Tolkien'],
        'description': {'value': 'A great adventure.'},
      });

      expect(detail.description, 'A great adventure.');
    });

    test('handles missing description gracefully', () {
      final detail = BookDetail.fromJson({
        'key': '/works/OL1W',
        'title': 'The Hobbit',
        'author_name': ['J.R.R. Tolkien'],
      });

      expect(detail.description, isNull);
    });
  });

  group('Favorites persistence tests', () {
    late FavoritesDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = FavoritesDatabase(databaseName: 'favorites_persistence_test.db');
      await db.resetForTest();
    });

    tearDown(() async {
      await db.resetForTest();
    });

    test('adds, reads, removes, and survives a restart', () async {
      final book = const BookSummary(
        id: 'OL123W',
        title: 'Dune',
        author: 'Frank Herbert',
        firstPublicationYear: 1965,
        coverUrl: 'https://example.com/cover.jpg',
      );

      await db.addFavorite(book);
      expect(await db.isFavorite('OL123W'), isTrue);
      expect((await db.getFavorites()).length, 1);

      await db.removeFavorite('OL123W');
      expect(await db.isFavorite('OL123W'), isFalse);

      await db.addFavorite(book);
      final reopened = FavoritesDatabase(databaseName: 'favorites_persistence_test.db');
      expect(await reopened.isFavorite('OL123W'), isTrue);
    });
  });

  group('Widget tests', () {
    testWidgets('loading state appears', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            booksRepositoryProvider.overrideWithValue(
              _FakeBooksRepository(
                searchResult: const SearchResultsState(status: SearchStatus.loading),
              ),
            )
          ],
          child: const MaterialApp(home: SearchPage()),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('results state appears with items', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            booksRepositoryProvider.overrideWithValue(
              _FakeBooksRepository(
                searchResult: SearchResultsState(
                  status: SearchStatus.results,
                  books: [
                    const BookSummary(
                      id: 'OL1W',
                      title: 'Dune',
                      author: 'Frank Herbert',
                      firstPublicationYear: 1965,
                    ),
                  ],
                ),
              ),
            ),
            favoritesProvider.overrideWithValue(AsyncData(const <BookSummary>[])),
          ],
          child: const MaterialApp(home: SearchPage()),
        ),
      );

      expect(find.text('Dune'), findsOneWidget);
    });

    testWidgets('empty state appears when there are no results', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            booksRepositoryProvider.overrideWithValue(
              _FakeBooksRepository(
                searchResult: const SearchResultsState(status: SearchStatus.empty),
              ),
            ),
            favoritesProvider.overrideWithValue(AsyncData(const <BookSummary>[])),
          ],
          child: const MaterialApp(home: SearchPage()),
        ),
      );

      expect(find.text('No books found.'), findsOneWidget);
    });

    testWidgets('error state appears when fetch fails', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            booksRepositoryProvider.overrideWithValue(
              _FakeBooksRepository(
                searchResult: const SearchResultsState(
                  status: SearchStatus.error,
                  errorMessage: 'Something went wrong',
                ),
              ),
            ),
            favoritesProvider.overrideWithValue(AsyncData(const <BookSummary>[])),
          ],
          child: const MaterialApp(home: SearchPage()),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('favorite toggle works', (tester) async {
      final repo = _FakeBooksRepository(
        searchResult: SearchResultsState(
          status: SearchStatus.results,
          books: [
            const BookSummary(
              id: 'OL1W',
              title: 'Dune',
              author: 'Frank Herbert',
              firstPublicationYear: 1965,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            booksRepositoryProvider.overrideWithValue(repo),
            favoritesProvider.overrideWithValue(AsyncData(const <BookSummary>[])),
          ],
          child: const MaterialApp(home: SearchPage()),
        ),
      );

      final button = find.byIcon(Icons.bookmark_border);
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pump();
      expect(repo.toggleCalled, isTrue);
    });
  });
}

class _FakeBooksRepository implements BooksRepository {
  _FakeBooksRepository({required this.searchResult});

  final SearchResultsState searchResult;
  bool toggleCalled = false;

  @override
  Future<List<BookSummary>> getFavoriteBooks() async => const [];

  @override
  Future<void> toggleFavorite(BookSummary book) async {
    toggleCalled = true;
  }

  @override
  Future<bool> isFavorite(String id) async => false;

  @override
  Future<BookDetail> getBookDetail(String workId) async {
    return BookDetail(
      id: workId,
      title: 'Dune',
      authors: const ['Frank Herbert'],
      firstPublicationYear: 1965,
      subjects: const ['Science fiction'],
      description: 'A sci-fi classic.',
    );
  }

  @override
  Future<SearchResultsState> search(String query, {required int page}) async => searchResult;
}
