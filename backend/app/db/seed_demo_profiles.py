from sqlalchemy.orm import sessionmaker

from app.db.database import SessionLocal
from app.models.child import ChildProfile

# Demonstration profiles only, not real children. Display names and other
# presentation details live in the Flutter app, keyed by participant code.
DEMO_PROFILES = [
    {"participant_code": "demo-1", "age_years": 7},
    {"participant_code": "demo-2", "age_years": 6},
    {"participant_code": "demo-3", "age_years": 5},
    {"participant_code": "demo-4", "age_years": 8},
]


def seed_demo_profiles(session_factory: sessionmaker = SessionLocal) -> int:
    """Insert missing demo profiles; existing rows are never modified.

    Returns the number of profiles inserted.
    """
    db = session_factory()
    try:
        existing_codes = {
            code
            for (code,) in db.query(ChildProfile.participant_code).filter(
                ChildProfile.participant_code.in_(
                    [profile["participant_code"] for profile in DEMO_PROFILES]
                )
            )
        }
        missing = [
            profile
            for profile in DEMO_PROFILES
            if profile["participant_code"] not in existing_codes
        ]
        db.add_all(ChildProfile(**profile) for profile in missing)
        db.commit()
        return len(missing)
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    inserted = seed_demo_profiles()
    print(f"Demo profiles initialized ({inserted} inserted).")
