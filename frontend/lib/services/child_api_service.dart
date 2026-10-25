import 'dart:convert';

import 'package:http/http.dart' as http;

class ChildApiService {
  // Android emulator uses this address to reach your Ubuntu machine.
  // For Flutter Web or a Linux desktop app, use 127.0.0.1 instead.
  static const String baseUrl = 'http://127.0.0.1:8000/api/v1';

  Future<List<Map<String, dynamic>>> getChildren() async {
    final response = await http.get(
      Uri.parse('$baseUrl/children/'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;

      return data
          .map((child) => Map<String, dynamic>.from(child as Map))
          .toList();
    }

    throw Exception(
      'Failed to load children: ${response.statusCode} ${response.body}',
    );
  }


  Future<Map<String, dynamic>> createChild({
    required String participantCode,
    int? ageYears,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/children/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'participant_code': participantCode,
        'age_years': ageYears,
      }),
    );

    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(
        jsonDecode(response.body) as Map,
      );
    }

    throw Exception(
      'Failed to create child: ${response.statusCode} ${response.body}',
    );
  }
}
