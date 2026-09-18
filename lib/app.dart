import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di.dart';
import 'presentation/favorites/favorites_page.dart';
import 'presentation/search/search_page.dart';
 
class BookshelfApp extends StatelessWidget {
  const BookshelfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bookshelf',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      home: const BookshelfShell(),
    );
  }
}

class BookshelfShell extends ConsumerStatefulWidget {
  const BookshelfShell({super.key});

  @override
  ConsumerState<BookshelfShell> createState() => _BookshelfShellState();
}

class _BookshelfShellState extends ConsumerState<BookshelfShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    ref.read(favoritesProvider);

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          SearchPage(),
          FavoritesPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) => setState(() => _selectedIndex = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.bookmark), label: 'Favourites'),
        ],
      ),
    );
  }
}
