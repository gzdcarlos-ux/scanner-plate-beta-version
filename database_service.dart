import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/plate_record.dart';

/// Camada de acesso ao banco SQLite local.
///
/// A tabela `plates` possui um índice único na coluna `plate`, o que garante
/// que a consulta feita a cada placa reconhecida pelo OCR use lookup por
/// índice (O(log n) / praticamente O(1) com B-Tree do SQLite) em vez de
/// varredura completa — essencial para manter a latência abaixo de ~10ms
/// mesmo com bases de dezenas de milhares de placas.
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  static const String _dbName = 'plates.db';
  static const String _table = 'plates';
  static const int _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            plate TEXT NOT NULL,
            observation TEXT
          )
        ''');

        // Índice único: garante buscas rapidíssimas e evita placas duplicadas
        // (uma nova importação com CONFLICT REPLACE atualiza o registro existente).
        await db.execute('''
          CREATE UNIQUE INDEX idx_plates_plate ON $_table (plate)
        ''');
      },
    );
  }

  /// Insere/atualiza uma lista de registros dentro de uma única transação
  /// (muito mais rápido do que inserts individuais para planilhas grandes).
  Future<int> upsertPlates(List<PlateRecord> records) async {
    final db = await database;
    int count = 0;

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final record in records) {
        batch.insert(
          _table,
          record.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      final results = await batch.commit(noResult: false);
      count = results.length;
    });

    return count;
  }

  /// Busca uma placa exata no banco. Usa o índice único criado acima.
  /// Retorna `null` caso não haja correspondência.
  Future<PlateRecord?> lookupPlate(String sanitizedPlate) async {
    final db = await database;
    final rows = await db.query(
      _table,
      where: 'plate = ?',
      whereArgs: [sanitizedPlate],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return PlateRecord.fromMap(rows.first);
  }

  /// Quantidade total de placas cadastradas — usada na tela inicial.
  Future<int> countPlates() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) AS total FROM $_table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Limpa toda a base local (útil antes de reimportar uma planilha nova
  /// do zero, caso o usuário deseje substituir a lista completamente).
  Future<void> clearAll() async {
    final db = await database;
    await db.delete(_table);
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
