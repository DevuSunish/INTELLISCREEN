import 'package:flutter/material.dart';

/// Status of an individual screening activity within an assessment session.
enum ActivityStatus {
  notStarted,
  inProgress,
  completed,
}

/// Conversion to and from the backend's activity status vocabulary.
extension ActivityStatusApi on ActivityStatus {
  String get apiValue {
    switch (this) {
      case ActivityStatus.notStarted:
        return 'not_started';
      case ActivityStatus.inProgress:
        return 'in_progress';
      case ActivityStatus.completed:
        return 'completed';
    }
  }

  static ActivityStatus fromApi(String value) {
    for (final status in ActivityStatus.values) {
      if (status.apiValue == value) return status;
    }
    throw FormatException('Unknown activity status "$value"');
  }
}

extension ActivityStatusExtension on ActivityStatus {
  String get label {
    switch (this) {
      case ActivityStatus.notStarted:
        return 'Not Started';
      case ActivityStatus.inProgress:
        return 'In Progress';
      case ActivityStatus.completed:
        return 'Completed';
    }
  }

  Color get textColor {
    switch (this) {
      case ActivityStatus.notStarted:
        return const Color(0xFF64748B);
      case ActivityStatus.inProgress:
        return const Color(0xFF0369A1);
      case ActivityStatus.completed:
        return const Color(0xFF0F766E);
    }
  }

  Color get bgColor {
    switch (this) {
      case ActivityStatus.notStarted:
        return const Color(0xFFF1F5F9);
      case ActivityStatus.inProgress:
        return const Color(0xFFE0F2FE);
      case ActivityStatus.completed:
        return const Color(0xFFCCFBF1);
    }
  }

  IconData get icon {
    switch (this) {
      case ActivityStatus.notStarted:
        return Icons.radio_button_unchecked_rounded;
      case ActivityStatus.inProgress:
        return Icons.pending_outlined;
      case ActivityStatus.completed:
        return Icons.check_circle_rounded;
    }
  }
}

/// Represents one of the 5 core screening activities in INTELLISCREEN.
/// The [id] is the stable activity key shared with the backend.
class AssessmentActivity {
  final String id;
  final String title;
  final String shortDescription;
  final IconData icon;
  final Color accentColor;
  final String objective;
  final List<String> protocolSteps;
  final String observationalGuidance;

  const AssessmentActivity({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.icon,
    required this.accentColor,
    required this.objective,
    required this.protocolSteps,
    required this.observationalGuidance,
  });
}

/// Catalog of the five screening activities, in workflow order.
class ScreeningActivities {
  static const List<AssessmentActivity> all = [
    AssessmentActivity(
        id: 'handwriting',
        title: 'Handwriting Assessment',
        shortDescription:
            'Evaluate pencil grasp, letter formation, line adherence, and motor stroke consistency.',
        icon: Icons.draw_outlined,
        accentColor: Color(0xFF0D9488),
        objective:
            'Observe fine motor control, handwriting posture, and letter formation to detect early signs of dysgraphia.',
        protocolSteps: [
          'Child is seated comfortably with an age-appropriate pencil and ruled paper.',
          'Child writes a short prompt or copies a model sentence at their normal pace.',
          'Observer evaluates dynamic pencil grasp, forearm stability, and pressure.',
          'Check for letter reversals, irregular spacing, and noticeable hand fatigue.',
        ],
        observationalGuidance:
            'Document whether the child shakes their hand, complains of cramping, or switches grips during writing.',
      ),
    AssessmentActivity(
        id: 'reading',
        title: 'Reading Assessment',
        shortDescription:
            'Assess single-word reading accuracy, phonemic decoding, and oral passage fluency.',
        icon: Icons.menu_book_rounded,
        accentColor: Color(0xFF0284C7),
        objective:
            'Measure oral reading fluency and sight-word decoding to identify potential phonological dyslexia flags.',
        protocolSteps: [
          'Present graded word lists containing both regular decodable and high-frequency sight words.',
          'Child reads a short, un-timed 100-word grade-level story aloud.',
          'Record words correct per minute (WCPM) and note hesitation patterns.',
          'Observe self-corrections, sound omissions, or whole-word guessing behaviors.',
        ],
        observationalGuidance:
            'Listen for vowel confusion, phoneme skipping, and monotone delivery without natural phrasing.',
      ),
    AssessmentActivity(
        id: 'phonological',
        title: 'Phonological Awareness',
        shortDescription:
            'Screen phoneme isolation, sound blending, rhyming pairs, and syllable manipulation.',
        icon: Icons.record_voice_over_outlined,
        accentColor: Color(0xFF0F766E),
        objective:
            'Evaluate auditory sensitivity to sound structures within spoken words without visual text.',
        protocolSteps: [
          'Rhyme Detection: Present word pairs (e.g., cat/hat vs. dog/pen) for oral identification.',
          'Syllable Clapping: Segment multisyllabic words by clapping or tapping beats.',
          'Phoneme Isolation: Ask the child for the first, middle, or final sound in simple words.',
          'Sound Blending: Say separated sounds (/s/ /u/ /n/) and ask the child to assemble the whole word.',
        ],
        observationalGuidance:
            'Check if the child relies on visual lip-reading or shows uncertainty with initial consonant blends.',
      ),
    AssessmentActivity(
        id: 'ran',
        title: 'Rapid Automatized Naming (RAN)',
        shortDescription:
            'Measure speed of visual naming for familiar objects, colors, and letter sequences.',
        icon: Icons.timer_outlined,
        accentColor: Color(0xFFD97706),
        objective:
            'Screen visual-to-phonological retrieval automaticity, a recognized core indicator in dyslexia screening.',
        protocolSteps: [
          'Familiarization preview: Verify child effortlessly recognizes sample icons and colors.',
          'Present a randomized 5x10 visual grid of recurring familiar items.',
          'Child names each item aloud as quickly as possible from left to right, top to bottom.',
          'Observer tracks total completion time in seconds and marks any skipped lines.',
        ],
        observationalGuidance:
            'Note hesitation blocks, finger-tracking necessity, or perceptual visual jumps between rows.',
      ),
    AssessmentActivity(
        id: 'memory',
        title: 'Memory Assessment',
        shortDescription:
            'Screen auditory short-term memory, verbal working memory, and sequential recall.',
        icon: Icons.psychology_outlined,
        accentColor: Color(0xFF6366F1),
        objective:
            'Screen working memory capacity needed to hold speech sounds while decoding and writing sentences.',
        protocolSteps: [
          'Forward Digit Span: Child repeats orally presented digit sequences (3 to 6 digits).',
          'Reverse Digit Span: Child repeats a short sequence in backwards order (e.g., 4 - 8 -> 8 - 4).',
          'Non-Word Repetition: Child repeats novel phonological non-words (e.g., "bav-ment-ish").',
          'Sequential Sentence Recall: Child repeats an 8-word sentence without omitting function words.',
        ],
        observationalGuidance:
            'Document whether the child reverses number sequences or forgets initial sounds in multi-clause instructions.',
      ),
  ];
}
