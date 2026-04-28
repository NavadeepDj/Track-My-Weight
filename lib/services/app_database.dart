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
      try {
        final people = await SupabaseDatabase.instance.getPeople();
        await _cachePeople(people);
        return people;
      } catch (_) {
        return _getLocalPeople();
      }
    }

    return _getLocalPeople();
  }

  Future<List<Person>> _getLocalPeople() async {
    final db = await database;
    final rows = await db.query('people', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Person.fromMap).toList();
  }

  Future<int> addPerson(String name) async {
    if (isCloudEnabled) {
      final id = await SupabaseDatabase.instance.addPerson(name);
      await _upsertLocalPerson(
        Person(id: id, name: name.trim(), createdAt: DateTime.now()),
      );
      return id;
    }

    return _addLocalPerson(name);
  }

  Future<int> _addLocalPerson(String name) async {
    final db = await database;
    return db.insert(
      'people',
      Person(id: null, name: name.trim(), createdAt: DateTime.now()).toMap(),
    );
  }

  Future<void> deletePerson(int personId) async {
    if (isCloudEnabled) {
      await SupabaseDatabase.instance.deletePerson(personId);
      await _deleteLocalPerson(personId);
      return;
    }

    await _deleteLocalPerson(personId);
  }

  Future<void> _deleteLocalPerson(int personId) async {
    final db = await database;
    await db.delete('people', where: 'id = ?', whereArgs: [personId]);
  }

  Future<List<WeightEntry>> getEntriesForPerson(int personId) async {
    if (isCloudEnabled) {
      try {
        final entries = await SupabaseDatabase.instance.getEntriesForPerson(
          personId,
        );
        await _cacheEntriesForPerson(personId, entries);
        return entries;
      } catch (_) {
        return _getLocalEntriesForPerson(personId);
      }
    }

    return _getLocalEntriesForPerson(personId);
  }

  Future<List<WeightEntry>> _getLocalEntriesForPerson(int personId) async {
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
      final id = await SupabaseDatabase.instance.addWeightEntry(entry);
      await _upsertLocalWeightEntry(
        WeightEntry(
          id: id,
          personId: entry.personId,
          weightKg: entry.weightKg,
          recordedAt: entry.recordedAt,
          note: entry.note,
        ),
      );
      return id;
    }

    return _addLocalWeightEntry(entry);
  }

  Future<int> _addLocalWeightEntry(WeightEntry entry) async {
    final db = await database;
    return db.insert('weight_entries', entry.toMap());
  }

  Future<void> deleteWeightEntry(int entryId) async {
    if (isCloudEnabled) {
      await SupabaseDatabase.instance.deleteWeightEntry(entryId);
      await _deleteLocalWeightEntry(entryId);
      return;
    }

    await _deleteLocalWeightEntry(entryId);
  }

  Future<void> _deleteLocalWeightEntry(int entryId) async {
    final db = await database;
    await db.delete('weight_entries', where: 'id = ?', whereArgs: [entryId]);
  }

  Future<void> _cachePeople(List<Person> people) async {
    final db = await database;
    final batch = db.batch();
    for (final person in people) {
      batch.insert(
        'people',
        person.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _upsertLocalPerson(Person person) async {
    final db = await database;
    await db.insert(
      'people',
      person.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _cacheEntriesForPerson(
    int personId,
    List<WeightEntry> entries,
  ) async {
    final db = await database;
    final batch = db.batch();
    batch.delete(
      'weight_entries',
      where: 'person_id = ?',
      whereArgs: [personId],
    );
    for (final entry in entries) {
      batch.insert(
        'weight_entries',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _upsertLocalWeightEntry(WeightEntry entry) async {
    final db = await database;
    await db.insert(
      'weight_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
