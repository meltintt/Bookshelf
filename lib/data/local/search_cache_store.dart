import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
 
import '../../domain/models/book.dart';

class SearchCacheStore {
  SearchCacheStore({Future<SharedPreferences>? sharedPreferences})
      : _sharedPreferences = sharedPreferences ?? SharedPreferences.getInstance();

  final Future<SharedPreferences> _sharedPreferences;

  static final SearchCacheStore instance = SearchCacheStore();

  Future<void> saveResults(String query, List<BookSummary> books) async {
    final prefs = await _sharedPreferences;
    final encoded = jsonEncode(books.map((book) => book.toMap()).toList());
    await prefs.setString(_cacheKey(query), encoded);
  }

  Future<List<BookSummary>> getResults(String query) async {
    final prefs = await _sharedPreferences;
    final raw = prefs.getString(_cacheKey(query));
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map>()
          .map((item) => BookSummary.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } on FormatException {
      return const [];
    }
  }

  String _cacheKey(String query) => 'cached_search_$query';
}
