import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sleep_habits/core/app.dart';

void main() {
  testWidgets('renders SleepHabitsApp scaffold', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SleepHabitsApp()));
    await tester.pump();

    expect(find.text('SleepHabits'), findsOneWidget);
  });
}
