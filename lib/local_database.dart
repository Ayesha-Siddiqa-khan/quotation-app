import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'quotation.dart';

class LocalQuotationDatabase {
  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final support = await getApplicationSupportDirectory();
    final databasePath = path.join(support.path, 'municipal_quotations.db');
    _database = await openDatabase(
      databasePath,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE quotations (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            file_name TEXT NOT NULL,
            data TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX quotations_updated_at ON quotations(updated_at DESC)',
        );
        await _createSuggestionTable(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) await _createSuggestionTable(db);
      },
    );
    return _database!;
  }

  Future<void> save(Quotation quotation) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((transaction) async {
      await transaction.insert('quotations', {
        'id': quotation.id,
        'title': quotation.title,
        'file_name': quotation.fileName,
        'data': quotation.encode(),
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      for (final line in quotation.lines) {
        final description = line.description.trim();
        if (description.isEmpty) continue;
        await transaction.insert('item_suggestions', {
          'key': description.toLowerCase(),
          'description': description,
          'last_used': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<Quotation?> latest() async {
    final db = await _db;
    final rows = await db.query(
      'quotations',
      columns: ['data'],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Quotation.decode(rows.first['data']! as String);
  }

  Future<List<Quotation>> all() async {
    final db = await _db;
    final rows = await db.query(
      'quotations',
      columns: ['data'],
      orderBy: 'updated_at DESC',
    );
    return rows.map((row) => Quotation.decode(row['data']! as String)).toList();
  }

  Future<List<String>> suggestions(String query, {int limit = 30}) async {
    final db = await _db;
    final value = query.trim().toLowerCase();
    final rows = await db.query(
      'item_suggestions',
      columns: ['description'],
      where: value.isEmpty ? null : 'key LIKE ?',
      whereArgs: value.isEmpty ? null : ['%$value%'],
      orderBy: 'last_used DESC',
      limit: limit,
    );
    return rows.map((row) => row['description']! as String).toList();
  }

  Future<void> _createSuggestionTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS item_suggestions (
        key TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        last_used INTEGER NOT NULL
      )
    ''');
  }
}
