import 'package:flutter/foundation.dart';

import '../services/api_client.dart';
import '../services/child_api_service.dart';
import 'progress.dart';

export 'assessment_activity.dart';
export 'progress.dart';

/// Presentation-only details for the four demonstration profiles.
///
/// These are not stored in the backend; they are matched to backend profiles by
/// participant code. Ids, ages and registration dates come from the backend.
class DemoPresentation {
  final String name;
  final String grade;
  final String gender;
  final DateTime dateOfBirth;
  final String notes;

  const DemoPresentation({
    required this.name,
    required this.grade,
    required this.gender,
    required this.dateOfBirth,
    required this.notes,
  });
}

final Map<String, DemoPresentation> demoPresentations = {
  'demo-1': DemoPresentation(
    name: 'Leo M. (Demo Profile)',
    grade: 'Grade 2',
    gender: 'Male',
    dateOfBirth: DateTime(2019, 4, 12),
    notes: 'Demonstrates strong oral comprehension. Needs gentle pacing with b/d letter orientation.',
  ),
  'demo-2': DemoPresentation(
    name: 'Maya S. (Demo Profile)',
    grade: 'Grade 1',
    gender: 'Female',
    dateOfBirth: DateTime(2020, 7, 24),
    notes: 'Shows hesitation during rapid naming drills; reports hand tiredness during handwriting tasks.',
  ),
  'demo-3': DemoPresentation(
    name: 'Sam T. (Demo Profile)',
    grade: 'Kindergarten',
    gender: 'Prefer not to say',
    dateOfBirth: DateTime(2021, 2, 10),
    notes: 'Initial kindergarten baseline screening scheduled. Enjoys rhyming games and listening to stories.',
  ),
  'demo-4': DemoPresentation(
    name: 'Zoe K. (Demo Profile)',
    grade: 'Grade 3',
    gender: 'Female',
    dateOfBirth: DateTime(2018, 11, 5),
    notes: 'Consistent phonological decoding. Continues practicing fluid cursive stroke connections.',
  ),
};

/// A learner profile shown in the app: a backend profile plus presentation details.
/// All records in this demo are strictly illustrative and non-diagnostic.
class ChildRecord {
  /// Database id assigned by the backend; used for every API request.
  final int backendId;
  final String participantCode;
  final String name;
  final int? age;
  final DateTime? dateOfBirth;
  final String grade;
  final String gender;
  final String? notes;
  final DateTime? registeredDate;
  final bool isDemoRecord;

  const ChildRecord({
    required this.backendId,
    required this.participantCode,
    required this.name,
    this.age,
    this.dateOfBirth,
    required this.grade,
    required this.gender,
    this.notes,
    this.registeredDate,
    this.isDemoRecord = true,
  });

  /// Maps a backend profile to the UI, adding demo presentation details if known.
  factory ChildRecord.fromBackend(BackendChild child) {
    final presentation = child.isDemo ? demoPresentations[child.participantCode] : null;
    return ChildRecord(
      backendId: child.id,
      participantCode: child.participantCode,
      name: presentation?.name ?? child.participantCode,
      age: child.ageYears,
      dateOfBirth: presentation?.dateOfBirth,
      grade: presentation?.grade ?? 'Grade not recorded',
      gender: presentation?.gender ?? 'Not recorded',
      notes: presentation?.notes,
      registeredDate: child.createdAt,
      isDemoRecord: child.isDemo,
    );
  }

  String get ageLabel => age == null ? 'Age not recorded' : 'Age $age yrs';
}

enum LoadState { idle, loading, ready, error }

/// Child profiles and their saved progress, loaded from the backend.
class ChildrenStore extends ChangeNotifier {
  ChildrenStore({this._api});

  final ChildApiService? _api;
  ChildApiService get api => _api ?? ChildApiService();

  List<ChildRecord> _children = const [];
  Map<int, ChildProgress> _progress = const {};
  LoadState _state = LoadState.idle;
  String? _error;

  List<ChildRecord> get children => List.unmodifiable(_children);
  int get count => _children.length;
  LoadState get state => _state;
  String? get error => _error;

  ChildProgress? progressFor(ChildRecord child) => _progress[child.backendId];

  int get completedAssessmentCount =>
      _progress.values.fold(0, (sum, progress) => sum + progress.completedAssessments);

  int get inProgressAssessmentCount =>
      _progress.values.fold(0, (sum, progress) => sum + progress.inProgressAssessments);

  int get resultCount =>
      _progress.values.fold(0, (sum, progress) => sum + progress.resultsAvailable);

  /// Loads the profiles and each child's progress. Safe to call repeatedly.
  Future<void> load() async {
    if (_state == LoadState.loading) return;
    _state = LoadState.loading;
    _error = null;
    notifyListeners();

    try {
      final profiles = await api.getChildren();
      final children = profiles.map(ChildRecord.fromBackend).toList();
      final progress = await Future.wait(
        children.map((child) => api.getProgress(child.backendId)),
      );
      _children = children;
      _progress = {for (final item in progress) item.childId: item};
      _state = LoadState.ready;
    } on ApiException catch (error) {
      _state = LoadState.error;
      _error = error.message;
    }
    notifyListeners();
  }

  /// Reloads one child's progress from the backend; errors are rethrown.
  Future<ChildProgress> refreshProgress(ChildRecord child) async {
    final progress = await api.getProgress(child.backendId);
    _progress = {..._progress, child.backendId: progress};
    notifyListeners();
    return progress;
  }

  /// Forgets all loaded data, e.g. after signing out.
  void clear() {
    _children = const [];
    _progress = const {};
    _state = LoadState.idle;
    _error = null;
    notifyListeners();
  }
}

/// Global shared instance for the current application session.
final ChildrenStore childrenStore = ChildrenStore();
