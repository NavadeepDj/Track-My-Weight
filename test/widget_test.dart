// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:track_my_weight/main.dart';

void main() {
  testWidgets('TrackMyWeight renders the dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TrackMyWeightApp());

    await tester.pump();

    expect(find.text('Track My Weight'), findsOneWidget);
    expect(find.text('Track every change, clearly.'), findsOneWidget);
  });
}
