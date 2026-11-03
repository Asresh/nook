class NookRoom {
  const NookRoom({
    required this.id,
    required this.name,
    required this.topic,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String topic;
  final DateTime createdAt;

  factory NookRoom.fromMap(Map<String, dynamic> map) {
    return NookRoom(
      id: map['id'] as String,
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? (map['name'] as String).trim()
          : 'Untitled room',
      topic: (map['topic'] as String?)?.trim() ?? '',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
