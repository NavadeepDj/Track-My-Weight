class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.personId,
    required this.weightKg,
    required this.recordedAt,
    this.note,
  });

  final int? id;
  final int personId;
  final double weightKg;
  final DateTime recordedAt;
  final String? note;

  factory WeightEntry.fromMap(Map<String, Object?> map) {
    return WeightEntry(
      id: map['id'] as int?,
      personId: map['person_id'] as int,
      weightKg: map['weight_kg'] as double,
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      note: map['note'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'person_id': personId,
      'weight_kg': weightKg,
      'recorded_at': recordedAt.toIso8601String(),
      'note': note,
    };
  }
}
