import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/child_api_service.dart';

void main() {
  test('ChildApiService can retrieve children from the backend', () async {
    final service = ChildApiService();

    final children = await service.getChildren();

    expect(children, isA<List<Map<String, dynamic>>>());
    expect(children, isNotEmpty);
    
  });
}