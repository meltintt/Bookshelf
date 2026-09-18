import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 

import '../../core/di.dart';
import '../../data/repositories/books_repository.dart';
import '../../domain/models/book.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favouritesAsync = ref.watch(favoritesProvider);
    final searchState = ref.watch(searchControllerProvider);
    final repository = ref.watch(booksRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Books'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Search by title, author or keyword',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  ref.read(searchControllerProvider.notifier).search(value);
                });
              },
            ),
          ),
          Expanded(
            child: _buildContent(
              repository: repository,
              favouritesAsync: favouritesAsync,
              searchState: searchState,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent({
    required BooksRepository repository,
    required AsyncValue<List<BookSummary>> favouritesAsync,
    required SearchResultsState searchState,
  }) {
    if (searchState.status == SearchStatus.loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (searchState.status == SearchStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            searchState.errorMessage ?? 'Something went wrong.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (searchState.status == SearchStatus.empty) {
      return const Center(
        child: Text('No books found.'),
      );
    }

    if (searchState.status == SearchStatus.results) {
      final favouriteIds = <String>{
        ...favouritesAsync.valueOrNull?.map((book) => book.id) ?? const []
      };

      return NotificationListener<ScrollEndNotification>(
        onNotification: (notification) {
          final scroll = notification.metrics;
          final trigger = scroll.extentAfter < 200;
          if (trigger && _controller.text.trim().isNotEmpty) {
            ref.read(searchControllerProvider.notifier).loadNextPage();
          }
          return false;
        },
        child: ListView.separated(
          itemCount: searchState.books.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, index) {
            final book = searchState.books[index];
            final isFavorite = favouriteIds.contains(book.id);

            return ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: SizedBox(
                width: 48,
                child: book.coverUrl == null
                    ? const Icon(Icons.book_outlined)
                    : Image.network(
                        book.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.book_outlined),
                      ),
              ),
              title: Text(book.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.author),
                  if (book.firstPublicationYear != null)
                    Text('First published: ${book.firstPublicationYear}'),
                ],
              ),
              trailing: IconButton(
                tooltip: isFavorite ? 'Remove favourite' : 'Add favourite',
                onPressed: () async {
                  await repository.toggleFavorite(book);
                  ref.invalidate(favoritesProvider);
                },
                icon: Icon(isFavorite ? Icons.bookmark : Icons.bookmark_border),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BookDetailPage(summary: book),
                  ),
                );
              },
            );
          },
        ),
      );
    }

    if (searchState.offline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(searchState.errorMessage ?? 'Offline'),
        ),
      );
    }

    return const Center(
      child: Text('Search for a book to begin.'),
    );
  }
}

final searchControllerProvider =
    StateNotifierProvider<SearchController, SearchResultsState>((ref) {
  final repository = ref.watch(booksRepositoryProvider);
  return SearchController(repository);
});

class SearchController extends StateNotifier<SearchResultsState> {
  SearchController(this._repository) : super(const SearchResultsState());

  final BooksRepository _repository;
  int _page = 1;

  Future<void> search(String query) async {
    final trimmed = query.trim();
    _page = 1;

    if (trimmed.isEmpty) {
      state = const SearchResultsState(
        status: SearchStatus.empty,
        query: '',
        books: [],
      );
      return;
    }

    state = state.copyWith(
      status: SearchStatus.loading,
      query: trimmed,
      errorMessage: null,
    );

    final result = await _repository.search(trimmed, page: _page);
    state = result.copyWith(
      status: result.status,
      query: trimmed,
      offline: result.offline,
      errorMessage: result.errorMessage,
      books: result.books,
    );
  }

  Future<void> loadNextPage() async {
    if (state.query.isEmpty) {
      return;
    }

    _page += 1;
    final result = await _repository.search(state.query, page: _page);
    final currentBooks = [...state.books, ...result.books];
    state = state.copyWith(
      status: SearchStatus.results,
      books: currentBooks,
      offline: result.offline,
      errorMessage: result.errorMessage,
    );
  }
}
