// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/main.dart';

void main() {
  testWidgets('App boots to auth flow without crashing', (WidgetTester tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Avoid touching SharedPreferences/SQLite in tests.
            institutionRegisteredProvider.overrideWith((ref) async => true),
          ],
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ENTER PORTAL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
