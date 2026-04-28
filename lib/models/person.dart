class Person {
  const Person({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final DateTime createdAt;

  factory Person.fromMap(Map<String, Object?> map) {
    return Person(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
