import 'package:flutter/material.dart';
import '../models/child_record.dart';
import '../models/json_utils.dart';
import '../services/api_client.dart';
import 'assessment_workflow_screen.dart';
import 'children_screen.dart' show LoadErrorCard;

/// Screen displaying an individual child's details, screening history, and entry points.
/// History comes from the backend; no diagnostic claims are fabricated.
class ChildProfileScreen extends StatefulWidget {
  final ChildRecord child;

  const ChildProfileScreen({
    super.key,
    required this.child,
  });

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  ChildRecord get child => widget.child;

  ChildProgress? _progress;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _progress = childrenStore.progressFor(child);
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final progress = await childrenStore.refreshProgress(child);
      if (mounted) setState(() => _progress = progress);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Opens the assessment workflow, then reloads saved progress.
  Future<void> _navigateToAssessmentWorkflow(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AssessmentWorkflowScreen(child: child),
      ),
    );
    if (mounted) await _loadProgress();
  }

  /// Displays an informational dialog explaining longitudinal progress tracking requirements.
  void _showProgressTrackingPreview(BuildContext context) {
    final progress = _progress;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.timeline_rounded, color: Color(0xFF0284C7), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Progress Tracking',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Longitudinal Trend for ${child.name}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 10),
              const Text(
                'Longitudinal monitoring evaluates how a child responds to targeted instructional interventions over time.\n\n'
                'To plot progress curves, at least two completed screening sessions (e.g., Beginning of Year vs. Mid-Year) are required.',
                style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              Text(
                progress == null
                    ? 'Saved progress could not be loaded.'
                    : 'Saved sessions: ${progress.totalAssessments} • '
                        'Completed: ${progress.completedAssessments} • '
                        'In progress: ${progress.inProgressAssessments} • '
                        'Screening results: ${progress.resultsAvailable}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.insights_rounded, size: 16, color: Color(0xFF0284C7)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Zero fabricated results. Counts come only from saved screening records.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryTeal = Color(0xFF0D9488);

    // Format DOB string
    final String dobText = child.dateOfBirth != null
        ? '${child.dateOfBirth!.month}/${child.dateOfBirth!.day}/${child.dateOfBirth!.year}'
        : 'Not recorded';

    // Format registration date string
    final String registeredText =
        child.registeredDate != null ? formatDate(child.registeredDate!) : 'Not recorded';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          tooltip: 'Return to Children',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          child.name,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Child Header Card
                  Card(
                    elevation: 1,
                    shadowColor: const Color(0x0D000000),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Avatar circle
                              Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFCCFBF1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.child_care_rounded,
                                  color: primaryTeal,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Name and metadata
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
                                              fontSize: 18,
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
                                    const SizedBox(height: 4),
                                    Text(
                                      '${child.grade} • ${child.ageLabel} • ${child.gender}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 28, color: Color(0xFFF1F5F9)),

                          // Key details grid
                          Row(
                            children: [
                              Expanded(
                                child: _DetailPill(
                                  label: 'Date of Birth',
                                  value: dobText,
                                  icon: Icons.cake_outlined,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _DetailPill(
                                  label: 'Registered On',
                                  value: registeredText,
                                  icon: Icons.calendar_today_outlined,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _DetailPill(
                            label: 'Status',
                            value: _progress?.statusSummary ?? 'Status unavailable',
                            icon: Icons.verified_outlined,
                          ),

                          if (child.notes != null && child.notes!.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
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
                                    'Demo Profile Notes (illustrative, not saved data):',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    child.notes!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actions / Quick Entry Points
                  const Text(
                    'Screening Actions',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      // Entry Point 1: New Assessment
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _navigateToAssessmentWorkflow(context),
                          icon: const Icon(Icons.add_task_rounded, size: 18),
                          label: const Text(
                            'New Assessment',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Entry Point 2: Progress Tracking
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            side: const BorderSide(color: Color(0xFFBAE6FD)),
                            backgroundColor: const Color(0xFFF0F9FF),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _showProgressTrackingPreview(context),
                          icon: const Icon(Icons.timeline_rounded, size: 18),
                          label: const Text(
                            'Progress Tracking',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Assessment History Section with Reactive Empty / Non-Empty States
                  const Text(
                    'Assessment History',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Builder(
                    builder: (context) {
                      final progress = _progress;

                      if (progress == null && _loading) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (progress == null) {
                        return LoadErrorCard(
                          title: 'Could not load assessment history',
                          message: _error ?? 'Unknown error',
                          onRetry: _loadProgress,
                        );
                      }

                      final assessments = progress.history;

                      // EMPTY STATE: If the child has no saved assessments
                      if (assessments.isEmpty) {
                        return Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Illustration / Icon
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDFA),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFCCFBF1), width: 1.5),
                                  ),
                                  child: const Icon(
                                    Icons.assignment_outlined,
                                    size: 32,
                                    color: primaryTeal,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Required heading
                                const Text(
                                  'No assessments yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Short explanation
                                Text(
                                  'Completed screening sessions, observation notes, and non-diagnostic indicators for ${child.name} will appear here.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Required "Start New Assessment" button
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryTeal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => _navigateToAssessmentWorkflow(context),
                                  icon: const Icon(Icons.add_task_rounded, size: 18),
                                  label: const Text('Start New Assessment'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // NON-EMPTY STATE: Display saved records for this child
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCCFBF1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${assessments.length} Saved Record${assessments.length > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => _navigateToAssessmentWorkflow(context),
                                icon: const Icon(Icons.add_task_rounded, size: 16, color: primaryTeal),
                                label: const Text(
                                  'Start New Assessment',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: primaryTeal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...assessments.map((record) => _AssessmentCardItem(record: record)),
                        ],
                      );
                    },
                  ),
                  if (_progress != null && _error != null) ...[
                    const SizedBox(height: 10),
                    LoadErrorCard(
                      title: 'Could not refresh assessment history',
                      message: _error!,
                      onRetry: _loadProgress,
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Non-diagnostic transparent disclaimer
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF166534)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Notice: INTELLISCREEN is an educational screening and progress-monitoring tool. It provides early observational insights and does not make medical or psychological diagnoses.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: Color(0xFF166534),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card displaying a saved assessment of a child, as returned by the backend.
class _AssessmentCardItem extends StatelessWidget {
  final AssessmentSummary record;

  const _AssessmentCardItem({required this.record});

  @override
  Widget build(BuildContext context) {
    Color statusBgColor;
    Color statusTextColor;
    IconData statusIcon;

    switch (record.status) {
      case AssessmentStatus.completed:
        statusBgColor = const Color(0xFFCCFBF1);
        statusTextColor = const Color(0xFF0F766E);
        statusIcon = Icons.check_circle_outline_rounded;
      case AssessmentStatus.inProgress:
        statusBgColor = const Color(0xFFE0F2FE);
        statusTextColor = const Color(0xFF0369A1);
        statusIcon = Icons.pending_outlined;
      case AssessmentStatus.cancelled:
        statusBgColor = const Color(0xFFF1F5F9);
        statusTextColor = const Color(0xFF475569);
        statusIcon = Icons.cancel_outlined;
    }

    final completedOn = record.completedAt;
    final String dateText = completedOn != null
        ? 'Completed on ${formatDate(completedOn)}'
        : 'Started on ${formatDate(record.createdAt)}';
    final activities = ScreeningActivities.all;
    final result = record.result;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shadowColor: const Color(0x0A000000),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.assignment_turned_in_outlined,
                    color: Color(0xFF0284C7),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Screening Session #${record.id}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateText,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusTextColor),
                      const SizedBox(width: 4),
                      Text(
                        record.status.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.category_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Activities completed: ${record.completedActivityCount} of ${activities.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final activity in activities)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: record.statusOf(activity.id).bgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          record.statusOf(activity.id).icon,
                          size: 11,
                          color: record.statusOf(activity.id).textColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          activity.title,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: record.statusOf(activity.id).textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Screening Result:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              result != null
                  ? [
                      'Category: ${result.resultCategory ?? 'not provided'}',
                      if (result.confidenceScore != null)
                        'Confidence: ${(result.confidenceScore! * 100).toStringAsFixed(0)}%',
                      if (result.modelVersion != null) 'Model: ${result.modelVersion}',
                    ].join(' • ')
                  : record.status == AssessmentStatus.completed
                      ? 'No screening result has been generated. The automated screening model is not connected yet, so completing activities does not produce a result.'
                      : 'No result. Results can only be added to completed assessments.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Color(0xFF334155),
              ),
            ),
            if (result != null && result.modalityScores.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                result.modalityScores.entries
                    .map((entry) => '${entry.key}: ${(entry.value * 100).toStringAsFixed(0)}%')
                    .join(' • '),
                style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
              ),
            ],
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.shield_outlined, size: 12, color: Color(0xFF94A3B8)),
                SizedBox(width: 4),
                Text(
                  'Academic screening observation • Non-diagnostic',
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper card displaying an individual attribute pill.
class _DetailPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
