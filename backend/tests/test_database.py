import sqlite3

from sqlalchemy import create_engine, inspect
from sqlalchemy.orm import sessionmaker

from app.db.init_db import init_db
from app.db.seed_demo_profiles import DEMO_PROFILES, seed_demo_profiles
from app.models.child import ChildProfile

DEMO_CODES = [profile["participant_code"] for profile in DEMO_PROFILES]


def _file_engine(tmp_path):
    return create_engine(
        f"sqlite:///{tmp_path / 'test.db'}", connect_args={"check_same_thread": False}
    )


def test_init_creates_all_tables_and_seeds(tmp_path):
    engine = _file_engine(tmp_path)
    init_db(engine)

    tables = set(inspect(engine).get_table_names())
    assert {
        "users",
        "child_profiles",
        "assessments",
        "activity_statuses",
        "screening_results",
    } <= tables

    with sessionmaker(bind=engine)() as session:
        codes = [c.participant_code for c in session.query(ChildProfile).order_by(ChildProfile.id)]
    assert codes == DEMO_CODES


def test_repeated_initialization_creates_no_duplicates(tmp_path):
    engine = _file_engine(tmp_path)
    init_db(engine)
    init_db(engine)
    assert seed_demo_profiles(sessionmaker(bind=engine)) == 0

    with sessionmaker(bind=engine)() as session:
        assert session.query(ChildProfile).count() == 4


def test_seeding_preserves_existing_profiles(tmp_path):
    engine = _file_engine(tmp_path)
    init_db(engine)
    Session = sessionmaker(bind=engine)
    with Session() as session:
        leo = session.query(ChildProfile).filter_by(participant_code="demo-1").one()
        leo.age_years = 9
        session.add(ChildProfile(participant_code="someone-else", age_years=10))
        session.commit()
        leo_id = leo.id

    init_db(engine)

    with Session() as session:
        leo = session.query(ChildProfile).filter_by(participant_code="demo-1").one()
        assert (leo.id, leo.age_years) == (leo_id, 9)
        assert session.query(ChildProfile).filter_by(participant_code="someone-else").count() == 1
        assert session.query(ChildProfile).count() == 5


def test_seeding_fills_in_missing_demo_profiles(tmp_path):
    engine = _file_engine(tmp_path)
    init_db(engine)
    Session = sessionmaker(bind=engine)
    with Session() as session:
        session.query(ChildProfile).filter_by(participant_code="demo-3").delete()
        session.commit()

    assert seed_demo_profiles(Session) == 1
    with Session() as session:
        assert session.query(ChildProfile).filter_by(participant_code="demo-3").count() == 1


def test_upgrades_database_created_by_first_release(tmp_path):
    """A database with the original schema keeps its rows and gains new columns."""
    path = tmp_path / "test.db"
    connection = sqlite3.connect(path)
    connection.executescript(
        """
        CREATE TABLE child_profiles (
            id INTEGER PRIMARY KEY, participant_code VARCHAR(50) NOT NULL UNIQUE,
            age_years INTEGER, created_at DATETIME DEFAULT CURRENT_TIMESTAMP);
        CREATE TABLE assessments (
            id INTEGER PRIMARY KEY, child_id INTEGER NOT NULL REFERENCES child_profiles(id),
            assessment_type VARCHAR(50) NOT NULL, status VARCHAR(30) NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP);
        CREATE TABLE screening_results (
            id INTEGER PRIMARY KEY, assessment_id INTEGER NOT NULL UNIQUE REFERENCES assessments(id),
            model_version VARCHAR(50), result_category VARCHAR(50), confidence_score FLOAT,
            modality_scores JSON, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP);
        INSERT INTO child_profiles (id, participant_code, age_years) VALUES (1, 'demo-1', 7), (5, 'legacy', 8);
        INSERT INTO assessments (id, child_id, assessment_type, status) VALUES (1, 1, 'screening', 'pending');
        """
    )
    connection.commit()
    connection.close()

    engine = create_engine(f"sqlite:///{path}")
    init_db(engine)
    init_db(engine)

    columns = {c["name"] for c in inspect(engine).get_columns("assessments")}
    assert {"user_id", "updated_at", "completed_at"} <= columns
    assert "owner_id" in {c["name"] for c in inspect(engine).get_columns("child_profiles")}

    connection = sqlite3.connect(path)
    profiles = connection.execute(
        "SELECT id, participant_code FROM child_profiles ORDER BY id"
    ).fetchall()
    assessment = connection.execute("SELECT id, status FROM assessments").fetchall()
    connection.close()

    # Existing rows keep their ids; the missing demo profiles are added.
    assert profiles[0] == (1, "demo-1")
    assert (5, "legacy") in profiles
    assert sorted(code for _, code in profiles) == ["demo-1", "demo-2", "demo-3", "demo-4", "legacy"]
    assert assessment == [(1, "in_progress")]
