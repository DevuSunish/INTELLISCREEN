// End-to-end UI flow against a running backend. Run it twice, as separate app
// processes, with the same account:
//
//   flutter test integration_test/app_flow_test.dart -d linux \
//     --dart-define=INTELLISCREEN_API_URL=http://127.0.0.1:8000/api/v1 \
//     --dart-define=E2E_EMAIL=e2e-user@example.com --dart-define=E2E_PHASE=assess
//
// then again with E2E_PHASE=verify to check the saved data after a restart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/services/api_client.dart';
import 'package:integration_test/integration_test.dart';

const email = String.fromEnvironment('E2E_EMAIL');
const phase = String.fromEnvironment('E2E_PHASE', defaultValue: 'assess');
const password = 'e2ePassword123';

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).first;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Taps the app bar's back button (the app uses custom leading buttons).
Future<void> goBack(WidgetTester tester) async {
  await tester.tap(
    find.descendant(of: find.byType(AppBar), matching: find.byType(IconButton)).first,
  );
  await tester.pumpAndSettle();
}

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
}

Future<void> signIn(WidgetTester tester, {required bool register}) async {
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tapText(tester, register ? 'Create an account' : 'Sign In as Parent');
  await waitFor(tester, find.text('Screening Dashboard'));
}

Future<void> openSam(WidgetTester tester) async {
  await tapText(tester, 'Child Profiles');
  await waitFor(tester, find.text('Sam T. (Demo Profile)'));
  for (final name in ['Leo M.', 'Maya S.', 'Zoe K.']) {
    expect(find.textContaining(name), findsOneWidget);
  }
  expect(find.textContaining('Backend Profiles'), findsNothing);
  expect(find.textContaining('Add Child'), findsNothing);
  await tapText(tester, 'Sam T. (Demo Profile)');
  await waitFor(tester, find.text('Assessment History'));
}

Future<void> setActivity(WidgetTester tester, String title, String button) async {
  await tapText(tester, title);
  await tapText(tester, button);
  await waitFor(tester, find.textContaining('saved as'));
  await goBack(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('INTELLISCREEN flow ($phase)', (tester) async {
    expect(email, isNotEmpty, reason: 'pass --dart-define=E2E_EMAIL=...');
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    if (phase == 'assess') {
      await signIn(tester, register: true);
      expect(AuthSession.instance.isAuthenticated, isTrue);
      await openSam(tester);
      expect(find.text('No assessments yet'), findsOneWidget);

      await tapText(tester, 'New Assessment');
      await waitFor(tester, find.text('Start Assessment'));
      await tapText(tester, 'Start Assessment');
      await waitFor(tester, find.text('In Progress'));

      await setActivity(tester, 'Handwriting Assessment', 'Mark Completed');
      expect(find.text('1 of 5 activities completed'), findsOneWidget);

      // Leave the workflow and reopen it: the status comes back from the backend.
      await goBack(tester);
      await waitFor(tester, find.text('Assessment in progress'));
      await tapText(tester, 'New Assessment');
      await waitFor(tester, find.text('1 of 5 activities completed'));

      for (final title in [
        'Reading Assessment',
        'Phonological Awareness',
        'Rapid Automatized Naming (RAN)',
        'Memory Assessment',
      ]) {
        await setActivity(tester, title, 'Mark Completed');
      }
      expect(find.text('5 of 5 activities completed'), findsOneWidget);

      await tapText(tester, 'Complete & Save Screening Session');
      await waitFor(tester, find.textContaining('Screening Session #'));
      expect(find.textContaining('No screening result has been generated'), findsOneWidget);
      expect(find.text('Activities completed: 5 of 5'), findsOneWidget);

      // Sign out clears the token.
      await goBack(tester);
      await goBack(tester);
      await tapText(tester, 'Sign Out');
      expect(find.text('Create an account'), findsOneWidget);
      expect(AuthSession.instance.isAuthenticated, isFalse);
    } else {
      // A fresh app process: sign in again and find the saved assessment.
      expect(AuthSession.instance.isAuthenticated, isFalse);
      await signIn(tester, register: false);
      await waitFor(tester, find.text('1 Completed'));
      await openSam(tester);
      await waitFor(tester, find.textContaining('Screening Session #'));
      expect(find.text('Completed'), findsWidgets);
      expect(find.text('Activities completed: 5 of 5'), findsOneWidget);
      expect(find.textContaining('Last screening completed'), findsOneWidget);
    }
  });
}
