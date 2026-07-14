import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/data/db/app_database.dart';

void main() {
  test('opens an in-memory database with the expected schema version', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, 1);

    // A trivial round-trip query proves the connection is actually live,
    // not just constructed.
    final result = await db.customSelect('SELECT 1 AS one').getSingle();
    expect(result.data['one'], 1);
  });
}
