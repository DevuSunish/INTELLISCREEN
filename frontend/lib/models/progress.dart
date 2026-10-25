import 'assessment_activity.dart';
import 'json_utils.dart';

/// A child profile as stored in the backend.
class BackendChild {
  final int id;
  final String participantCode;
  final int? ageYears;
  final bool isDemo;
  final DateTime? createdAt;

  const BackendChild({
    required this.id,
    required this.participantCode,
    this.ageYears,
    this.isDemo = false,
    this.createdAt,
  });

  factory BackendChild.fromJson(Map<String, dynamic> json) => BackendChild(
        id: readInt(json, 'id'),
        participantCode: readString(json, 'participant_code'),
        ageYears: readOptionalInt(json, 'age_years'),
        isDemo: readBool(json, 'is_demo'),
        createdAt: readOptionalDate(json, 'created_at'),
      );
}

/// Lifecycle of a saved assessment. "Not started" means no assessment exists.
enum AssessmentStatus { inProgress, completed, cancelled }

extension AssessmentStatusApi on AssessmentStatus {
  String get apiValue {
    switch (this) {
      case AssessmentStatus.inProgress:
        return 'in_progress';
      case AssessmentStatus.completed:
        return 'completed';
      case AssessmentStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case AssessmentStatus.inProgress:
        return 'In Progress';
      case AssessmentStatus.completed:
        return 'Completed';
      case AssessmentStatus.cancelled:
        return 'Cancelled';
    }
  }

  static AssessmentStatus fromApi(String value) {
    for (final status in AssessmentStatus.values) {
      if (status.apiValue == value) return status;
    }
    throw FormatException('Unknown assessment status "$value"');
  }
}

/// Screening-model inference state of a completed assessment.
/// Null on an assessment means inference was never requested.
enum InferenceStatus { pending, completed, failed }

InferenceStatus? _inferenceStatusFromApi(Object? value) {
  if (value == null) return null;
  for (final status in InferenceStatus.values) {
    if (status.name == value) return status;
  }
  throw FormatException('Unknown inference status "$value"');
}

/// Output of the screening model, present only when one was actually saved.
class ScreeningResultSummary {
  final int id;
  final String? modelVersion;
  final String? resultCategory;
  final double? confidenceScore;
  final Map<String, double> modalityScores;
  final DateTime? createdAt;

  const ScreeningResultSummary({
    required this.id,
    this.modelVersion,
    this.resultCategory,
    this.confidenceScore,
    this.modalityScores = const {},
    this.createdAt,
  });

  factory ScreeningResultSummary.fromJson(Map<String, dynamic> json) {
    final scores = json['modality_scores'];
    return ScreeningResultSummary(
      id: readInt(json, 'id'),
      modelVersion: readOptionalString(json, 'model_version'),
      resultCategory: readOptionalString(json, 'result_category'),
      confidenceScore: readOptionalDouble(json, 'confidence_score'),
      modalityScores: scores == null
          ? const {}
          : {
              for (final entry in asJsonMap(scores).entries)
                entry.key: entry.value is num
                    ? (entry.value as num).toDouble()
                    : throw FormatException('Expected number for modality "${entry.key}"'),
            },
      createdAt: readOptionalDate(json, 'created_at'),
    );
  }
}

/// A saved assessment with its persisted activity statuses.
class AssessmentSummary {
  final int id;
  final String assessmentType;
  final AssessmentStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final Map<String, ActivityStatus> activityStatuses;
  final InferenceStatus? inferenceStatus;
  final ScreeningResultSummary? result;
  final bool hasResult;

  const AssessmentSummary({
    required this.id,
    required this.assessmentType,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.activityStatuses = const {},
    this.inferenceStatus,
    this.result,
    this.hasResult = false,
  });

  /// Parses a response of the `/assessments` endpoints.
  factory AssessmentSummary.fromAssessmentJson(Map<String, dynamic> json) {
    return AssessmentSummary(
      id: readInt(json, 'id'),
      assessmentType: readString(json, 'assessment_type'),
      status: AssessmentStatusApi.fromApi(readString(json, 'status')),
      createdAt: readDate(json, 'created_at'),
      updatedAt: readOptionalDate(json, 'updated_at'),
      completedAt: readOptionalDate(json, 'completed_at'),
      activityStatuses: _parseActivities(json['activities']),
      inferenceStatus: _inferenceStatusFromApi(json['inference_status']),
      hasResult: readBool(json, 'has_result'),
    );
  }

  /// Parses an entry of the progress endpoint's `assessment_history`.
  factory AssessmentSummary.fromHistoryJson(Map<String, dynamic> json) {
    final result = json['result'];
    return AssessmentSummary(
      id: readInt(json, 'assessment_id'),
      assessmentType: readString(json, 'assessment_type'),
      status: AssessmentStatusApi.fromApi(readString(json, 'assessment_status')),
      createdAt: readDate(json, 'assessment_date'),
      updatedAt: readOptionalDate(json, 'updated_at'),
      completedAt: readOptionalDate(json, 'completed_at'),
      activityStatuses: _parseActivities(json['activities']),
      inferenceStatus: _inferenceStatusFromApi(json['inference_status']),
      result: result == null ? null : ScreeningResultSummary.fromJson(asJsonMap(result)),
      hasResult: result != null,
    );
  }

  static Map<String, ActivityStatus> _parseActivities(Object? value) {
    if (value == null) return const {};
    return {
      for (final item in asJsonList(value).map(asJsonMap))
        readString(item, 'activity_key'): ActivityStatusApi.fromApi(readString(item, 'status')),
    };
  }

  ActivityStatus statusOf(String activityKey) =>
      activityStatuses[activityKey] ?? ActivityStatus.notStarted;

  int get completedActivityCount => ScreeningActivities.all
      .where((activity) => statusOf(activity.id) == ActivityStatus.completed)
      .length;

  AssessmentSummary copyWithActivity(String activityKey, ActivityStatus status) {
    return AssessmentSummary(
      id: id,
      assessmentType: assessmentType,
      status: this.status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      completedAt: completedAt,
      activityStatuses: {...activityStatuses, activityKey: status},
      inferenceStatus: inferenceStatus,
      result: result,
      hasResult: hasResult,
    );
  }
}

/// Saved progress of one child for the signed-in account.
class ChildProgress {
  final int childId;
  final String participantCode;
  final int totalAssessments;
  final int completedAssessments;
  final int inProgressAssessments;
  final int resultsAvailable;

  /// Newest first.
  final List<AssessmentSummary> history;

  const ChildProgress({
    required this.childId,
    required this.participantCode,
    required this.totalAssessments,
    required this.completedAssessments,
    required this.inProgressAssessments,
    required this.resultsAvailable,
    required this.history,
  });

  factory ChildProgress.fromJson(Map<String, dynamic> json) => ChildProgress(
        childId: readInt(json, 'child_id'),
        participantCode: readString(json, 'participant_code'),
        totalAssessments: readInt(json, 'total_assessments'),
        completedAssessments: readInt(json, 'completed_assessments'),
        inProgressAssessments: readInt(json, 'in_progress_assessments'),
        resultsAvailable: readInt(json, 'results_available'),
        history: asJsonList(json['assessment_history'])
            .map((item) => AssessmentSummary.fromHistoryJson(asJsonMap(item)))
            .toList(),
      );

  /// Short status for profile cards, derived only from saved records.
  String get statusSummary {
    if (inProgressAssessments > 0) return 'Assessment in progress';
    final lastCompleted = history
        .where((assessment) => assessment.status == AssessmentStatus.completed)
        .firstOrNull;
    if (lastCompleted != null) {
      final date = lastCompleted.completedAt ?? lastCompleted.createdAt;
      return 'Last screening completed ${formatDate(date)}';
    }
    return 'Not screened yet';
  }
}
