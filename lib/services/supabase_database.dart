import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/person.dart';
import '../models/weight_entry.dart';

class SupabaseDatabase {
  SupabaseDatabase._();

  static final SupabaseDatabase instance = SupabaseDatabase._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Person>> getPeople() async {
    final rows = await _client.from('people').select().order('name', ascending: true);
    return rows.map((row) => Person.fromMap(row)).toList();
  }

  Future<int> addPerson(String name) async {
    final row = await _client
        .from('people')
        .insert({
          'name': name.trim(),
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();
    return row['id'] as int;
  }

  Future<void> deletePerson(int personId) async {
    await _client.from('people').delete().eq('id', personId);
  }

  Future<List<WeightEntry>> getEntriesForPerson(int personId) async {
    final rows = await _client
        .from('weight_entries')
        .select()
        .eq('person_id', personId)
        .order('recorded_at', ascending: true);
    return rows.map((row) => WeightEntry.fromMap(row)).toList();
  }

  Future<int> addWeightEntry(WeightEntry entry) async {
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
    return row['id'] as int;
  }

  Future<void> deleteWeightEntry(int entryId) async {
    await _client.from('weight_entries').delete().eq('id', entryId);
  }
}
