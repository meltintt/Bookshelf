import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di.dart';
import '../../domain/models/book.dart';

class BookDetailPage extends ConsumerWidget {
  const BookDetailPage({super.key, required this.summary});

  final BookSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(booksRepositoryProvider);
    final favoriteAsync = ref.watch(favoritesProvider);
    final favoriteIds = favoriteAsync.valueOrNull?.map((book) => book.id).toSet() ?? <String>{};
    final isFav = favoriteIds.contains(summary.id);

    return FutureBuilder<BookDetail>(
      future: repository.getBookDetail(summary.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Loading...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Book details')),
            body: Center(child: Text('Could not load details: ${snapshot.error}')),
          );
        }

        final detail = snapshot.data ?? BookDetail(
          id: summary.id,
          title: summary.title,
          authors: [summary.author],
          firstPublicationYear: summary.firstPublicationYear,
          subjects: const [],
          description: null,
          coverUrl: summary.coverUrl,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(detail.title),
            actions: [
              IconButton(
                tooltip: isFav ? 'Remove favourite' : 'Add favourite',
                onPressed: () async {
                  await repository.toggleFavorite(summary);
                  ref.invalidate(favoritesProvider);
                },
                icon: Icon(isFav ? Icons.bookmark : Icons.bookmark_border),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (detail.coverUrl != null)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        detail.coverUrl!,
                        height: 220,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.book_outlined, size: 90),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  detail.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  detail.authors.join(', '),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (detail.firstPublicationYear != null)
                  Text('First publication year: ${detail.firstPublicationYear}'),
                const SizedBox(height: 16),
                if (detail.subjects.isNotEmpty) ...[
                  Text('Subjects', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: detail.subjects.map((subject) => Chip(label: Text(subject))).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  detail.description ?? 'No description available.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
