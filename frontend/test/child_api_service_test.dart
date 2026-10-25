import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/child_record.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/services/auth_api_service.dart';
import 'package:frontend/services/child_api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const baseUrl = 'http://test.local/api/v1';

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> authBody({String token = 'token-123'}) => {
      'access_token': token,
      'token_type': 'bearer',
      'expires_in': 43200,
      'user': {'id': 7, 'email': 'parent@example.com', 'role': 'parent'},
    };

void main() {
  late AuthSession session;
  late List<http.Request> requests;

  ApiClient clientWith(Future<http.Response> Function(http.Request request) handler) {
    return ApiClient(
      baseUrl: baseUrl,
      session: session,
      httpClient: MockClient((request) {
        requests.add(request);
        return handler(request);
      }),
    );
  }

  setUp(() {
    session = AuthSession();
    requests = [];
  });

  group('AuthApiService', () {
    test('login stores the token and returns the user', () async {
      final service = AuthApiService(client: clientWith((_) async => jsonResponse(authBody())));
      final user = await service.login(email: 'parent@example.com', password: 'safePassword123');

      expect(user.email, 'parent@example.com');
      expect(session.token, 'token-123');
      expect(session.isAuthenticated, isTrue);

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.toString(), '$baseUrl/auth/login');
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(request.body), {
        'email': 'parent@example.com',
        'password': 'safePassword123',
      });
    });

    test('register sends the role', () async {
      final service = AuthApiService(client: clientWith((_) async => jsonResponse(authBody(), 201)));
      await service.register(email: 'a@example.com', password: 'safePassword123', role: 'teacher');
      expect(requests.single.url.path, '/api/v1/auth/register');
      expect(jsonDecode(requests.single.body)['role'], 'teacher');
      expect(session.isAuthenticated, isTrue);
    });

    test('failed login reports the backend message and stores no token', () async {
      final service = AuthApiService(
        client: clientWith((_) async => jsonResponse({'detail': 'Invalid email or password'}, 401)),
      );
      await expectLater(
        service.login(email: 'a@example.com', password: 'wrongPassword'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Invalid email or password')),
      );
      expect(session.isAuthenticated, isFalse);
      expect(session.expired, isFalse);
    });

    test('validation errors are turned into readable messages', () async {
      final service = AuthApiService(
        client: clientWith((_) async => jsonResponse({
              'detail': [
                {'msg': 'Value error, A valid email address is required'},
              ],
            }, 422)),
      );
      await expectLater(
        service.register(email: 'x@y.z', password: 'safePassword123', role: 'parent'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'A valid email address is required')),
      );
    });

    test('a response without a token is rejected', () async {
      final service = AuthApiService(
        client: clientWith((_) async => jsonResponse({'user': authBody()['user']})),
      );
      await expectLater(
        service.login(email: 'a@example.com', password: 'safePassword123'),
        throwsA(isA<ApiException>()),
      );
      expect(session.isAuthenticated, isFalse);
    });

    test('logout clears the token', () async {
      final service = AuthApiService(client: clientWith((_) async => jsonResponse(authBody())));
      await service.login(email: 'a@example.com', password: 'safePassword123');
      service.logout();
      expect(session.token, isNull);
    });
  });

  group('ApiClient', () {
    test('attaches the bearer token to protected requests', () async {
      session.signIn('secret-token', const AuthUser(id: 1, email: 'a@b.co', role: 'parent'));
      final api = ChildApiService(client: clientWith((_) async => jsonResponse([])));
      await api.getChildren();
      expect(requests.single.headers['Authorization'], 'Bearer secret-token');
    });

    test('does not send protected requests without a token', () async {
      final api = ChildApiService(client: clientWith((_) async => jsonResponse([])));
      await expectLater(api.getChildren(), throwsA(isA<ApiException>()));
      expect(requests, isEmpty);
    });

    test('a 401 response expires the session', () async {
      session.signIn('old-token', const AuthUser(id: 1, email: 'a@b.co', role: 'parent'));
      final api = ChildApiService(
        client: clientWith((_) async => jsonResponse({'detail': 'Invalid or expired access token'}, 401)),
      );
      await expectLater(
        api.getChildren(),
        throwsA(isA<ApiException>().having((e) => e.isUnauthorized, 'isUnauthorized', isTrue)),
      );
      expect(session.isAuthenticated, isFalse);
      expect(session.expired, isTrue);
    });

    test('connection failures produce a clear message', () async {
      session.signIn('t', const AuthUser(id: 1, email: 'a@b.co', role: 'parent'));
      final api = ChildApiService(
        client: clientWith((_) async => throw http.ClientException('Connection refused')),
      );
      await expectLater(
        api.getChildren(),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('Cannot reach'))),
      );
    });

    test('malformed responses are reported, not crashed on', () async {
      session.signIn('t', const AuthUser(id: 1, email: 'a@b.co', role: 'parent'));
      final notJson = ChildApiService(client: clientWith((_) async => http.Response('<html>', 200)));
      await expectLater(notJson.getChildren(), throwsA(isA<ApiException>()));

      final wrongShape = ChildApiService(
        client: clientWith((_) async => jsonResponse([
              {'id': '1', 'participant_code': 'demo-1'},
            ])),
      );
      await expectLater(wrongShape.getChildren(), throwsA(isA<ApiException>()));
    });
  });

  group('ChildApiService', () {
    setUp(() => session.signIn('t', const AuthUser(id: 1, email: 'a@b.co', role: 'parent')));

    test('sends assessment and activity requests in the backend vocabulary', () async {
      final api = ChildApiService(
        client: clientWith((request) async {
          if (request.url.path.endsWith('/activities/reading')) {
            return jsonResponse({
              'id': 3,
              'assessment_id': 11,
              'activity_key': 'reading',
              'status': 'completed',
            });
          }
          return jsonResponse({
            'id': 11,
            'child_id': 42,
            'assessment_type': 'screening',
            'status': request.method == 'PATCH' ? 'completed' : 'in_progress',
            'created_at': '2026-10-25T10:00:00Z',
            'activities': [],
            'has_result': false,
          }, request.method == 'POST' ? 201 : 200);
        }),
      );

      final started = await api.startAssessment(42);
      expect(started.id, 11);
      expect(started.status, AssessmentStatus.inProgress);
      expect(jsonDecode(requests.last.body), {'child_id': 42, 'assessment_type': 'screening'});

      final saved = await api.setActivityStatus(
        assessmentId: 11,
        activityKey: 'reading',
        status: ActivityStatus.completed,
      );
      expect(saved, ActivityStatus.completed);
      expect(requests.last.method, 'PUT');
      expect(requests.last.url.path, '/api/v1/assessments/11/activities/reading');
      expect(jsonDecode(requests.last.body), {'status': 'completed'});

      final completed = await api.updateAssessmentStatus(
        assessmentId: 11,
        status: AssessmentStatus.completed,
      );
      expect(completed.status, AssessmentStatus.completed);
      expect(requests.last.method, 'PATCH');
      expect(jsonDecode(requests.last.body), {'status': 'completed'});
    });

    test('finds the in-progress assessment for a child', () async {
      final api = ChildApiService(client: clientWith((_) async => jsonResponse([])));
      expect(await api.findActiveAssessment(42), isNull);
      expect(requests.single.url.queryParameters, {'child_id': '42', 'status': 'in_progress'});
    });

    test('backend conflict messages are passed through', () async {
      final api = ChildApiService(
        client: clientWith((_) async => jsonResponse(
              {'detail': 'All activities must be completed first. Remaining: memory'},
              409,
            )),
      );
      await expectLater(
        api.updateAssessmentStatus(assessmentId: 1, status: AssessmentStatus.completed),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('Remaining: memory'))),
      );
    });
  });
}
