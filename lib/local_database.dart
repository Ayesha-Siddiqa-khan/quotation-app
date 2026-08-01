import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'quotation.dart';

class StoredQuotation {
  const StoredQuotation({required this.quotation, required this.isReference});

  final Quotation quotation;
  final bool isReference;
}

class LocalQuotationDatabase {
  Database? _database;
  String? _databasePath;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final support = await getApplicationSupportDirectory();
    _databasePath = path.join(support.path, 'municipal_quotations.db');
    _database = await openDatabase(
      _databasePath!,
      version: 3,
      onCreate: (db, _) async {
        await _createQuotationTable(db);
        await _createReferenceTable(db);
        await _createSuggestionTable(db);
        await _createSettingsTable(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) await _createSuggestionTable(db);
        if (oldVersion < 3) {
          await _createReferenceTable(db);
          await _createSettingsTable(db);
        }
      },
    );
    return _database!;
  }

  Future<String> location() async {
    await _db;
    return _databasePath!;
  }

  Future<void> save(Quotation quotation) async {
    quotation.updatedAt = DateTime.now();
    final db = await _db;
    await db.transaction((transaction) async {
      await _insertQuotation(transaction, 'quotations', quotation);
      await _learnItems(transaction, quotation);
    });
  }

  Future<void> saveReference(Quotation quotation) async {
    quotation.updatedAt = DateTime.now();
    final db = await _db;
    await db.transaction((transaction) async {
      await _insertQuotation(transaction, 'imported_references', quotation);
      await _learnItems(transaction, quotation);
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
    return _readTable(db, 'quotations');
  }

  Future<List<Quotation>> references() async {
    final db = await _db;
    return _readTable(db, 'imported_references');
  }

  Future<List<StoredQuotation>> records({String query = ''}) async {
    final db = await _db;
    final working = await _readTable(db, 'quotations');
    final imported = await _readTable(db, 'imported_references');
    final value = query.trim().toLowerCase();
    bool matches(Quotation quotation) {
      if (value.isEmpty) return true;
      return quotation.title.toLowerCase().contains(value) ||
          quotation.fileName.toLowerCase().contains(value) ||
          quotation.sourceName.toLowerCase().contains(value) ||
          quotation.lines.any(
            (line) => line.description.toLowerCase().contains(value),
          );
    }

    final result = <StoredQuotation>[
      for (final quotation in imported)
        if (matches(quotation))
          StoredQuotation(quotation: quotation, isReference: true),
      for (final quotation in working)
        if (matches(quotation))
          StoredQuotation(quotation: quotation, isReference: false),
    ];
    result.sort(
      (a, b) => b.quotation.updatedAt.compareTo(a.quotation.updatedAt),
    );
    return result;
  }

  Future<void> deleteRecord(StoredQuotation record) async {
    final db = await _db;
    await db.delete(
      record.isReference ? 'imported_references' : 'quotations',
      where: 'id = ?',
      whereArgs: [record.quotation.id],
    );
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

  Future<void> setSetting(String key, String value) async {
    final db = await _db;
    await db.insert('app_settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> setting(String key) async {
    final db = await _db;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<Uint8List> exportBackup() async {
    final db = await _db;
    final quotations = await db.query('quotations');
    final references = await db.query('imported_references');
    final suggestions = await db.query('item_suggestions');
    final settings = await db.query('app_settings');
    final data = jsonEncode({
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'quotations': quotations,
      'importedReferences': references,
      'itemSuggestions': suggestions,
      'settings': settings,
    });
    return Uint8List.fromList(utf8.encode(data));
  }

  Future<void> restoreBackup(Uint8List bytes) async {
    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (decoded['schemaVersion'] != 1) {
      throw const FormatException('Unsupported backup format.');
    }
    final db = await _db;
    await db.transaction((transaction) async {
      for (final table in [
        'quotations',
        'imported_references',
        'item_suggestions',
        'app_settings',
      ]) {
        await transaction.delete(table);
      }
      await _restoreRows(transaction, 'quotations', decoded['quotations']);
      await _restoreRows(
        transaction,
        'imported_references',
        decoded['importedReferences'],
      );
      await _restoreRows(
        transaction,
        'item_suggestions',
        decoded['itemSuggestions'],
      );
      await _restoreRows(transaction, 'app_settings', decoded['settings']);
    });
  }

  Future<void> _restoreRows(
    Transaction transaction,
    String table,
    Object? source,
  ) async {
    for (final value in source as List<dynamic>? ?? const []) {
      await transaction.insert(
        table,
        Map<String, Object?>.from(value as Map),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Quotation>> _readTable(Database db, String table) async {
    final rows = await db.query(
      table,
      columns: ['data'],
      orderBy: 'updated_at DESC',
    );
    return rows.map((row) => Quotation.decode(row['data']! as String)).toList();
  }

  Future<void> _insertQuotation(
    DatabaseExecutor db,
    String table,
    Quotation quotation,
  ) async {
    await db.insert(table, {
      'id': quotation.id,
      'title': quotation.title,
      'file_name': quotation.fileName,
      'data': quotation.encode(),
      'created_at': quotation.createdAt.millisecondsSinceEpoch,
      'updated_at': quotation.updatedAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _learnItems(DatabaseExecutor db, Quotation quotation) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final line in quotation.lines) {
      final description = line.description.trim();
      if (description.isEmpty) continue;
      await db.insert('item_suggestions', {
        'key': description.toLowerCase(),
        'description': description,
        'last_used': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _createQuotationTable(Database db) async {
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
  }

  Future<void> _createReferenceTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS imported_references (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        file_name TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS references_updated_at
      ON imported_references(updated_at DESC)
    ''');
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

  Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }
}
