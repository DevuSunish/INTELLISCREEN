from fastapi.testclient import TestClient

from app.db.database import SessionLocal
from app.models.activity_status import ActivityStatus
from app.models.assessment import Assessment
from tests.conftest import (
    ACTIVITY_KEYS,
    API,
    complete_all_activities,
    complete_assessment,
    demo_child_id,
    start_assessment,
)

RESULT_PAYLOAD = {
    "model_version": "test-v1",
    "result_category": "test_result",
    "confidence_score": 0.75,
    "modality_scores": {"reading": 0.70, "writing": 0.80, "audio": 0.65},
}


# --- Children -----------------------------------------------------------------


def test_children_lists_demo_profiles(client: TestClient, headers):
    response = client.get(f"{API}/children/", headers=headers)
    assert response.status_code == 200
    children = response.json()
    assert [(c["participant_code"], c["age_years"], c["is_demo"]) for c in children] == [
        ("demo-1", 7, True),
        ("demo-2", 6, True),
        ("demo-3", 5, True),
        ("demo-4", 8, True),
    ]
    assert all(isinstance(c["id"], int) for c in children)


def test_private_child_is_visible_only_to_owner(client: TestClient, headers, other_headers):
    created = client.post(
        f"{API}/children/",
        json={"participant_code": "private-1", "age_years": 9},
        headers=headers,
    )
    assert created.status_code == 201
    child = created.json()
    assert child["is_demo"] is False

    own_codes = [c["participant_code"] for c in client.get(f"{API}/children/", headers=headers).json()]
    other_codes = [c["participant_code"] for c in client.get(f"{API}/children/", headers=other_headers).json()]
    assert "private-1" in own_codes
    assert "private-1" not in other_codes

    assert client.get(f"{API}/children/{child['id']}", headers=other_headers).status_code == 404
    assert client.get(f"{API}/progress/{child['id']}", headers=other_headers).status_code == 404
    assert (
        client.post(f"{API}/assessments/", json={"child_id": child["id"]}, headers=other_headers).status_code
        == 404
    )


def test_duplicate_participant_code_is_rejected(client: TestClient, headers):
    response = client.post(
        f"{API}/children/", json={"participant_code": "demo-1"}, headers=headers
    )
    assert response.status_code == 409


# --- Assessments ----------------------------------------------------------------


def test_start_assessment_for_demo_child(client: TestClient, headers):
    child_id = demo_child_id(client, headers, "demo-2")
    response = client.post(f"{API}/assessments/", json={"child_id": child_id}, headers=headers)
    assert response.status_code == 201
    assessment = response.json()
    assert assessment["child_id"] == child_id
    assert assessment["status"] == "in_progress"
    assert assessment["assessment_type"] == "screening"
    assert assessment["activities"] == []
    assert assessment["has_result"] is False

    fetched = client.get(f"{API}/assessments/{assessment['id']}", headers=headers)
    assert fetched.status_code == 200
    assert fetched.json()["id"] == assessment["id"]


def test_start_assessment_is_idempotent_while_in_progress(client: TestClient, headers):
    child_id = demo_child_id(client, headers)
    first = client.post(f"{API}/assessments/", json={"child_id": child_id}, headers=headers)
    retry = client.post(f"{API}/assessments/", json={"child_id": child_id}, headers=headers)
    assert first.status_code == 201
    assert retry.status_code == 200
    assert retry.json()["id"] == first.json()["id"]

    listed = client.get(
        f"{API}/assessments/",
        params={"child_id": child_id, "status": "in_progress"},
        headers=headers,
    ).json()
    assert [a["id"] for a in listed] == [first.json()["id"]]


def test_start_assessment_rejects_invalid_input(client: TestClient, headers):
    assert client.post(f"{API}/assessments/", json={"child_id": 99999}, headers=headers).status_code == 404
    assert client.post(f"{API}/assessments/", json={"child_id": 0}, headers=headers).status_code == 422
    child_id = demo_child_id(client, headers)
    assert (
        client.post(
            f"{API}/assessments/",
            json={"child_id": child_id, "assessment_type": "other"},
            headers=headers,
        ).status_code
        == 422
    )


def test_status_transitions(client: TestClient, headers):
    child_id = demo_child_id(client, headers)
    assessment_id = start_assessment(client, headers, child_id)["id"]
    url = f"{API}/assessments/{assessment_id}/status"

    invalid = client.patch(url, json={"status": "pending"}, headers=headers)
    assert invalid.status_code == 422

    early = client.patch(url, json={"status": "completed"}, headers=headers)
    assert early.status_code == 409
    assert "Remaining" in early.json()["detail"]

    complete_all_activities(client, headers, assessment_id)
    completed = client.patch(url, json={"status": "completed"}, headers=headers)
    assert completed.status_code == 200
    assert completed.json()["status"] == "completed"
    assert completed.json()["completed_at"] is not None

    # Retried completion is harmless; leaving a terminal state is not allowed.
    assert client.patch(url, json={"status": "completed"}, headers=headers).status_code == 200
    assert client.patch(url, json={"status": "in_progress"}, headers=headers).status_code == 409
    assert client.patch(url, json={"status": "cancelled"}, headers=headers).status_code == 409


def test_cancelled_assessment_allows_a_new_one(client: TestClient, headers):
    child_id = demo_child_id(client, headers)
    first = start_assessment(client, headers, child_id)["id"]
    cancelled = client.patch(
        f"{API}/assessments/{first}/status", json={"status": "cancelled"}, headers=headers
    )
    assert cancelled.status_code == 200
    assert cancelled.json()["status"] == "cancelled"
    assert start_assessment(client, headers, child_id)["id"] != first


def test_status_update_persists(client: TestClient, headers):
    child_id = demo_child_id(client, headers)
    assessment_id = start_assessment(client, headers, child_id)["id"]
    client.patch(
        f"{API}/assessments/{assessment_id}/status", json={"status": "cancelled"}, headers=headers
    )
    with SessionLocal() as session:
        assert session.get(Assessment, assessment_id).status == "cancelled"


# --- Activity statuses ----------------------------------------------------------


def test_activity_status_create_update_and_list(client: TestClient, headers):
    child_id = demo_child_id(client, headers)
    assessment_id = start_assessment(client, headers, child_id)["id"]
    url = f"{API}/assessments/{assessment_id}/activities"

    created = client.put(f"{url}/reading", json={"status": "in_progress"}, headers=headers)
    assert created.status_code == 200
    assert created.json()["activity_key"] == "reading"
    assert created.json()["status"] == "in_progress"

    updated = client.put(f"{url}/reading", json={"status": "completed"}, headers=headers)
    assert updated.status_code == 200
    assert updated.json()["id"] == created.json()["id"]
    assert updated.json()["status"] == "completed"

    client.put(f"{url}/memory", json={"status": "in_progress"}, headers=headers)

    listed = client.get(url, headers=headers)
    assert listed.status_code == 200
    assert {(a["activity_key"], a["status"]) for a in listed.json()} == {
        ("reading", "completed"),
        ("memory", "in_progress"),
    }

    assessment = client.get(f"{API}/assessments/{assessment_id}", headers=headers).json()
    assert len(assessment["activities"]) == 2


def test_activity_status_has_no_duplicates_and_persists(client: TestClient, headers):
    child_id = demo_child_id(client, headers)
    assessment_id = start_assessment(client, headers, child_id)["id"]
    for status in ("in_progress", "completed", "completed"):
        client.put(
            f"{API}/assessments/{assessment_id}/activities/handwriting",
            json={"status": status},
            headers=headers,
        )

    # Read back through a new database session.
    with SessionLocal() as session:
        rows = (
            session.query(ActivityStatus)
            .filter(ActivityStatus.assessment_id == assessment_id)
            .all()
        )
        assert [(row.activity_key, row.status) for row in rows] == [("handwriting", "completed")]


def test_activity_status_validation(client: TestClient, headers):
    child_id = demo_child_id(client, headers)
    assessment_id = start_assessment(client, headers, child_id)["id"]
    url = f"{API}/assessments/{assessment_id}/activities"
    assert client.put(f"{url}/unknown", json={"status": "completed"}, headers=headers).status_code == 422
    assert client.put(f"{url}/reading", json={"status": "done"}, headers=headers).status_code == 422
    assert (
        client.put(f"{API}/assessments/99999/activities/reading", json={"status": "completed"}, headers=headers).status_code
        == 404
    )


def test_activities_of_finished_assessment_are_read_only(client: TestClient, headers):
    child_id = demo_child_id(client, headers)
    assessment_id = complete_assessment(client, headers, child_id)
    response = client.put(
        f"{API}/assessments/{assessment_id}/activities/reading",
        json={"status": "in_progress"},
        headers=headers,
    )
    assert response.status_code == 409


# --- Results --------------------------------------------------------------------


def test_save_and_get_result(client: TestClient, headers):
    child_id = demo_child_id(client, headers)
    assessment_id = complete_assessment(client, headers, child_id)

    created = client.post(
        f"{API}/results/", json={"assessment_id": assessment_id, **RESULT_PAYLOAD}, headers=headers
    )
    assert created.status_code == 201
    result_id = created.json()["id"]

    fetched = client.get(f"{API}/results/{result_id}", headers=headers)
    assert fetched.status_code == 200
    data = fetched.json()
    assert data["confidence_score"] == 0.75
    assert data["modality_scores"] == RESULT_PAYLOAD["modality_scores"]
    assert [r["id"] for r in client.get(f"{API}/results/", headers=headers).json()] == [result_id]
    assert client.get(f"{API}/assessments/{assessment_id}", headers=headers).json()["has_result"] is True


def test_result_validation(client: TestClient, headers):
    child_id = demo_child_id(client, headers)
    assessment_id = complete_assessment(client, headers, child_id)
    invalid_payloads = [
        {**RESULT_PAYLOAD, "confidence_score": 1.5},
        {**RESULT_PAYLOAD, "confidence_score": -0.1},
        {**RESULT_PAYLOAD, "modality_scores": {"reading": 2.0}},
        {**RESULT_PAYLOAD, "modality_scores": {"": 0.5}},
        {key: value for key, value in RESULT_PAYLOAD.items() if key != "result_category"},
    ]
    for payload in invalid_payloads:
        response = client.post(
            f"{API}/results/", json={"assessment_id": assessment_id, **payload}, headers=headers
        )
        assert response.status_code == 422, payload


def test_result_requires_existing_completed_assessment(client: TestClient, headers):
    missing = client.post(
        f"{API}/results/", json={"assessment_id": 99999, **RESULT_PAYLOAD}, headers=headers
    )
    assert missing.status_code == 404

    child_id = demo_child_id(client, headers)
    open_assessment = start_assessment(client, headers, child_id)["id"]
    not_completed = client.post(
        f"{API}/results/", json={"assessment_id": open_assessment, **RESULT_PAYLOAD}, headers=headers
    )
    assert not_completed.status_code == 409


def test_duplicate_result_is_rejected(client: TestClient, headers):
    child_id = demo_child_id(client, headers)
    assessment_id = complete_assessment(client, headers, child_id)
    payload = {"assessment_id": assessment_id, **RESULT_PAYLOAD}
    assert client.post(f"{API}/results/", json=payload, headers=headers).status_code == 201
    assert client.post(f"{API}/results/", json=payload, headers=headers).status_code == 409


# --- Authorization between accounts -----------------------------------------------


def test_users_cannot_access_each_others_records(client: TestClient, headers, other_headers):
    child_id = demo_child_id(client, headers)
    assessment_id = complete_assessment(client, headers, child_id)
    result_id = client.post(
        f"{API}/results/", json={"assessment_id": assessment_id, **RESULT_PAYLOAD}, headers=headers
    ).json()["id"]

    as_other = [
        client.get(f"{API}/assessments/{assessment_id}", headers=other_headers),
        client.get(f"{API}/assessments/{assessment_id}/activities", headers=other_headers),
        client.patch(f"{API}/assessments/{assessment_id}/status", json={"status": "cancelled"}, headers=other_headers),
        client.put(f"{API}/assessments/{assessment_id}/activities/reading", json={"status": "in_progress"}, headers=other_headers),
        client.get(f"{API}/results/{result_id}", headers=other_headers),
        client.post(f"{API}/results/", json={"assessment_id": assessment_id, **RESULT_PAYLOAD}, headers=other_headers),
    ]
    assert [r.status_code for r in as_other] == [404] * len(as_other)
    assert client.get(f"{API}/assessments/", headers=other_headers).json() == []
    assert client.get(f"{API}/results/", headers=other_headers).json() == []


def test_shared_demo_profile_progress_is_per_account(client: TestClient, headers, other_headers):
    child_id = demo_child_id(client, headers)
    complete_assessment(client, headers, child_id)

    other_progress = client.get(f"{API}/progress/{child_id}", headers=other_headers)
    assert other_progress.status_code == 200
    assert other_progress.json()["total_assessments"] == 0

    # The other account starts its own assessment for the same demo child.
    other_assessment = start_assessment(client, other_headers, child_id)
    assert other_assessment["status"] == "in_progress"
    assert client.get(f"{API}/progress/{child_id}", headers=headers).json()["total_assessments"] == 1


# --- Progress -------------------------------------------------------------------


def test_empty_progress(client: TestClient, headers):
    child_id = demo_child_id(client, headers, "demo-3")
    response = client.get(f"{API}/progress/{child_id}", headers=headers)
    assert response.status_code == 200
    assert response.json() == {
        "child_id": child_id,
        "participant_code": "demo-3",
        "total_assessments": 0,
        "completed_assessments": 0,
        "in_progress_assessments": 0,
        "results_available": 0,
        "assessment_history": [],
    }


def test_progress_history_activities_and_results(client: TestClient, headers):
    child_id = demo_child_id(client, headers, "demo-4")
    with_result = complete_assessment(client, headers, child_id)
    client.post(
        f"{API}/results/", json={"assessment_id": with_result, **RESULT_PAYLOAD}, headers=headers
    )
    without_result = complete_assessment(client, headers, child_id)
    open_assessment = start_assessment(client, headers, child_id)["id"]
    client.put(
        f"{API}/assessments/{open_assessment}/activities/ran",
        json={"status": "in_progress"},
        headers=headers,
    )

    response = client.get(f"{API}/progress/{child_id}", headers=headers)
    assert response.status_code == 200
    progress = response.json()
    assert progress["participant_code"] == "demo-4"
    assert progress["total_assessments"] == 3
    assert progress["completed_assessments"] == 2
    assert progress["in_progress_assessments"] == 1
    assert progress["results_available"] == 1

    history = {item["assessment_id"]: item for item in progress["assessment_history"]}
    assert set(history) == {with_result, without_result, open_assessment}

    assert history[with_result]["result"]["result_category"] == "test_result"
    assert history[with_result]["result"]["model_version"] == "test-v1"
    assert history[without_result]["result"] is None
    assert history[without_result]["completed_at"] is not None
    assert {a["activity_key"] for a in history[without_result]["activities"]} == set(ACTIVITY_KEYS)
    assert [(a["activity_key"], a["status"]) for a in history[open_assessment]["activities"]] == [
        ("ran", "in_progress")
    ]
    assert history[open_assessment]["assessment_status"] == "in_progress"
    assert history[open_assessment]["assessment_date"].endswith("Z")  # explicit UTC


def test_progress_for_unknown_child(client: TestClient, headers):
    assert client.get(f"{API}/progress/99999", headers=headers).status_code == 404
