import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_finance_assistant/main.dart';

void main() {
  testWidgets('starts on Overview and switches tabs via bottom navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: PfaApp()));
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsWidgets);

    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(find.text('Plan'), findsWidgets);

    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('Accounts'), findsWidgets);
  });
}
