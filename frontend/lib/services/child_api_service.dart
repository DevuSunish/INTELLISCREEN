import '../models/assessment_activity.dart';
import '../models/json_utils.dart';
import '../models/progress.dart';
import 'api_client.dart';

/// Child profiles, assessments, activity statuses and progress.
class ChildApiService {
  ChildApiService({this._client});

  final ApiClient? _client;
  ApiClient get client => _client ?? ApiClient.shared;

  Future<List<BackendChild>> getChildren() async {
    final data = await client.get('/children/');
    return client.parse(
      () => asJsonList(data).map((item) => BackendChild.fromJson(asJsonMap(item))).toList(),
    );
  }

  /// The account's in-progress assessment for this child, if there is one.
  Future<AssessmentSummary?> findActiveAssessment(int childId) async {
    final data = await client.get('/assessments/', query: {
      'child_id': '$childId',
      'status': AssessmentStatus.inProgress.apiValue,
    });
    final assessments = client.parse(
      () => asJsonList(data)
          .map((item) => AssessmentSummary.fromAssessmentJson(asJsonMap(item)))
          .toList(),
    );
    return assessments.isEmpty ? null : assessments.last;
  }

  /// Starts an assessment; the backend returns the open one if it already exists.
  Future<AssessmentSummary> startAssessment(int childId) async {
    final data = await client.post('/assessments/', {
      'child_id': childId,
      'assessment_type': 'screening',
    });
    return client.parse(() => AssessmentSummary.fromAssessmentJson(asJsonMap(data)));
  }

  Future<ActivityStatus> setActivityStatus({
    required int assessmentId,
    required String activityKey,
    required ActivityStatus status,
  }) async {
    final data = await client.put(
      '/assessments/$assessmentId/activities/${Uri.encodeComponent(activityKey)}',
      {'status': status.apiValue},
    );
    return client.parse(
      () => ActivityStatusApi.fromApi(readString(asJsonMap(data), 'status')),
    );
  }

  Future<AssessmentSummary> updateAssessmentStatus({
    required int assessmentId,
    required AssessmentStatus status,
  }) async {
    final data = await client.patch(
      '/assessments/$assessmentId/status',
      {'status': status.apiValue},
    );
    return client.parse(() => AssessmentSummary.fromAssessmentJson(asJsonMap(data)));
  }

  Future<ChildProgress> getProgress(int childId) async {
    final data = await client.get('/progress/$childId');
    return client.parse(() => ChildProgress.fromJson(asJsonMap(data)));
  }
}
