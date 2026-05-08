import 'package:flutter_test/flutter_test.dart';
import 'package:mail_linear_flutter/app/mail_linear_app.dart';

void main() {
  testWidgets('renders desktop shell while booting', (tester) async {
    await tester.pumpWidget(const MailLinearApp());
    expect(find.byType(MailLinearApp), findsOneWidget);
  });
}
