import 'package:flutter/material.dart';
import 'assessment_record.dart';
import 'assessment_session.dart';

export 'assessment_record.dart';
export 'assessment_session.dart';

/// Represents a learner profile record for academic screening and progress monitoring.
/// All records in this demo session are strictly illustrative and non-diagnostic.
class ChildRecord {
  final String id;
  final String name;
  final int age;
  final DateTime? dateOfBirth;
  final String grade;
  final String gender;
  final String assessmentStatus;
  final String? notes;
  final DateTime registeredDate;
  final bool isDemoRecord;

  const ChildRecord({
    required this.id,
    required this.name,
    required this.age,
    this.dateOfBirth,
    required this.grade,
    required this.gender,
    required this.assessmentStatus,
    this.notes,
    required this.registeredDate,
    this.isDemoRecord = true,
  });

  /// Creates a copy of the child record with modified fields.
  ChildRecord copyWith({
    String? id,
    String? name,
    int? age,
    DateTime? dateOfBirth,
    String? grade,
    String? gender,
    String? assessmentStatus,
    String? notes,
    DateTime? registeredDate,
    bool? isDemoRecord,
  }) {
    return ChildRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      grade: grade ?? this.grade,
      gender: gender ?? this.gender,
      assessmentStatus: assessmentStatus ?? this.assessmentStatus,
      notes: notes ?? this.notes,
      registeredDate: registeredDate ?? this.registeredDate,
      isDemoRecord: isDemoRecord ?? this.isDemoRecord,
    );
  }
}

/// In-memory store holding temporary demo child records and associated screening history.
/// Uses standard Flutter ChangeNotifier so UI updates automatically.
class ChildrenStore extends ChangeNotifier {
  final List<ChildRecord> _children = [
    ChildRecord(
      id: 'demo-1',
      name: 'Leo M. (Demo Profile)',
      age: 7,
      dateOfBirth: DateTime(2019, 4, 12),
      grade: 'Grade 2',
      gender: 'Male',
      assessmentStatus: 'Screening Up to Date (Demo)',
      notes: 'Demonstrates strong oral comprehension. Needs gentle pacing with b/d letter orientation.',
      registeredDate: DateTime(2026, 9, 15),
    ),
    ChildRecord(
      id: 'demo-2',
      name: 'Maya S. (Demo Profile)',
      age: 6,
      dateOfBirth: DateTime(2020, 7, 24),
      grade: 'Grade 1',
      gender: 'Female',
      assessmentStatus: 'Follow-up Recommended (Demo)',
      notes: 'Shows hesitation during rapid naming drills; reports hand tiredness during handwriting tasks.',
      registeredDate: DateTime(2026, 10, 2),
    ),
    ChildRecord(
      id: 'demo-3',
      name: 'Sam T. (Demo Profile)',
      age: 5,
      dateOfBirth: DateTime(2021, 2, 10),
      grade: 'Kindergarten',
      gender: 'Prefer not to say',
      assessmentStatus: 'Not Screened Yet (Demo)',
      notes: 'Initial kindergarten baseline screening scheduled. Enjoys rhyming games and listening to stories.',
      registeredDate: DateTime(2026, 10, 20),
    ),
    ChildRecord(
      id: 'demo-4',
      name: 'Zoe K. (Demo Profile)',
      age: 8,
      dateOfBirth: DateTime(2018, 11, 5),
      grade: 'Grade 3',
      gender: 'Female',
      assessmentStatus: 'Screening Up to Date (Demo)',
      notes: 'Consistent phonological decoding. Continues practicing fluid cursive stroke connections.',
      registeredDate: DateTime(2026, 8, 28),
    ),
  ];

  /// In-memory store of screening session records, each associated with a specific childId.
  final List<AssessmentRecord> _assessments = [
    // Completed demo record for Leo M. (demo-1)
    AssessmentRecord(
      id: 'assess-1',
      childId: 'demo-1',
      title: 'Autumn Baseline Screening (Demo)',
      date: DateTime(2026, 9, 20),
      assessmentType: 'Phonological Awareness & Letter Formation',
      status: 'Completed (Demo Log)',
      conductedBy: 'Classroom Educator',
      observationalSummary:
          'Completed oral letter-sound checklist and 3-line pencil writing sample. Non-diagnostic observation: letter orientation b/d showed intermittent hesitation.',
    ),
    // Completed demo record for Maya S. (demo-2)
    AssessmentRecord(
      id: 'assess-2',
      childId: 'demo-2',
      title: 'Early Literacy & Motor Screening (Demo)',
      date: DateTime(2026, 10, 5),
      assessmentType: 'Rapid Automatized Naming & Pencil Grip Observation',
      status: 'Follow-up Recommended (Demo)',
      conductedBy: 'Reading Specialist',
      observationalSummary:
          'Pencil grasp fatigue observed after 2 minutes of continuous handwriting. Rapid naming drills showed slower retrieval pace.',
    ),
    // Completed demo record for Zoe K. (demo-4)
    AssessmentRecord(
      id: 'assess-3',
      childId: 'demo-4',
      title: 'Beginning-of-Year Fluency Screening (Demo)',
      date: DateTime(2026, 9, 5),
      assessmentType: 'Reading Fluency & Cursive Stroke Check',
      status: 'Screening Up to Date (Demo)',
      conductedBy: 'Classroom Educator',
      observationalSummary:
          'Demonstrated solid phonological decoding and rhythm. Continues working on cursive stroke consistency.',
    ),
    // NOTE: Sam T. (demo-3) intentionally has 0 assessment records to display the empty state.
  ];

  /// Unmodifiable view of currently registered children.
  List<ChildRecord> get children => List.unmodifiable(_children);

  /// Total count of registered children in current session.
  int get count => _children.length;

  /// Adds a new child profile to temporary in-memory session state.
  void addChild(ChildRecord child) {
    _children.insert(0, child);
    notifyListeners();
  }

  /// Retrieves assessment records associated with a specific child.
  List<AssessmentRecord> getAssessmentsForChild(String childId) {
    return _assessments.where((record) => record.childId == childId).toList();
  }

  /// Adds a new assessment record associated with a child to in-memory state.
  void addAssessment(AssessmentRecord assessment) {
    _assessments.insert(0, assessment);

    // Update child's status if needed
    final index = _children.indexWhere((c) => c.id == assessment.childId);
    if (index != -1) {
      _children[index] = _children[index].copyWith(
        assessmentStatus: assessment.status,
      );
    }

    notifyListeners();
  }

  /// Active in-memory assessment sessions keyed by childId.
  final Map<String, AssessmentSession> _sessions = {};

  /// Retrieves or initializes an active assessment session for a child.
  AssessmentSession getOrCreateSessionForChild(ChildRecord child) {
    if (!_sessions.containsKey(child.id)) {
      _sessions[child.id] = AssessmentSession(
        id: 'session-${child.id}',
        childId: child.id,
        childName: child.name,
        startedAt: DateTime.now(),
        activities: AssessmentSession.createDefaultActivities(),
      );
    }
    return _sessions[child.id]!;
  }

  /// Updates status for a specific screening activity.
  void updateActivityStatus(String childId, String activityId, ActivityStatus status) {
    if (_sessions.containsKey(childId)) {
      final session = _sessions[childId]!;
      final index = session.activities.indexWhere((a) => a.id == activityId);
      if (index != -1) {
        session.activities[index].status = status;
        notifyListeners();
      }
    }
  }

  /// Completes an active screening session, logs an AssessmentRecord, and updates the child.
  void completeSession(String childId) {
    if (_sessions.containsKey(childId)) {
      final session = _sessions[childId]!;
      session.isCompleted = true;
      for (final a in session.activities) {
        a.status = ActivityStatus.completed;
      }

      // Add a completed assessment record to history
      final record = AssessmentRecord(
        id: 'assess-${DateTime.now().millisecondsSinceEpoch}',
        childId: childId,
        title: 'Full 5-Protocol Screening Session (Demo)',
        date: DateTime.now(),
        assessmentType: 'Handwriting, Reading, Phonology, RAN, & Memory',
        status: 'Completed (Demo Log)',
        conductedBy: 'Classroom Screener / Parent',
        observationalSummary:
            'Completed all five screening modules: Handwriting, Reading, Phonological Awareness, RAN, and Memory. Observational indicators recorded in temporary session state. Non-diagnostic screening output.',
      );
      addAssessment(record);
    }
  }

  /// Resets an active session to a fresh "Not Started" state for demo testing.
  void resetSession(String childId, String childName) {
    _sessions[childId] = AssessmentSession(
      id: 'session-$childId',
      childId: childId,
      childName: childName,
      startedAt: DateTime.now(),
      activities: AssessmentSession.createDefaultActivities(),
    );
    notifyListeners();
  }
}

/// Global shared instance for the current application session.
final ChildrenStore childrenStore = ChildrenStore();
