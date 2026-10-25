import 'package:flutter/material.dart';
import '../models/child_record.dart';
import '../services/api_client.dart';
import '../state/assessment_controller.dart';
import 'activity_detail_screen.dart';
import 'children_screen.dart' show LoadErrorCard;

/// Screen managing the multi-activity assessment workflow for a specific child.
/// Coordinates session status across five screening activities:
/// Handwriting, Reading, Phonological Awareness, RAN, and Memory.
/// The assessment and every activity status are saved to the backend.
class AssessmentWorkflowScreen extends StatefulWidget {
  final ChildRecord child;

  const AssessmentWorkflowScreen({
    super.key,
    required this.child,
  });

  @override
  State<AssessmentWorkflowScreen> createState() => _AssessmentWorkflowScreenState();
}

class _AssessmentWorkflowScreenState extends State<AssessmentWorkflowScreen> {
  late final AssessmentController _controller = AssessmentController(child: widget.child);

  ChildRecord get child => widget.child;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? const Color(0xFFB91C1C) : const Color(0xFF0D9488),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
      ),
    );
  }

  Future<void> _startAssessment() async {
    try {
      await _controller.start();
      _showMessage('Assessment started for ${child.name}. Progress is saved as you go.');
    } on ApiException catch (error) {
      _showMessage('Could not start the assessment: $error', isError: true);
    }
  }

  /// Marks the saved assessment completed; the backend checks every activity is done.
  Future<void> _completeSession() async {
    try {
      await _controller.complete();
    } on ApiException catch (error) {
      _showMessage('Could not complete the assessment: $error', isError: true);
      return;
    }

    try {
      await childrenStore.refreshProgress(child);
    } on ApiException {
      // The profile screen reloads progress and shows any error itself.
    }

    _showMessage(
      'Assessment completed and saved for ${child.name}. '
      'No screening result was generated because the screening model is not connected.',
    );
    if (mounted) Navigator.of(context).pop();
  }

  /// Cancels the in-progress assessment after confirmation.
  Future<void> _cancelAssessment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this assessment?'),
        content: const Text(
          'The assessment stays in the history as cancelled and its activities can no longer be changed. '
          'You can start a new assessment afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Assessment'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel Assessment'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _controller.cancel();
      _showMessage('Assessment cancelled for ${child.name}.');
    } on ApiException catch (error) {
      _showMessage('Could not cancel the assessment: $error', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryTeal = Color(0xFF0D9488);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          tooltip: 'Return to Child Profile',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Assessment Workflow',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => IconButton(
              tooltip: 'Cancel Assessment',
              icon: const Icon(Icons.cancel_outlined, color: Color(0xFF64748B)),
              onPressed: _controller.hasActiveAssessment && !_controller.busy
                  ? _cancelAssessment
                  : null,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  final activities = _controller.activities;
                  final int completedCount = _controller.completedCount;
                  final double progressPercent =
                      activities.isEmpty ? 0.0 : completedCount / activities.length;
                  final bool active = _controller.hasActiveAssessment;
                  final bool busy = _controller.busy;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Child Details Header Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: const BoxDecoration(
                                color: Color(0xFFCCFBF1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.child_care_rounded,
                                color: primaryTeal,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          child.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'DEMO',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${child.grade} • ${child.ageLabel} • ID: ${child.participantCode}',
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
                      ),
                      const SizedBox(height: 16),

                      // Session Progress Overview Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0D9488), Color(0xFF0284C7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Assessment Session Status',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _controller.statusLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progressPercent,
                                minHeight: 8,
                                backgroundColor: Colors.white.withValues(alpha: 0.25),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$completedCount of ${activities.length} activities completed',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Storage Notice Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF166534)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Saved to the INTELLISCREEN backend • The assessment and each activity status are stored as you go and restored when you return.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF166534),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (_controller.loading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: LinearProgressIndicator(),
                        )
                      else if (_controller.loadError != null) ...[
                        LoadErrorCard(
                          title: 'Could not load saved assessment progress',
                          message: _controller.loadError!,
                          onRetry: _controller.load,
                        ),
                        const SizedBox(height: 16),
                      ] else if (!active) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'No assessment in progress',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Start an assessment to record activity progress. You can preview the activities below at any time.',
                                style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryTeal,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(46),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: busy ? null : _startAssessment,
                                icon: busy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.play_arrow_rounded, size: 20),
                                label: const Text('Start Assessment'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Section Header
                      Row(
                        children: [
                          const Text(
                            'Screening Activities',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Tap any activity to preview',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 2. The Five Assessment Activity Cards
                      ...activities.map(
                        (activity) => _ActivityCardItem(
                          activity: activity,
                          status: _controller.statusOf(activity.id),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ActivityDetailScreen(
                                  controller: _controller,
                                  activity: activity,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Complete Session Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTeal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: active && _controller.allActivitiesCompleted && !busy
                            ? _completeSession
                            : null,
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                        label: const Text(
                          'Complete & Save Screening Session',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ),
                      if (active && !_controller.allActivitiesCompleted) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'Mark all five activities as completed to finish the assessment.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                      const SizedBox(height: 10),

                      // Return to Profile button
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Return to Child Profile'),
                      ),
                      const SizedBox(height: 16),

                      // Non-diagnostic Footnote
                      const Center(
                        child: Text(
                          'INTELLISCREEN provides educational screening indicators, not clinical or formal medical diagnoses.',
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

/// Card representing an individual screening activity in the session.
class _ActivityCardItem extends StatelessWidget {
  final AssessmentActivity activity;
  final ActivityStatus status;
  final VoidCallback onTap;

  const _ActivityCardItem({
    required this.activity,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shadowColor: const Color(0x0A000000),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Activity icon in colored container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: activity.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(activity.icon, color: activity.accentColor, size: 22),
              ),
              const SizedBox(width: 14),

              // Title, description, and status pill
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            activity.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: status.bgColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                status.icon,
                                size: 11,
                                color: status.textColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                status.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: status.textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      activity.shortDescription,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Trailing arrow icon
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
