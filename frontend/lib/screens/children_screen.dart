import 'package:flutter/material.dart';
import '../models/child_record.dart';
import 'child_profile_screen.dart';

/// Screen displaying the list of registered child profiles.
/// Profiles and their status are loaded from the backend.
class ChildrenScreen extends StatefulWidget {
  const ChildrenScreen({super.key});

  @override
  State<ChildrenScreen> createState() => _ChildrenScreenState();
}

class _ChildrenScreenState extends State<ChildrenScreen> {
  @override
  void initState() {
    super.initState();
    if (childrenStore.state != LoadState.ready) {
      childrenStore.load();
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
          tooltip: 'Return to Dashboard',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Child Profiles',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          ListenableBuilder(
            listenable: childrenStore,
            builder: (context, _) => IconButton(
              tooltip: 'Reload profiles',
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
              onPressed:
                  childrenStore.state == LoadState.loading ? null : childrenStore.load,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListenableBuilder(
              listenable: childrenStore,
              builder: (context, _) {
                final children = childrenStore.children;
                final state = childrenStore.state;

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  children: [
                    // Header Card
                    Container(
                      padding: const EdgeInsets.all(18),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCCFBF1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.people_alt_rounded,
                                  color: primaryTeal,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Registered Learners',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      state == LoadState.ready
                                          ? '${children.length} Demo Profiles'
                                          : 'Loading profiles…',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Select a demo child to view their profile, screening history, and progress.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Demo Data Notice Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_clock_outlined, size: 16, color: Color(0xFF0369A1)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sample records only. No personal student identities are stored.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0369A1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section Heading
                    Row(
                      children: [
                        const Text(
                          'Learner Roster',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const Spacer(),
                        if (state == LoadState.ready)
                          Text(
                            'Showing ${children.length} profiles',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // List of Child Profile Cards
                    if (state == LoadState.loading || state == LoadState.idle)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (state == LoadState.error)
                      LoadErrorCard(
                        title: 'Could not load child profiles',
                        message: childrenStore.error ?? 'Unknown error',
                        onRetry: childrenStore.load,
                      )
                    else if (children.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            'No child profiles are available. Restart the backend to restore the demo profiles.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ...children.map(
                        (child) => _ChildCardItem(
                          child: child,
                          statusLabel: childrenStore.progressFor(child)?.statusSummary ??
                              'Status unavailable',
                        ),
                      ),

                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Error panel with a retry button, used where backend data failed to load.
class LoadErrorCard extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const LoadErrorCard({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_off_rounded, size: 18, color: Color(0xFFB91C1C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF7F1D1D)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Individual card displaying a child profile item in the roster list.
class _ChildCardItem extends StatelessWidget {
  final ChildRecord child;
  final String statusLabel;

  const _ChildCardItem({required this.child, required this.statusLabel});

  @override
  Widget build(BuildContext context) {
    // Dynamic status badge styling
    Color badgeBgColor;
    Color badgeTextColor;
    IconData badgeIcon;

    if (statusLabel.contains('in progress')) {
      badgeBgColor = const Color(0xFFE0F2FE);
      badgeTextColor = const Color(0xFF0369A1);
      badgeIcon = Icons.pending_outlined;
    } else if (statusLabel.contains('completed')) {
      badgeBgColor = const Color(0xFFCCFBF1);
      badgeTextColor = const Color(0xFF0F766E);
      badgeIcon = Icons.check_circle_outline_rounded;
    } else {
      badgeBgColor = const Color(0xFFF1F5F9);
      badgeTextColor = const Color(0xFF475569);
      badgeIcon = Icons.schedule_rounded;
    }

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
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChildProfileScreen(child: child),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFCCFBF1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.child_care_rounded,
                  color: Color(0xFF0D9488),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),

              // Child Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Age & Grade Tags
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            child.grade,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            child.ageLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 12, color: badgeTextColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              statusLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: badgeTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Chevron Icon
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
