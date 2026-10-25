// Strict readers for decoded JSON; they throw FormatException on bad shapes.

Map<String, dynamic> asJsonMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('Expected a JSON object');
}

List<dynamic> asJsonList(Object? value) {
  if (value is List) return value;
  throw const FormatException('Expected a JSON array');
}

int readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected integer "$key"');
}

int? readOptionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value is int) return value as int?;
  throw FormatException('Expected integer "$key"');
}

String readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected string "$key"');
}

String? readOptionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Expected string "$key"');
}

double? readOptionalDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw FormatException('Expected number "$key"');
}

bool readBool(Map<String, dynamic> json, String key, {bool fallback = false}) {
  final value = json[key];
  if (value == null) return fallback;
  if (value is bool) return value;
  throw FormatException('Expected boolean "$key"');
}

/// Parses an ISO-8601 timestamp into local time.
DateTime? readOptionalDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return DateTime.parse(value).toLocal();
  throw FormatException('Expected timestamp "$key"');
}

DateTime readDate(Map<String, dynamic> json, String key) {
  return readOptionalDate(json, key) ?? (throw FormatException('Missing timestamp "$key"'));
}

String formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';
