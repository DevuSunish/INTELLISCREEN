from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine
from sqlalchemy.orm import sessionmaker

from app import models  # noqa: F401  (registers every model on Base.metadata)
from app.core.constants import ASSESSMENT_IN_PROGRESS, INFERENCE_COMPLETED
from app.db.database import Base, engine
from app.db.seed_demo_profiles import seed_demo_profiles

# Columns added after the first release. create_all() never alters existing
# tables, so databases created earlier get these through ALTER TABLE.
_ADDED_COLUMNS = {
    "child_profiles": {
        "owner_id": "INTEGER REFERENCES users(id)",
    },
    "assessments": {
        "user_id": "INTEGER REFERENCES users(id)",
        "updated_at": "DATETIME",
        "completed_at": "DATETIME",
        "inference_status": "VARCHAR(20)",
        "inference_error": "VARCHAR(500)",
    },
}

_ADDED_INDEXES = {
    "ix_child_profiles_owner_id": ("child_profiles", "owner_id"),
    "ix_assessments_user_id": ("assessments", "user_id"),
}


def _upgrade_existing_tables(bind: Engine) -> None:
    inspector = inspect(bind)
    with bind.begin() as connection:
        for table, columns in _ADDED_COLUMNS.items():
            existing = {column["name"] for column in inspector.get_columns(table)}
            for name, ddl in columns.items():
                if name not in existing:
                    connection.execute(text(f"ALTER TABLE {table} ADD COLUMN {name} {ddl}"))

        for index, (table, column) in _ADDED_INDEXES.items():
            connection.execute(
                text(f"CREATE INDEX IF NOT EXISTS {index} ON {table} ({column})")
            )

        # The first release used "pending" for assessments that had been started.
        connection.execute(
            text("UPDATE assessments SET status = :new WHERE status = 'pending'"),
            {"new": ASSESSMENT_IN_PROGRESS},
        )

        # Results saved before inference tracking existed count as completed inference.
        connection.execute(
            text(
                "UPDATE assessments SET inference_status = :done "
                "WHERE inference_status IS NULL "
                "AND id IN (SELECT assessment_id FROM screening_results)"
            ),
            {"done": INFERENCE_COMPLETED},
        )


def init_db(bind: Engine = engine) -> None:
    """Create missing tables, upgrade older schemas and seed demo profiles.

    Safe to run on every startup: nothing existing is dropped or overwritten.
    """
    Base.metadata.create_all(bind=bind)
    _upgrade_existing_tables(bind)
    seed_demo_profiles(sessionmaker(bind=bind, autoflush=False))


if __name__ == "__main__":
    init_db()
    print("INTELLISCREEN database initialized.")
