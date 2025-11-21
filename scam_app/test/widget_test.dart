import 'package:flutter_test/flutter_test.dart';
import 'package:scam_app/main.dart';

void main() {
  testWidgets('HomeScreen has login and signup buttons', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(MyApp());

    // Vérifie que le bouton "Se connecter" existe
    expect(find.text('Se connecter'), findsOneWidget);

    // Vérifie que le bouton "S\'inscrire" existe
    expect(find.text("S'inscrire"), findsOneWidget);
  });
}
