import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/person.dart';
import '../models/weight_entry.dart';
import 'supabase_config.dart';
import 'supabase_database.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static Database? _database;

  bool get isCloudEnabled => SupabaseConfig.isConfigured;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'track_my_weight.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE people (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE weight_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            person_id INTEGER NOT NULL,
            weight_kg REAL NOT NULL,
            recorded_at TEXT NOT NULL,
            note TEXT,
            FOREIGN KEY (person_id) REFERENCES people (id) ON DELETE CASCADE
          )
        ''');
      },
    );

    return _database!;
  }

  Future<List<Person>> getPeople() async {
    if (isCloudEnabled) {
      return SupabaseDatabase.instance.getPeople();
    }

    final db = await database;
    final rows = await db.query('people', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Person.fromMap).toList();
  }

  Future<int> addPerson(String name) async {
    if (isCloudEnabled) {
      return SupabaseDatabase.instance.addPerson(name);
    }

    final db = await database;
    return db.insert(
      'people',
      Person(id: null, name: name.trim(), createdAt: DateTime.now()).toMap(),
    );
  }

  Future<void> deletePerson(int personId) async {
    if (isCloudEnabled) {
      return SupabaseDatabase.instance.deletePerson(personId);
    }

    final db = await database;
    await db.delete('people', where: 'id = ?', whereArgs: [personId]);
  }

  Future<List<WeightEntry>> getEntriesForPerson(int personId) async {
    if (isCloudEnabled) {
      return SupabaseDatabase.instance.getEntriesForPerson(personId);
    }

    final db = await database;
    final rows = await db.query(
      'weight_entries',
      where: 'person_id = ?',
      whereArgs: [personId],
      orderBy: 'recorded_at ASC',
    );
    return rows.map(WeightEntry.fromMap).toList();
  }

  Future<int> addWeightEntry(WeightEntry entry) async {
    if (isCloudEnabled) {
      return SupabaseDatabase.instance.addWeightEntry(entry);
    }

    final db = await database;
    return db.insert('weight_entries', entry.toMap());
  }

  Future<void> deleteWeightEntry(int entryId) async {
    if (isCloudEnabled) {
      return SupabaseDatabase.instance.deleteWeightEntry(entryId);
    }

    final db = await database;
    await db.delete('weight_entries', where: 'id = ?', whereArgs: [entryId]);
  }
}
