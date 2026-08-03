import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/modules/chat/message_actions_sheet.dart';

void main() {
  testWidgets('failed media actions expose retry and local removal', (
    tester,
  ) async {
    var removed = false;
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageActionsSheet(
            isPinned: false,
            initiallyShowMore: true,
            deleteLabel: 'Remove failed photo',
            onDeleteForMe: () => removed = true,
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Retry send'), findsOneWidget);
    expect(find.text('Remove failed photo'), findsOneWidget);

    await tester.tap(find.text('Retry send'));
    await tester.tap(find.text('Remove failed photo'));

    expect(retried, isTrue);
    expect(removed, isTrue);
  });
}
