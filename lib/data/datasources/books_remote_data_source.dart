import 'dart:convert';
import 'dart:io';
 
import 'package:http/http.dart' as http;

abstract class BooksRemoteDataSource {
  Future<SearchResponse> search(String query, {required int page});
  Future<Map<String, dynamic>> getWork(String workId);
}

class SearchResponse {
  const SearchResponse({required this.numFound, required this.docs});

  final int numFound;
  final List<Map<String, dynamic>> docs;
}

class OpenLibraryRemoteDataSource implements BooksRemoteDataSource {
  OpenLibraryRemoteDataSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<SearchResponse> search(String query, {required int page}) async {
    final searchTerm = query.trim();
    if (searchTerm.isEmpty) {
      return const SearchResponse(numFound: 0, docs: []);
    }

    final uri = Uri.parse(
      'https://openlibrary.org/search.json?q=${Uri.encodeQueryComponent(searchTerm)}&page=$page',
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw HttpException('Open Library request failed (${response.statusCode})');
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Unexpected JSON payload from Open Library');
      }

      final docs = <Map<String, dynamic>>[];
      final rawDocs = decoded['docs'];
      if (rawDocs is List) {
        for (final item in rawDocs) {
          if (item is Map) {
            docs.add(Map<String, dynamic>.from(item));
          }
        }
      }

      final numFound = decoded['numFound'];
      return SearchResponse(
        numFound: numFound is num ? numFound.toInt() : 0,
        docs: docs,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Malformed Open Library search response');
    }
  }

  @override
  Future<Map<String, dynamic>> getWork(String workId) async {
    final uri = Uri.parse('https://openlibrary.org/works/$workId.json');
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw HttpException('Open Library work lookup failed (${response.statusCode})');
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Unexpected work JSON payload');
      }
      return decoded;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Malformed Open Library work response');
    }
  }
}
