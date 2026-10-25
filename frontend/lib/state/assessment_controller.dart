import 'package:flutter/foundation.dart';

import '../models/child_record.dart';
import '../services/api_client.dart';
import '../services/child_api_service.dart';

/// State of the assessment workflow for one child, backed by the API.
///
/// Every change is sent to the backend first; local state only reflects what
/// the backend confirmed. Action methods throw [ApiException] on failure.
class AssessmentController extends ChangeNotifier {
  AssessmentController({required this.child, ChildApiService? api})
      : _api = api ?? ChildApiService();

  final ChildRecord child;
  final ChildApiService _api;

  List<AssessmentActivity> get activities => ScreeningActivities.all;

  AssessmentSummary? _assessment;
  bool _loading = false;
  bool _busy = false;
  String? _loadError;

  /// The in-progress (or just finished) assessment, if any.
  AssessmentSummary? get assessment => _assessment;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get loadError => _loadError;

  bool get hasActiveAssessment => _assessment?.status == AssessmentStatus.inProgress;

  ActivityStatus statusOf(String activityKey) =>
      _assessment?.statusOf(activityKey) ?? ActivityStatus.notStarted;

  int get completedCount => _assessment?.completedActivityCount ?? 0;

  bool get allActivitiesCompleted => completedCount == activities.length;

  String get statusLabel => _assessment?.status.label ?? 'Not Started';

  /// Resumes the account's in-progress assessment for this child, if any.
  Future<void> load() async {
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      _assessment = await _api.findActiveAssessment(child.backendId);
    } on ApiException catch (error) {
      _loadError = error.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> start() => _run(() async {
        _assessment = await _api.startAssessment(child.backendId);
      });

  Future<void> setActivityStatus(String activityKey, ActivityStatus status) => _run(() async {
        final current = _assessment;
        if (current == null || current.status != AssessmentStatus.inProgress) {
          throw const ApiException('Start the assessment before recording activity progress.');
        }
        final saved = await _api.setActivityStatus(
          assessmentId: current.id,
          activityKey: activityKey,
          status: status,
        );
        _assessment = current.copyWithActivity(activityKey, saved);
      });

  Future<void> complete() => _setAssessmentStatus(AssessmentStatus.completed);

  Future<void> cancel() => _setAssessmentStatus(AssessmentStatus.cancelled);

  Future<void> _setAssessmentStatus(AssessmentStatus status) => _run(() async {
        final current = _assessment;
        if (current == null) {
          throw const ApiException('There is no assessment in progress.');
        }
        _assessment = await _api.updateAssessmentStatus(
          assessmentId: current.id,
          status: status,
        );
      });

  /// Runs one request at a time so repeated taps cannot send duplicates.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
