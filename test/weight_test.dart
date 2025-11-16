import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_text_field_widget.dart';

void main() {
  testWidgets('TextField widget displays label, handles input, and validates',
      (WidgetTester tester) async {
    // Build the TestTextFieldWidget with a given label.
    await tester.pumpWidget(const TestTextFieldWidget(label: 'Name'));

    // Allow any animations to complete.
    await tester.pumpAndSettle();

    // Verify the text field displays the label.
    expect(find.text('Name'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);

    // Enter text into the TextFormField.
    await tester.enterText(find.byType(TextFormField), 'John Doe');
    // Verify that the entered text appears.
    expect(find.text('John Doe'), findsOneWidget);

    // Clear the text to test the validator.
    await tester.enterText(find.byType(TextFormField), '');
    await tester.pump();

    // To trigger the validation, get the FormState and call validate().
    final formState = tester.state<FormState>(find.byType(Form));
    expect(formState.validate(), isFalse);

    // After validation, the error text should be visible.
    await tester.pump(); // Rebuild to show validation error
    expect(find.text('Required'), findsOneWidget);
  });
}