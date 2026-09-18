import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p; 
import 'package:sqflite/sqflite.dart';

import '../domain/models/book.dart';

class FavoritesDatabase {
  FavoritesDatabase({String databaseName = 'favorites.db'})
      : _databaseName = databaseName;

  final String _databaseName;
  static final FavoritesDatabase instance = FavoritesDatabase();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _databaseName);
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE favorites (
            id TEXT PRIMARY KEY,
            title TEXT,
            author TEXT,
            firstPublicationYear INTEGER,
            coverUrl TEXT
          )
        ''');
      },
    );
  }

  Future<void> addFavorite(BookSummary book) async {
    final db = await database;
    await db.insert(
      'favorites',
      book.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavorite(String id) async {
    final db = await database;
    await db.delete('favorites', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> isFavorite(String id) async {
    final db = await database;
    final result = await db.query(
      'favorites',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<List<BookSummary>> getFavorites() async {
    final db = await database;
    final rows = await db.query('favorites');
    return rows.map((row) => BookSummary.fromMap(row)).toList();
  }

  Future<void> resetForTest() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _databaseName);
    await deleteDatabase(path);
  }
}
