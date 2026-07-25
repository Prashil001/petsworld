import 'package:flutter_test/flutter_test.dart';

import 'package:shop/core/app/app_scope.dart';
import 'package:shop/main.dart';

void main() {
  testWidgets('App boots into storefront for guests', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AppScope(child: MyApp()));
    await tester.pumpAndSettle();

    expect(find.text('PetsWorld'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Sign in to your account'), findsNothing);
  });
}
