import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/person.dart';
import '../models/weight_entry.dart';
import 'app_logger.dart';
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
    AppLogger.info('Opening local SQLite database', data: {'path': path});

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        AppLogger.info(
          'Creating local SQLite schema',
          data: {'version': version},
        );

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
        AppLogger.debug('Fetching people from Supabase');
        final people = await SupabaseDatabase.instance.getPeople();
        await _cachePeople(people);
        AppLogger.info(
          'Fetched people from Supabase',
          data: {'count': people.length},
        );
        return people;
      } catch (error, stackTrace) {
        AppLogger.warning(
          'Supabase people fetch failed; falling back to SQLite cache',
          error: error,
          stackTrace: stackTrace,
        );
        return _getLocalPeople();
      }
    }

    return _getLocalPeople();
  }

  Future<List<Person>> _getLocalPeople() async {
    AppLogger.debug('Fetching people from local SQLite');
    final db = await database;
    final rows = await db.query('people', orderBy: 'name COLLATE NOCASE ASC');
    final people = rows.map(Person.fromMap).toList();
    AppLogger.info(
      'Fetched people from local SQLite',
      data: {'count': people.length},
    );
    return people;
  }

  Future<int> addPerson(String name) async {
    if (isCloudEnabled) {
      AppLogger.info('Adding person to Supabase', data: {'name': name.trim()});
      final id = await SupabaseDatabase.instance.addPerson(name);
      await _upsertLocalPerson(
        Person(id: id, name: name.trim(), createdAt: DateTime.now()),
      );
      AppLogger.info(
        'Added person to Supabase and local cache',
        data: {'id': id},
      );
      return id;
    }

    return _addLocalPerson(name);
  }

  Future<int> _addLocalPerson(String name) async {
    AppLogger.info(
      'Adding person to local SQLite',
      data: {'name': name.trim()},
    );
    final db = await database;
    final id = await db.insert(
      'people',
      Person(id: null, name: name.trim(), createdAt: DateTime.now()).toMap(),
    );
    AppLogger.info('Added person to local SQLite', data: {'id': id});
    return id;
  }

  Future<void> deletePerson(int personId) async {
    if (isCloudEnabled) {
      AppLogger.info(
        'Deleting person from Supabase',
        data: {'personId': personId},
      );
      await SupabaseDatabase.instance.deletePerson(personId);
      await _deleteLocalPerson(personId);
      return;
    }

    await _deleteLocalPerson(personId);
  }

  Future<void> _deleteLocalPerson(int personId) async {
    AppLogger.info(
      'Deleting person from local SQLite',
      data: {'personId': personId},
    );
    final db = await database;
    await db.delete('people', where: 'id = ?', whereArgs: [personId]);
  }

  Future<List<WeightEntry>> getEntriesForPerson(int personId) async {
    if (isCloudEnabled) {
      try {
        AppLogger.debug(
          'Fetching weight entries from Supabase',
          data: {'personId': personId},
        );
        final entries = await SupabaseDatabase.instance.getEntriesForPerson(
          personId,
        );
        await _cacheEntriesForPerson(personId, entries);
        AppLogger.info(
          'Fetched weight entries from Supabase',
          data: {'personId': personId, 'count': entries.length},
        );
        return entries;
      } catch (error, stackTrace) {
        AppLogger.warning(
          'Supabase entry fetch failed; falling back to SQLite cache',
          data: {'personId': personId},
          error: error,
          stackTrace: stackTrace,
        );
        return _getLocalEntriesForPerson(personId);
      }
    }

    return _getLocalEntriesForPerson(personId);
  }

  Future<List<WeightEntry>> _getLocalEntriesForPerson(int personId) async {
    AppLogger.debug(
      'Fetching weight entries from local SQLite',
      data: {'personId': personId},
    );
    final db = await database;
    final rows = await db.query(
      'weight_entries',
      where: 'person_id = ?',
      whereArgs: [personId],
      orderBy: 'recorded_at ASC',
    );
    final entries = rows.map(WeightEntry.fromMap).toList();
    AppLogger.info(
      'Fetched weight entries from local SQLite',
      data: {'personId': personId, 'count': entries.length},
    );
    return entries;
  }

  Future<int> addWeightEntry(WeightEntry entry) async {
    if (isCloudEnabled) {
      AppLogger.info(
        'Adding weight entry to Supabase',
        data: {'personId': entry.personId, 'weightKg': entry.weightKg},
      );
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
      AppLogger.info(
        'Added weight entry to Supabase and local cache',
        data: {'id': id},
      );
      return id;
    }

    return _addLocalWeightEntry(entry);
  }

  Future<int> _addLocalWeightEntry(WeightEntry entry) async {
    AppLogger.info(
      'Adding weight entry to local SQLite',
      data: {'personId': entry.personId, 'weightKg': entry.weightKg},
    );
    final db = await database;
    final id = await db.insert('weight_entries', entry.toMap());
    AppLogger.info('Added weight entry to local SQLite', data: {'id': id});
    return id;
  }

  Future<void> deleteWeightEntry(int entryId) async {
    if (isCloudEnabled) {
      AppLogger.info(
        'Deleting weight entry from Supabase',
        data: {'entryId': entryId},
      );
      await SupabaseDatabase.instance.deleteWeightEntry(entryId);
      await _deleteLocalWeightEntry(entryId);
      return;
    }

    await _deleteLocalWeightEntry(entryId);
  }

  Future<void> _deleteLocalWeightEntry(int entryId) async {
    AppLogger.info(
      'Deleting weight entry from local SQLite',
      data: {'entryId': entryId},
    );
    final db = await database;
    await db.delete('weight_entries', where: 'id = ?', whereArgs: [entryId]);
  }

  Future<void> _cachePeople(List<Person> people) async {
    AppLogger.debug(
      'Refreshing local people cache',
      data: {'count': people.length},
    );
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
    AppLogger.info(
      'Local people cache refreshed',
      data: {'count': people.length},
    );
  }

  Future<void> _upsertLocalPerson(Person person) async {
    AppLogger.debug(
      'Upserting person into local cache',
      data: {'personId': person.id},
    );
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
    AppLogger.debug(
      'Refreshing local weight entry cache',
      data: {'personId': personId, 'count': entries.length},
    );
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
    AppLogger.info(
      'Local weight entry cache refreshed',
      data: {'personId': personId, 'count': entries.length},
    );
  }

  Future<void> _upsertLocalWeightEntry(WeightEntry entry) async {
    AppLogger.debug(
      'Upserting weight entry into local cache',
      data: {'entryId': entry.id},
    );
    final db = await database;
    await db.insert(
      'weight_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
