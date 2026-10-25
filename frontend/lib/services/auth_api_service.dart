import '../models/json_utils.dart';
import 'api_client.dart';

class AuthApiService {
  AuthApiService({this._client});

  final ApiClient? _client;
  ApiClient get client => _client ?? ApiClient.shared;

  Future<AuthUser> login({
    required String email,
    required String password,
  }) {
    return _authenticate('/auth/login', {'email': email, 'password': password});
  }

  Future<AuthUser> register({
    required String email,
    required String password,
    required String role,
  }) {
    return _authenticate('/auth/register', {
      'email': email,
      'password': password,
      'role': role,
    });
  }

  void logout() => client.session.signOut();

  Future<AuthUser> _authenticate(String path, Map<String, String> body) async {
    final data = await client.post(path, body, authenticated: false);
    final (token, user) = client.parse(() {
      final json = asJsonMap(data);
      final token = readString(json, 'access_token');
      if (token.isEmpty) throw const FormatException('Empty access token');
      return (token, AuthUser.fromJson(asJsonMap(json['user'])));
    });
    client.session.signIn(token, user);
    return user;
  }
}
