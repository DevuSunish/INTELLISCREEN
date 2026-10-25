"""Shared vocabulary used by models, schemas, endpoints and the Flutter client."""

# Participant codes of the four shared demonstration profiles.
DEMO_PARTICIPANT_CODES = ("demo-1", "demo-2", "demo-3", "demo-4")

ASSESSMENT_TYPE_SCREENING = "screening"

# Assessment lifecycle. "Not started" is represented by the absence of an assessment.
ASSESSMENT_IN_PROGRESS = "in_progress"
ASSESSMENT_COMPLETED = "completed"
ASSESSMENT_CANCELLED = "cancelled"
ASSESSMENT_STATUSES = (
    ASSESSMENT_IN_PROGRESS,
    ASSESSMENT_COMPLETED,
    ASSESSMENT_CANCELLED,
)

# Activity lifecycle within an assessment.
ACTIVITY_NOT_STARTED = "not_started"
ACTIVITY_IN_PROGRESS = "in_progress"
ACTIVITY_COMPLETED = "completed"
ACTIVITY_STATUSES = (
    ACTIVITY_NOT_STARTED,
    ACTIVITY_IN_PROGRESS,
    ACTIVITY_COMPLETED,
)

# Stable keys of the five screening activities; they match the Flutter catalog.
SCREENING_ACTIVITY_KEYS = ("handwriting", "reading", "phonological", "ran", "memory")
