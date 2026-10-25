/// Represents an individual screening session record associated with a child.
/// INTELLISCREEN is an academic screening tool, not a diagnostic application;
/// records store non-diagnostic observational checkpoints and rubric flags.
class AssessmentRecord {
  final String id;
  final String childId;
  final String title;
  final DateTime date;
  final String assessmentType;
  final String status;
  final String conductedBy;
  final String? observationalSummary;
  final bool isDemoRecord;

  const AssessmentRecord({
    required this.id,
    required this.childId,
    required this.title,
    required this.date,
    required this.assessmentType,
    required this.status,
    required this.conductedBy,
    this.observationalSummary,
    this.isDemoRecord = true,
  });

  /// Creates a copy of the assessment record with modified fields.
  AssessmentRecord copyWith({
    String? id,
    String? childId,
    String? title,
    DateTime? date,
    String? assessmentType,
    String? status,
    String? conductedBy,
    String? observationalSummary,
    bool? isDemoRecord,
  }) {
    return AssessmentRecord(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      title: title ?? this.title,
      date: date ?? this.date,
      assessmentType: assessmentType ?? this.assessmentType,
      status: status ?? this.status,
      conductedBy: conductedBy ?? this.conductedBy,
      observationalSummary: observationalSummary ?? this.observationalSummary,
      isDemoRecord: isDemoRecord ?? this.isDemoRecord,
    );
  }
}
