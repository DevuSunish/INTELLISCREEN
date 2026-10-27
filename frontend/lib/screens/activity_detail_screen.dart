import 'package:flutter/material.dart';
import '../models/child_record.dart';
import '../services/api_client.dart';
import '../state/assessment_controller.dart';

/// Screen displaying details and protocol breakdown for a specific screening activity.
/// Explains planned tasks without fabricating AI processing or clinical diagnoses.
/// Status changes are saved to the backend for the active assessment.
class ActivityDetailScreen extends StatelessWidget {
  final AssessmentController controller;
  final AssessmentActivity activity;

  const ActivityDetailScreen({
    super.key,
    required this.controller,
    required this.activity,
  });

  ChildRecord get child => controller.child;

  /// Saves the new status of this activity, then confirms it.
  Future<void> _setStatus(BuildContext context, ActivityStatus newStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.setActivityStatus(activity.id, newStatus);
    } on ApiException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          behavior: SnackBarBehavior.floating,
          content: Text('Could not save activity status: $error'),
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0D9488),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${activity.title} saved as "${newStatus.label}".',
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          tooltip: 'Return to Assessment Activities',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          activity.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final currentActivity = activity;
                  final status = controller.statusOf(activity.id);
                  final bool canEdit = controller.hasActiveAssessment && !controller.busy;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Candidate Context Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: Color(0xFFCCFBF1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.child_care_rounded,
                                color: Color(0xFF0D9488),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    child.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    '${child.grade} • ${child.ageLabel}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Current Activity Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: status.bgColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    status.icon,
                                    size: 13,
                                    color: status.textColor,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    status.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: status.textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Placeholder Notice Banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.construction_rounded, size: 18, color: Color(0xFF166534)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Activity Workflow in Development • Demo Preview',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF166534),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'This is a structured protocol preview. AI processing, speech models, and automatic scoring are NOT active in this version. No diagnoses are made.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1.35,
                                      color: Color(0xFF166534),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Activity Protocol Card
                      Card(
                        elevation: 1,
                        shadowColor: const Color(0x0A000000),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: currentActivity.accentColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      currentActivity.icon,
                                      color: currentActivity.accentColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentActivity.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          currentActivity.shortDescription,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 28, color: Color(0xFFF1F5F9)),

                              // Objective
                              const Text(
                                'Clinical & Educational Objective',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentActivity.objective,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Protocol steps
                              const Text(
                                'Planned Protocol Tasks',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...currentActivity.protocolSteps.map(
                                (step) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 16,
                                        color: Color(0xFF0D9488),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          step,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            height: 1.4,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Guidance
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Observer Guidance (Parent / Teacher):',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currentActivity.observationalGuidance,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        height: 1.4,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Status control buttons for interactive testing
                      const Text(
                        'Update Activity Status',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (!controller.hasActiveAssessment) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'Start the assessment on the previous screen to record progress for this activity.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0284C7),
                                side: const BorderSide(color: Color(0xFFBAE6FD)),
                                backgroundColor: const Color(0xFFF0F9FF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: canEdit ? () => _setStatus(context, ActivityStatus.inProgress) : null,
                              icon: const Icon(Icons.play_arrow_rounded, size: 16),
                              label: const Text('Mark In Progress'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D9488),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: canEdit ? () => _setStatus(context, ActivityStatus.completed) : null,
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Mark Completed'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: canEdit ? () => _setStatus(context, ActivityStatus.notStarted) : null,
                          child: const Text(
                            'Reset to Not Started',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Return to Activities Button
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: const Color(0xFF334155),
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Return to Assessment Activities'),
                      ),
                      const SizedBox(height: 16),

                      // Footnote
                      const Center(
                        child: Text(
                          'INTELLISCREEN is an academic screening tool, not a diagnostic medical application.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
