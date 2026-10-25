import 'package:flutter/material.dart';
import '../models/child_record.dart';
import '../services/child_api_service.dart';

/// Screen allowing parents or educators to register a new child profile.
/// Saves to temporary in-memory session state without persisting to a backend.
class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final _formKey = GlobalKey<FormState>();
  final ChildApiService _childApiService = ChildApiService();
bool _isSavingToBackend = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime? _selectedDateOfBirth;
  String? _selectedGrade = 'Grade 1';
  String _selectedGender = 'Prefer not to say';

  // Standard grade level options for academic screening
  final List<String> _gradeOptions = [
    'Pre-K',
    'Kindergarten',
    'Grade 1',
    'Grade 2',
    'Grade 3',
    'Grade 4',
    'Grade 5',
    'Grade 6',
    'Grade 7',
    'Grade 8',
    'Other / Specialized',
  ];

  // Gender selection options with optional "Prefer not to say"
  final List<String> _genderOptions = [
    'Female',
    'Male',
    'Non-binary / Other',
    'Prefer not to say',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Opens a DatePicker and auto-computes the child's approximate age.
  Future<void> _pickDateOfBirth() async {
    final DateTime now = DateTime.now();
    // Default initial date: ~7 years ago
    final DateTime initial = _selectedDateOfBirth ?? DateTime(now.year - 7, now.month, now.day);
    final DateTime firstDate = DateTime(now.year - 18, 1, 1);
    final DateTime lastDate = DateTime(now.year - 3, 12, 31);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select Date of Birth (Ages 3-17)',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D9488),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateOfBirth = picked;
        // Calculate age
        int age = now.year - picked.year;
        if (now.month < picked.month || (now.month == picked.month && now.day < picked.day)) {
          age--;
        }
        _ageController.text = age.toString();
      });
    }
  }

  /// Validates and saves the new record to in-memory store.
  void _saveChildProfile() {
    final bool isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    final int age = int.tryParse(_ageController.text.trim()) ?? 0;
    final String cleanName = _nameController.text.trim();
    final String displayName = cleanName.endsWith('(Demo Profile)')
        ? cleanName
        : '$cleanName (Demo Profile)';

    final newChild = ChildRecord(
      id: 'demo-${DateTime.now().millisecondsSinceEpoch}',
      name: displayName,
      age: age,
      dateOfBirth: _selectedDateOfBirth,
      grade: _selectedGrade ?? 'Grade 1',
      gender: _selectedGender,
      assessmentStatus: 'Not Screened Yet (Demo)',
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      registeredDate: DateTime.now(),
      isDemoRecord: true,
    );

    // Save to session state
    childrenStore.addChild(newChild);

    // Show confirmation feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0D9488),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Added "$displayName" to temporary demo session.',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );

    Navigator.of(context).pop();
  }
  Future<void> _saveBackendProfile() async {
  if (_isSavingToBackend) return;

  final bool isValid = _formKey.currentState?.validate() ?? false;
  if (!isValid) return;

  final int? age = int.tryParse(_ageController.text.trim());
  if (age == null) return;

  final String participantCode = _nameController.text.trim();

  setState(() {
    _isSavingToBackend = true;
  });

  try {
    final profile = await _childApiService.createChild(
      participantCode: participantCode,
      ageYears: age,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Backend profile created: ${profile['participant_code']}',
        ),
      ),
    );

    Navigator.of(context).pop();
  } catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not create backend profile: $error'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isSavingToBackend = false;
      });
    }
  }
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
          tooltip: 'Return to Children',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Add Child Profile',
          style: TextStyle(
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
              constraints: const BoxConstraints(maxWidth: 540),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Demo Session Notice Banner
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
                          Icon(Icons.info_outline_rounded, color: Color(0xFF166534), size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Temporary Session Storage Only',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF166534),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Records created here are stored in memory for this demo session and are not permanently saved to a backend database. Please use fictitious sample names.',
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

                    // Main Form Card
                    Card(
                      elevation: 1,
                      shadowColor: const Color(0x0D000000),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section title
                            const Text(
                              'Learner Information',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Enter sample details to simulate an academic screening workflow.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 20),

                            // Child's Name
                            const Text(
                              'Child Name or Identifier *',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                hintText: 'e.g., Jamie R. (Demo)',
                                prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a child name or identifier';
                                }
                                if (value.trim().length < 2) {
                                  return 'Name must be at least 2 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            // Age and Date of Birth Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Age input
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Age (Years) *',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _ageController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          hintText: '4 - 17',
                                          prefixIcon: Icon(Icons.cake_outlined, size: 20),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'Required';
                                          }
                                          final int? parsed = int.tryParse(value.trim());
                                          if (parsed == null || parsed < 4 || parsed > 17) {
                                            return 'Age 4-17 only';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Date of birth picker button
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Date of Birth',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      InkWell(
                                        onTap: _pickDateOfBirth,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.calendar_today_rounded,
                                                size: 18,
                                                color: Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _selectedDateOfBirth == null
                                                      ? 'Select DOB'
                                                      : '${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.year}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: _selectedDateOfBirth == null
                                                        ? const Color(0xFF94A3B8)
                                                        : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Grade Level Dropdown
                            const Text(
                              'Grade Level *',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedGrade,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.school_outlined, size: 20),
                              ),
                              items: _gradeOptions.map((grade) {
                                return DropdownMenuItem<String>(
                                  value: grade,
                                  child: Text(grade, style: const TextStyle(fontSize: 14)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedGrade = value;
                                });
                              },
                              validator: (value) =>
                                  value == null ? 'Please select a grade level' : null,
                            ),
                            const SizedBox(height: 18),

                            // Gender Selection
                            const Text(
                              'Gender (Optional / Demographic)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedGender,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.badge_outlined, size: 20),
                              ),
                              items: _genderOptions.map((gender) {
                                return DropdownMenuItem<String>(
                                  value: gender,
                                  child: Text(gender, style: const TextStyle(fontSize: 14)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedGender = value ?? 'Prefer not to say';
                                });
                              },
                            ),
                            const SizedBox(height: 18),

                            // Observational Notes (Optional)
                            const Text(
                              'Parent / Educator Observations (Optional)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _notesController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText:
                                    'e.g., Enjoys storybooks, shows hesitation during letter naming, fatigues with handwriting...',
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Submit Button
                          ElevatedButton(
                              onPressed: _saveChildProfile,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_add_alt_1_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('Save to Demo Session'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            OutlinedButton.icon(
                              onPressed: _isSavingToBackend
                                  ? null
                                  : _saveBackendProfile,
                              icon: _isSavingToBackend
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.cloud_upload_outlined),
                              label: Text(
                                _isSavingToBackend
                                    ? 'Saving Backend Profile...'
                                    : 'Save Anonymized Backend Profile',
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Cancel Button
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF64748B),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Non-diagnostic footnote
                    const Center(
                      child: Text(
                        'INTELLISCREEN is an academic screening tool, not a diagnostic application.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
