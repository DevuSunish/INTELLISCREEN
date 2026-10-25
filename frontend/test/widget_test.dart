import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/models/child_record.dart';
import 'package:frontend/screens/children_screen.dart';
import 'package:frontend/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void useBackend(Future<http.Response> Function(http.Request request) handler) {
  ApiClient.shared = ApiClient(baseUrl: 'http://test.local/api/v1', httpClient: MockClient(handler));
}

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

Map<String, dynamic> emptyProgress(int id, String code) => {
      'child_id': id,
      'participant_code': code,
      'total_assessments': 0,
      'completed_assessments': 0,
      'in_progress_assessments': 0,
      'results_available': 0,
      'assessment_history': [],
    };

void useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    AuthSession.instance.signOut();
    childrenStore.clear();
  });

  testWidgets('sign-in screen offers sign in and account creation', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('INTELLISCREEN'), findsOneWidget);
    expect(find.text('Sign In as Parent'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });

  testWidgets('invalid credentials keep the user on the sign-in screen', (tester) async {
    useBackend((_) async => jsonResponse({'detail': 'Invalid email or password'}, 401));
    useTallView(tester);
    await tester.pumpWidget(const MyApp());
    await tester.enterText(find.byType(TextFormField).at(0), 'parent@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongPassword');
    await tester.tap(find.text('Sign In as Parent'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password'), findsOneWidget);
    expect(find.text('Screening Dashboard'), findsNothing);
    expect(AuthSession.instance.isAuthenticated, isFalse);
  });

  testWidgets('children screen lists backend profiles without profile creation UI', (tester) async {
    AuthSession.instance.signIn('t', const AuthUser(id: 1, email: 'a@b.co', role: 'parent'));
    final ids = {'demo-1': 21, 'demo-2': 22, 'demo-3': 23, 'demo-4': 24};
    useBackend((request) async {
      expect(request.headers['Authorization'], 'Bearer t');
      if (request.url.path.endsWith('/children/')) {
        return jsonResponse([
          for (final entry in ids.entries)
            {'id': entry.value, 'participant_code': entry.key, 'age_years': 6, 'is_demo': true},
        ]);
      }
      final id = int.parse(request.url.pathSegments.last);
      final code = ids.entries.firstWhere((entry) => entry.value == id).key;
      return jsonResponse(emptyProgress(id, code));
    });

    useTallView(tester);
    await tester.pumpWidget(const MaterialApp(home: ChildrenScreen()));
    await tester.pumpAndSettle();

    for (final name in ['Leo M.', 'Maya S.', 'Sam T.', 'Zoe K.']) {
      expect(find.textContaining(name), findsOneWidget);
    }
    expect(find.text('Not screened yet'), findsNWidgets(4));
    expect(find.textContaining('Backend Profiles'), findsNothing);
    expect(find.textContaining('Add Child'), findsNothing);
    expect(childrenStore.children.map((c) => c.backendId), [21, 22, 23, 24]);
  });

  testWidgets('children screen shows an error with retry when the backend is down', (tester) async {
    AuthSession.instance.signIn('t', const AuthUser(id: 1, email: 'a@b.co', role: 'parent'));
    var calls = 0;
    useBackend((request) async {
      calls++;
      throw http.ClientException('Connection refused');
    });

    await tester.pumpWidget(const MaterialApp(home: ChildrenScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Could not load child profiles'), findsOneWidget);
    expect(find.textContaining('Cannot reach the INTELLISCREEN server'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
}
