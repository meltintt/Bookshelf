import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/datasources/books_remote_data_source.dart';
import '../data/local/favorites_database.dart';
import '../data/local/search_cache_store.dart';
import '../data/repositories/books_repository.dart';
import '../domain/models/book.dart';

final favoritesDatabaseProvider = Provider<FavoritesDatabase>((ref) {
  return FavoritesDatabase.instance;
});

final searchCacheStoreProvider = Provider<SearchCacheStore>((ref) {
  return SearchCacheStore.instance;
});

final booksRemoteDataSourceProvider = Provider<BooksRemoteDataSource>((ref) {
  return OpenLibraryRemoteDataSource(client: http.Client());
});

final booksRepositoryProvider = Provider<BooksRepository>((ref) {
  final dataSource = ref.watch(booksRemoteDataSourceProvider);
  final favoritesDatabase = ref.watch(favoritesDatabaseProvider);
  final cacheStore = ref.watch(searchCacheStoreProvider);

  return OpenLibraryBooksRepository(
    dataSource: dataSource,
    favoritesDatabase: favoritesDatabase,
    cacheStore: cacheStore,
  );
});

final favoritesProvider = FutureProvider<List<BookSummary>>((ref) {
  return ref.watch(booksRepositoryProvider).getFavoriteBooks();
});
