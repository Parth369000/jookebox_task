// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:jookebox_task/main.dart';

void main() {
  testWidgets('Reminder app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ReminderApp());

    // Verify core controls exist
    expect(find.text('Day of the week'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);

    // Verify that main controls are present
    expect(find.text('Day of the week'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
  });
}
