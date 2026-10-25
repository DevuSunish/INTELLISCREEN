import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/child_record.dart';

Map<String, dynamic> progressJson() => {
      'child_id': 12,
      'participant_code': 'demo-2',
      'total_assessments': 2,
      'completed_assessments': 1,
      'in_progress_assessments': 1,
      'results_available': 1,
      'assessment_history': [
        {
          'assessment_id': 31,
          'assessment_type': 'screening',
          'assessment_status': 'in_progress',
          'assessment_date': '2026-10-25T09:00:00Z',
          'updated_at': '2026-10-25T09:05:00Z',
          'completed_at': null,
          'activities': [
            {'id': 1, 'assessment_id': 31, 'activity_key': 'ran', 'status': 'in_progress'},
          ],
          'result': null,
        },
        {
          'assessment_id': 30,
          'assessment_type': 'screening',
          'assessment_status': 'completed',
          'assessment_date': '2026-10-20T09:00:00Z',
          'completed_at': '2026-10-20T09:30:00Z',
          'activities': [
            for (final key in ['handwriting', 'reading', 'phonological', 'ran', 'memory'])
              {'id': 2, 'assessment_id': 30, 'activity_key': key, 'status': 'completed'},
          ],
          'result': {
            'id': 5,
            'assessment_id': 30,
            'model_version': 'model-v1',
            'result_category': 'monitor',
            'confidence_score': 0.8,
            'modality_scores': {'reading': 0.7, 'writing': 1},
            'created_at': '2026-10-20T09:31:00Z',
          },
        },
      ],
    };

void main() {
  group('ChildRecord.fromBackend', () {
    test('maps demo profiles by participant code using the backend id', () {
      final record = ChildRecord.fromBackend(
        BackendChild(id: 57, participantCode: 'demo-3', ageYears: 5, isDemo: true),
      );
      expect(record.backendId, 57);
      expect(record.participantCode, 'demo-3');
      expect(record.name, 'Sam T. (Demo Profile)');
      expect(record.grade, 'Kindergarten');
      expect(record.age, 5);
      expect(record.isDemoRecord, isTrue);
    });

    test('does not invent details for profiles without demo presentation', () {
      final record = ChildRecord.fromBackend(
        BackendChild(id: 9, participantCode: 'private-1', isDemo: false),
      );
      expect(record.name, 'private-1');
      expect(record.ageLabel, 'Age not recorded');
      expect(record.notes, isNull);
      expect(record.dateOfBirth, isNull);
    });

    test('all four demo children have presentation details', () {
      expect(demoPresentations.keys, ['demo-1', 'demo-2', 'demo-3', 'demo-4']);
      expect(
        demoPresentations.values.map((p) => p.name.split(' (').first),
        ['Leo M.', 'Maya S.', 'Sam T.', 'Zoe K.'],
      );
    });

    test('parses backend child JSON', () {
      final child = BackendChild.fromJson({
        'id': 3,
        'participant_code': 'demo-1',
        'age_years': 7,
        'is_demo': true,
        'created_at': '2026-10-25T07:46:04Z',
      });
      expect(child.id, 3);
      expect(child.isDemo, isTrue);
      expect(child.createdAt!.isUtc, isFalse);
      expect(child.createdAt!.toUtc(), DateTime.utc(2026, 10, 25, 7, 46, 4));
    });
  });

  group('status mapping', () {
    test('activity statuses round-trip through the API vocabulary', () {
      for (final status in ActivityStatus.values) {
        expect(ActivityStatusApi.fromApi(status.apiValue), status);
      }
      expect(ActivityStatus.notStarted.apiValue, 'not_started');
      expect(() => ActivityStatusApi.fromApi('done'), throwsFormatException);
    });

    test('assessment statuses round-trip through the API vocabulary', () {
      for (final status in AssessmentStatus.values) {
        expect(AssessmentStatusApi.fromApi(status.apiValue), status);
      }
      expect(() => AssessmentStatusApi.fromApi('pending'), throwsFormatException);
    });

    test('activity keys match the backend', () {
      expect(
        ScreeningActivities.all.map((a) => a.id),
        ['handwriting', 'reading', 'phonological', 'ran', 'memory'],
      );
    });
  });

  group('ChildProgress', () {
    test('parses history, activity statuses and results', () {
      final progress = ChildProgress.fromJson(progressJson());
      expect(progress.childId, 12);
      expect(progress.totalAssessments, 2);
      expect(progress.history.map((a) => a.id), [31, 30]);

      final open = progress.history.first;
      expect(open.status, AssessmentStatus.inProgress);
      expect(open.statusOf('ran'), ActivityStatus.inProgress);
      expect(open.statusOf('memory'), ActivityStatus.notStarted);
      expect(open.result, isNull);
      expect(open.hasResult, isFalse);

      final done = progress.history.last;
      expect(done.completedActivityCount, 5);
      expect(done.result!.resultCategory, 'monitor');
      expect(done.result!.confidenceScore, 0.8);
      expect(done.result!.modalityScores, {'reading': 0.7, 'writing': 1.0});
      expect(progress.statusSummary, 'Assessment in progress');
    });

    test('status summary reflects saved records only', () {
      final empty = ChildProgress.fromJson({
        ...progressJson(),
        'total_assessments': 0,
        'completed_assessments': 0,
        'in_progress_assessments': 0,
        'results_available': 0,
        'assessment_history': [],
      });
      expect(empty.statusSummary, 'Not screened yet');

      final json = progressJson();
      json['in_progress_assessments'] = 0;
      (json['assessment_history'] as List).removeAt(0);
      expect(ChildProgress.fromJson(json).statusSummary, startsWith('Last screening completed'));
    });

    test('rejects malformed responses', () {
      final json = progressJson()..remove('assessment_history');
      expect(() => ChildProgress.fromJson(json), throwsFormatException);

      final badStatus = progressJson();
      (badStatus['assessment_history'] as List).first['assessment_status'] = 'pending';
      expect(() => ChildProgress.fromJson(badStatus), throwsFormatException);
    });

    test('copyWithActivity updates a single activity', () {
      final open = ChildProgress.fromJson(progressJson()).history.first;
      final updated = open.copyWithActivity('memory', ActivityStatus.completed);
      expect(updated.statusOf('memory'), ActivityStatus.completed);
      expect(updated.statusOf('ran'), ActivityStatus.inProgress);
      expect(open.statusOf('memory'), ActivityStatus.notStarted);
    });
  });
}
