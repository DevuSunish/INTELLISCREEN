import 'package:flutter/material.dart';
import '../models/child_record.dart';
import 'add_child_screen.dart';
import 'child_profile_screen.dart';
import '../services/child_api_service.dart';

/// Screen displaying the list of registered child profiles.
/// Supports adding new sample learners into temporary in-memory state.
class ChildrenScreen extends StatelessWidget {
  const ChildrenScreen({super.key});

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
          // Quick Add Child button in AppBar
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddChildScreen()),
              );
            },
            icon: const Icon(Icons.add_rounded, size: 18, color: primaryTeal),
            label: const Text(
              'Add Child',
              style: TextStyle(color: primaryTeal, fontWeight: FontWeight.w700),
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

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  children: [
                    const BackendChildrenSection(),
  const SizedBox(height: 16),

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
                                      '${children.length} Active Profiles • In-Memory Demo',
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
                            'Manage profiles for academic screening and progress monitoring. Tap any child card to view their profile, screening status, and observation history.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Add Child CTA Button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryTeal,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const AddChildScreen()),
                              );
                            },
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                            label: const Text('Add New Child Profile'),
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
                    if (children.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            'No child profiles registered yet.\nTap "Add New Child Profile" above to create one.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ...children.map((child) => _ChildCardItem(child: child)),

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

/// Individual card displaying a child profile item in the roster list.
class _ChildCardItem extends StatelessWidget {
  final ChildRecord child;

  const _ChildCardItem({required this.child});

  @override
  Widget build(BuildContext context) {
    // Dynamic status badge styling
    Color badgeBgColor;
    Color badgeTextColor;
    IconData badgeIcon;

    if (child.assessmentStatus.contains('Follow-up')) {
      badgeBgColor = const Color(0xFFFEF3C7);
      badgeTextColor = const Color(0xFFB45309);
      badgeIcon = Icons.flag_outlined;
    } else if (child.assessmentStatus.contains('Up to Date')) {
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
                            'Age ${child.age} yrs',
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
                              child.assessmentStatus,
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

/// Displays anonymized child profiles retrieved from the backend API.
class BackendChildrenSection extends StatefulWidget {
  const BackendChildrenSection({super.key});

  @override
  State<BackendChildrenSection> createState() =>
      _BackendChildrenSectionState();
}

class _BackendChildrenSectionState extends State<BackendChildrenSection> {
  final ChildApiService _apiService = ChildApiService();

  late Future<List<Map<String, dynamic>>> _childrenFuture;

  @override
  void initState() {
    super.initState();
    _childrenFuture = _apiService.getChildren();
  }

  void _reloadChildren() {
    setState(() {
      _childrenFuture = _apiService.getChildren();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Backend Profiles',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh backend profiles',
                  onPressed: _reloadChildren,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const Text(
              'Anonymized participant records stored by the backend.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _childrenFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Could not load backend profiles.',
                        style: TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _reloadChildren,
                        child: const Text('Try again'),
                      ),
                    ],
                  );
                }

                final children = snapshot.data ?? [];

                if (children.isEmpty) {
                  return const Text('No backend profiles found.');
                }

                return Column(
                  children: children.map((child) {
                    final participantCode =
                        child['participant_code']?.toString() ??
                        'Unknown participant';
                    final age = child['age_years'];

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(participantCode),
                      subtitle: Text(
                        age == null ? 'Age not provided' : 'Age $age years',
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
