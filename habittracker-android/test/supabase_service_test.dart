import 'package:flutter_test/flutter_test.dart';
import 'package:habittracker/services/supabase_service.dart';

void main() {
  test('merge keeps a newer local unchecked habit', () {
    final service = SupabaseService(projectUrl: '', anonKey: '');
    final local = HabitData(
      habits: [
        {'id': 1, 'name': 'Drink Water', 'points': 20, 'isExtra': 0},
      ],
      dailyRecords: {
        '2026-05-24': <String, dynamic>{},
      },
      scoreHistory: {
        '2026-05-24': 0,
      },
      lastModified: '2026-05-24T12:00:00.000Z',
    );
    final remote = HabitData(
      habits: [
        {'id': 1, 'name': 'Drink Water', 'points': 20, 'isExtra': 0},
      ],
      dailyRecords: {
        '2026-05-24': {'1': true},
      },
      scoreHistory: {
        '2026-05-24': 20,
      },
      lastModified: '2026-05-24T11:00:00.000Z',
    );

    final merged = service.merge(local, remote);

    expect(merged.todayCompleted('2026-05-24'), isEmpty);
    expect(merged.todayScore('2026-05-24'), 0);
  });
}
