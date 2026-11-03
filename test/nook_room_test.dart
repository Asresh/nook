import 'package:flutter_test/flutter_test.dart';
import 'package:nook/models/nook_room.dart';

void main() {
  test('parses a room row and trims the name', () {
    final room = NookRoom.fromMap({
      'id': 'abc',
      'name': '  Late Night Talks  ',
      'topic': 'No agenda',
      'created_at': '2026-11-02T10:00:00Z',
    });

    expect(room.id, 'abc');
    expect(room.name, 'Late Night Talks');
    expect(room.topic, 'No agenda');
    expect(room.createdAt.toUtc(), DateTime.utc(2026, 11, 2, 10));
  });

  test('falls back when optional fields are missing', () {
    final room = NookRoom.fromMap({'id': 'abc'});

    expect(room.name, 'Untitled room');
    expect(room.topic, '');
  });
}
