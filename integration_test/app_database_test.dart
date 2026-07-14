// Runs on a real device/simulator (not the host VM), because it exercises
// path_provider — which unit tests (test/) cannot do without mocking
// platform channels. E13.T3 will add the full user-flow integration tests
// on top of this same harness.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_finance_assistant/data/db/app_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AppDatabase opens a real, file-backed database on-device', (
    tester,
  ) async {
    final db = AppDatabase();
    addTearDown(db.close);

    expect(db.schemaVersion, 1);

    final result = await db.customSelect('SELECT 1 AS one').getSingle();
    expect(result.data['one'], 1);
  });
}
