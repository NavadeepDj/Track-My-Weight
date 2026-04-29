import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/person.dart';
import '../models/weight_entry.dart';
import 'app_logger.dart';

class SupabaseDatabase {
  SupabaseDatabase._();

  static final SupabaseDatabase instance = SupabaseDatabase._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Person>> getPeople() async {
    AppLogger.debug(
      'Supabase query started',
      data: {'table': 'people', 'action': 'select'},
    );
    final rows = await _client
        .from('people')
        .select()
        .order('name', ascending: true);
    final people = rows.map((row) => Person.fromMap(row)).toList();
    AppLogger.debug(
      'Supabase query completed',
      data: {'table': 'people', 'action': 'select', 'count': people.length},
    );
    return people;
  }

  Future<int> addPerson(String name) async {
    AppLogger.debug(
      'Supabase mutation started',
      data: {'table': 'people', 'action': 'insert'},
    );
    final row = await _client
        .from('people')
        .insert({
          'name': name.trim(),
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();
    final id = row['id'] as int;
    AppLogger.debug(
      'Supabase mutation completed',
      data: {'table': 'people', 'action': 'insert', 'id': id},
    );
    return id;
  }

  Future<void> deletePerson(int personId) async {
    AppLogger.debug(
      'Supabase mutation started',
      data: {'table': 'people', 'action': 'delete', 'personId': personId},
    );
    await _client.from('people').delete().eq('id', personId);
    AppLogger.debug(
      'Supabase mutation completed',
      data: {'table': 'people', 'action': 'delete', 'personId': personId},
    );
  }

  Future<List<WeightEntry>> getEntriesForPerson(int personId) async {
    AppLogger.debug(
      'Supabase query started',
      data: {
        'table': 'weight_entries',
        'action': 'select',
        'personId': personId,
      },
    );
    final rows = await _client
        .from('weight_entries')
        .select()
        .eq('person_id', personId)
        .order('recorded_at', ascending: true);
    final entries = rows.map((row) => WeightEntry.fromMap(row)).toList();
    AppLogger.debug(
      'Supabase query completed',
      data: {
        'table': 'weight_entries',
        'action': 'select',
        'personId': personId,
        'count': entries.length,
      },
    );
    return entries;
  }

  Future<int> addWeightEntry(WeightEntry entry) async {
    AppLogger.debug(
      'Supabase mutation started',
      data: {
        'table': 'weight_entries',
        'action': 'insert',
        'personId': entry.personId,
      },
    );
    final row = await _client
        .from('weight_entries')
        .insert({
          'person_id': entry.personId,
          'weight_kg': entry.weightKg,
          'recorded_at': entry.recordedAt.toIso8601String(),
          'note': entry.note,
        })
        .select('id')
        .single();
    final id = row['id'] as int;
    AppLogger.debug(
      'Supabase mutation completed',
      data: {'table': 'weight_entries', 'action': 'insert', 'id': id},
    );
    return id;
  }

  Future<void> deleteWeightEntry(int entryId) async {
    AppLogger.debug(
      'Supabase mutation started',
      data: {'table': 'weight_entries', 'action': 'delete', 'entryId': entryId},
    );
    await _client.from('weight_entries').delete().eq('id', entryId);
    AppLogger.debug(
      'Supabase mutation completed',
      data: {'table': 'weight_entries', 'action': 'delete', 'entryId': entryId},
    );
  }
}
