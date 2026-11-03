import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/nook_room.dart';

abstract class RoomsRepository {
  Future<List<NookRoom>> listRooms();

  Future<NookRoom> createRoom({
    required String name,
    required String topic,
    required String createdBy,
  });
}

class DemoRoomsRepository implements RoomsRepository {
  DemoRoomsRepository() {
    final now = DateTime.now();
    _rooms.addAll([
      NookRoom(
        id: 'demo-late-night',
        name: 'Late Night Talks',
        topic: 'No agenda. Just talk.',
        createdAt: now.subtract(const Duration(minutes: 4)),
      ),
      NookRoom(
        id: 'demo-study',
        name: 'Study With Me',
        topic: 'Quiet company while you work',
        createdAt: now.subtract(const Duration(minutes: 22)),
      ),
      NookRoom(
        id: 'demo-venting',
        name: 'Venting Circle',
        topic: 'Say it out loud, no judgement',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      NookRoom(
        id: 'demo-music',
        name: 'Music & Chill',
        topic: 'Share what is on repeat',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
    ]);
  }

  final List<NookRoom> _rooms = [];
  int _counter = 0;

  @override
  Future<List<NookRoom>> listRooms() async {
    return List<NookRoom>.unmodifiable(_rooms);
  }

  @override
  Future<NookRoom> createRoom({
    required String name,
    required String topic,
    required String createdBy,
  }) async {
    _counter += 1;
    final room = NookRoom(
      id: 'demo-${DateTime.now().millisecondsSinceEpoch}-$_counter',
      name: name,
      topic: topic,
      createdAt: DateTime.now(),
    );
    _rooms.insert(0, room);
    return room;
  }
}

class SupabaseRoomsRepository implements RoomsRepository {
  const SupabaseRoomsRepository();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<List<NookRoom>> listRooms() async {
    final rows = await _client
        .from('rooms')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => NookRoom.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<NookRoom> createRoom({
    required String name,
    required String topic,
    required String createdBy,
  }) async {
    final row = await _client
        .from('rooms')
        .insert({'name': name, 'topic': topic, 'created_by': createdBy})
        .select()
        .single();
    return NookRoom.fromMap(row);
  }
}
