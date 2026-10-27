import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/json_utils.dart';

/// Location of the INTELLISCREEN backend.
///
/// Override with `--dart-define=INTELLISCREEN_API_URL=http://host:8000/api/v1`.
class ApiConfig {
  static const String _override = String.fromEnvironment('INTELLISCREEN_API_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    // The Android emulator reaches the host machine through 10.0.2.2.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    // Linux desktop (and web) talk to a backend on the same machine.
    return 'http://127.0.0.1:8000/api/v1';
  }
}

/// A failed API call with a message suitable for showing to the user.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// The signed-in account.
class AuthUser {
  final int id;
  final String email;
  final String role;

  const AuthUser({required this.id, required this.email, required this.role});

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: readInt(json, 'id'),
        email: readString(json, 'email'),
        role: readString(json, 'role'),
      );
}

/// Holds the access token for the current app run.
///
/// The token is kept in memory only: secure storage on Linux needs libsecret,
/// which is not a dependency of this app, so users sign in again after a restart.
class AuthSession extends ChangeNotifier {
  static final AuthSession instance = AuthSession();

  String? _token;
  AuthUser? _user;
  bool _expired = false;

  String? get token => _token;
  AuthUser? get user => _user;
  bool get isAuthenticated => _token != null;

  /// True when the session ended because the server rejected the token.
  bool get expired => _expired;

  void signIn(String token, AuthUser user) {
    _token = token;
    _user = user;
    _expired = false;
    notifyListeners();
  }

  void signOut() {
    if (_token == null && !_expired) return;
    _token = null;
    _user = null;
    _expired = false;
    notifyListeners();
  }

  void expire() {
    if (_token == null) return;
    _token = null;
    _user = null;
    _expired = true;
    notifyListeners();
  }
}

/// Shared HTTP client: one base URL, bearer token attachment and error handling.
class ApiClient {
  ApiClient({
    http.Client? httpClient,
    String? baseUrl,
    AuthSession? session,
    this.timeout = const Duration(seconds: 15),
  })  : _http = httpClient ?? http.Client(),
        baseUrl = baseUrl ?? ApiConfig.baseUrl,
        session = session ?? AuthSession.instance;

  /// Instance used by the app's services; tests may replace it.
  static ApiClient shared = ApiClient();

  final http.Client _http;
  final String baseUrl;
  final AuthSession session;
  final Duration timeout;

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, Object body, {bool authenticated = true}) =>
      _send('POST', path, body: body, authenticated: authenticated);

  Future<dynamic> put(String path, Object body) => _send('PUT', path, body: body);

  Future<dynamic> patch(String path, Object body) => _send('PATCH', path, body: body);

  /// Runs [parse] on response data, reporting malformed data as an [ApiException].
  T parse<T>(T Function() parse) {
    try {
      return parse();
    } on FormatException {
      throw const ApiException('Unexpected response from the server.');
    }
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool authenticated = true,
  }) async {
    final token = session.token;
    if (authenticated && token == null) {
      throw const ApiException('Please sign in to continue.', statusCode: 401);
    }

    var uri = Uri.parse('$baseUrl$path');
    if (query != null) uri = uri.replace(queryParameters: query);

    final request = http.Request(method, uri)..headers['Accept'] = 'application/json';
    if (authenticated) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await _http.send(request).then(http.Response.fromStream).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        'The INTELLISCREEN server did not respond in time. Please try again.',
      );
    } on http.ClientException {
      throw ApiException(
        'Cannot reach the INTELLISCREEN server at $baseUrl. '
        'Check that the backend is running, then retry.',
      );
    }

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    final Object? decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      if (ok) throw const ApiException('Unexpected response from the server.');
      throw ApiException('Request failed (HTTP ${response.statusCode}).',
          statusCode: response.statusCode);
    }
    if (ok) return decoded;

    if (response.statusCode == 401 && authenticated) {
      session.expire();
      throw const ApiException(
        'Your session has expired. Please sign in again.',
        statusCode: 401,
      );
    }
    throw ApiException(
      _errorDetail(decoded) ?? 'Request failed (HTTP ${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  /// Extracts FastAPI's `detail`, which is a string or a list of validation errors.
  static String? _errorDetail(Object? decoded) {
    if (decoded is! Map) return null;
    final detail = decoded['detail'];
    if (detail is String && detail.isNotEmpty) return detail;
    if (detail is List) {
      final messages = detail
          .whereType<Map>()
          .map((error) => error['msg'])
          .whereType<String>()
          .map((message) => message.replaceFirst('Value error, ', ''))
          .toList();
      if (messages.isNotEmpty) return messages.join('\n');
    }
    return null;
  }
}
