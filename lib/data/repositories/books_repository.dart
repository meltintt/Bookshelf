import 'dart:io';

import '../datasources/books_remote_data_source.dart';
import '../local/favorites_database.dart'; 
import '../local/search_cache_store.dart';
import '../../domain/models/book.dart';

abstract class BooksRepository {
  Future<List<BookSummary>> getFavoriteBooks();
  Future<void> toggleFavorite(BookSummary book);
  Future<bool> isFavorite(String id);
  Future<BookDetail> getBookDetail(String workId);
  Future<SearchResultsState> search(String query, {required int page});
}

class OpenLibraryBooksRepository implements BooksRepository {
  OpenLibraryBooksRepository({
    required this.dataSource,
    required this.favoritesDatabase,
    required this.cacheStore,
  });

  final BooksRemoteDataSource dataSource;
  final FavoritesDatabase favoritesDatabase;
  final SearchCacheStore cacheStore;

  @override
  Future<List<BookSummary>> getFavoriteBooks() async {
    return favoritesDatabase.getFavorites();
  }

  @override
  Future<void> toggleFavorite(BookSummary book) async {
    final alreadyFavorite = await favoritesDatabase.isFavorite(book.id);
    if (alreadyFavorite) {
      await favoritesDatabase.removeFavorite(book.id);
    } else {
      await favoritesDatabase.addFavorite(book);
    }
  }

  @override
  Future<bool> isFavorite(String id) async {
    return favoritesDatabase.isFavorite(id);
  }

  @override
  Future<BookDetail> getBookDetail(String workId) async {
    final payload = await dataSource.getWork(workId);
    return BookDetail.fromJson(payload);
  }

  @override
  Future<SearchResultsState> search(String query, {required int page}) async {
    final searchTerm = query.trim();
    if (searchTerm.isEmpty) {
      return const SearchResultsState(
        status: SearchStatus.empty,
        query: '',
        books: [],
      );
    }

    try {
      final response = await dataSource.search(searchTerm, page: page);
      final books = response.docs
          .map((entry) => BookSummary.fromJson(entry))
          .where((book) => book.id.isNotEmpty)
          .toList();

      if (page == 1) {
        await cacheStore.saveResults(searchTerm, books);
      }

      if (books.isEmpty) {
        return SearchResultsState(
          status: SearchStatus.empty,
          query: searchTerm,
          books: const [],
        );
      }

      return SearchResultsState(
        status: SearchStatus.results,
        query: searchTerm,
        books: books,
      );
    } on SocketException {
      final cachedResults = await cacheStore.getResults(searchTerm);
      return SearchResultsState(
        status: cachedResults.isNotEmpty ? SearchStatus.results : SearchStatus.error,
        query: searchTerm,
        books: cachedResults,
        offline: true,
        errorMessage: cachedResults.isEmpty
            ? 'Offline and no cached results available.'
            : 'Offline — showing cached results.',
      );
    } on HttpException catch (error) {
      final cachedResults = await cacheStore.getResults(searchTerm);
      return SearchResultsState(
        status: cachedResults.isNotEmpty ? SearchStatus.results : SearchStatus.error,
        query: searchTerm,
        books: cachedResults,
        offline: true,
        errorMessage: cachedResults.isNotEmpty
            ? 'Offline — showing cached results.'
            : error.message,
      );
    } on FormatException catch (error) {
      return SearchResultsState(
        status: SearchStatus.error,
        query: searchTerm,
        books: const [],
        errorMessage: error.message,
      );
    } catch (error) {
      return SearchResultsState(
        status: SearchStatus.error,
        query: searchTerm,
        books: const [],
        errorMessage: 'Something went wrong while searching books.',
      );
    }
  }
}
