import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key}); 

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Favourites')),
      body: favoritesAsync.when(
        data: (books) {
          if (books.isEmpty) {
            return const Center(child: Text('No favourites yet.'));
          }

          return ListView.builder(
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return ListTile(
                leading: book.coverUrl == null
                    ? const Icon(Icons.book_outlined)
                    : Image.network(
                        book.coverUrl!,
                        width: 42,
                        height: 42,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.book_outlined),
                      ),
                title: Text(book.title),
                subtitle: Text(book.author),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await ref.read(booksRepositoryProvider).toggleFavorite(book);
                    ref.invalidate(favoritesProvider);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Could not load favourites: $error')),
      );
    );
  }
}
