import 'package:flutter/foundation.dart';

@immutable
class BookSummary {
  const BookSummary({
    required this.id,
    required this.title,
    required this.author,
    this.firstPublicationYear,
    this.coverUrl,
  });

  final String id;
  final String title;
  final String author;
  final int? firstPublicationYear;
  final String? coverUrl;

  factory BookSummary.fromJson(Map<String, dynamic> json) {
    final titleValue = json['title'];
    final title = titleValue is String && titleValue.trim().isNotEmpty
        ? titleValue
        : 'Untitled';

    final authorNames = json['author_name'];
    String author = 'Unknown author';
    if (authorNames is List) {
      final names = authorNames
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .toList();
      if (names.isNotEmpty) {
        author = names.join(', ');
      }
    }

    int? year;
    final rawYear = json['first_publish_year'];
    if (rawYear is int) {
      year = rawYear;
    } else if (rawYear is String) {
      year = int.tryParse(rawYear);
    }

    String? coverUrl;
    final coverId = json['cover_i'];
    if (coverId != null) {
      coverUrl = 'https://covers.openlibrary.org/b/id/$coverId-M.jpg';
    }

    final workKey = json['key'];
    String id = '';
    if (workKey is String) {
      id = workKey.split('/').last;
    }

    return BookSummary(
      id: id,
      title: title,
      author: author,
      firstPublicationYear: year,
      coverUrl: coverUrl,
    );
  }

  factory BookSummary.fromMap(Map<String, dynamic> map) {
    return BookSummary(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Untitled',
      author: map['author'] as String? ?? 'Unknown author',
      firstPublicationYear: map['firstPublicationYear'] as int?,
      coverUrl: map['coverUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'firstPublicationYear': firstPublicationYear,
      'coverUrl': coverUrl,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  BookSummary copyWith({
    String? id,
    String? title,
    String? author,
    int? firstPublicationYear,
    String? coverUrl,
  }) {
    return BookSummary(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      firstPublicationYear: firstPublicationYear ?? this.firstPublicationYear,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }
}

@immutable
class BookDetail {
  const BookDetail({
    required this.id,
    required this.title,
    required this.authors,
    this.firstPublicationYear,
    this.subjects = const [],
    this.description,
    this.coverUrl,
  });

  final String id;
  final String title;
  final List<String> authors;
  final int? firstPublicationYear;
  final List<String> subjects;
  final String? description;
  final String? coverUrl;

  factory BookDetail.fromJson(Map<String, dynamic> json) {
    final titleValue = json['title'];
    final title = titleValue is String && titleValue.trim().isNotEmpty
        ? titleValue
        : 'Untitled';

    final authorsList = <String>[];
    final rawAuthors = json['authors'];
    if (rawAuthors is List) {
      for (final item in rawAuthors) {
        if (item is Map && item['name'] is String) {
          final value = item['name'] as String;
          if (value.trim().isNotEmpty) {
            authorsList.add(value);
          }
        }
      }
    }

    final authorNames = json['author_name'];
    if (authorNames is List && authorsList.isEmpty) {
      for (final item in authorNames) {
        if (item is String && item.trim().isNotEmpty) {
          authorsList.add(item);
        }
      }
    }

    final subjectsList = <String>[];
    final rawSubjects = json['subjects'];
    if (rawSubjects is List) {
      for (final item in rawSubjects) {
        if (item is String && item.trim().isNotEmpty) {
          subjectsList.add(item);
        }
      }
    }

    String? description;
    final rawDescription = json['description'];
    if (rawDescription is String) {
      description = rawDescription;
    } else if (rawDescription is Map) {
      final value = rawDescription['value'];
      if (value is String && value.trim().isNotEmpty) {
        description = value;
      }
    }

    String? coverUrl;
    final coverIds = json['covers'];
    if (coverIds is List && coverIds.isNotEmpty && coverIds.first is num) {
      coverUrl = 'https://covers.openlibrary.org/b/id/${coverIds.first}-M.jpg';
    }

    final key = json['key'];
    String id = '';
    if (key is String) {
      id = key.split('/').last;
    }

    final yearValue = json['first_publish_year'];
    int? year;
    if (yearValue is int) {
      year = yearValue;
    } else if (yearValue is String) {
      year = int.tryParse(yearValue);
    }

    return BookDetail(
      id: id,
      title: title,
      authors: authorsList.isNotEmpty ? authorsList : const ['Unknown author'],
      firstPublicationYear: year,
      subjects: subjectsList,
      description: description,
      coverUrl: coverUrl,
    );
  }

  BookSummary toSummary() {
    return BookSummary(
      id: id,
      title: title,
      author: authors.join(', '),
      firstPublicationYear: firstPublicationYear,
      coverUrl: coverUrl,
    );
  }
}

@immutable
class SearchResultsState {
  const SearchResultsState({
    this.status = SearchStatus.initial,
    this.query = '',
    this.books = const [],
    this.offline = false,
    this.errorMessage,
  });

  final SearchStatus status;
  final String query;
  final List<BookSummary> books;
  final bool offline;
  final String? errorMessage;

  SearchResultsState copyWith({
    SearchStatus? status,
    String? query,
    List<BookSummary>? books,
    bool? offline,
    String? errorMessage,
  }) {
    return SearchResultsState(
      status: status ?? this.status,
      query: query ?? this.query,
      books: books ?? this.books,
      offline: offline ?? this.offline,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

enum SearchStatus {
  initial,
  loading,
  results,
  empty,
  error,
}
