import uuid

from fastapi.testclient import TestClient

from app.main import app


def test_health_check(client: TestClient):
    response = client.get("/api/v1/health")
    assert response.status_code == 200


def test_get_children(client: TestClient):
    response = client.get("/api/v1/children/")
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_create_and_get_assessment(client: TestClient):
    child_response = client.post(
        "/api/v1/children/",
        json={
            "participant_code": f"TEST_AUTO_{uuid.uuid4().hex[:8]}",
            "age_years": 10,
        },
    )
    assert child_response.status_code == 201

    child_id = child_response.json()["id"]

    assessment_response = client.post(
        "/api/v1/assessments/",
        json={"child_id": child_id, "assessment_type": "screening"},
    )
    assert assessment_response.status_code == 201

    assessment_id = assessment_response.json()["id"]
    get_response = client.get(f"/api/v1/assessments/{assessment_id}")

    assert get_response.status_code == 200
    assert get_response.json()["id"] == assessment_id


def test_update_assessment_status(client: TestClient):
    child_response = client.post(
        "/api/v1/children/",
        json={
            "participant_code": f"TEST_STATUS_{uuid.uuid4().hex[:8]}",
            "age_years": 10,
        },
    )
    assert child_response.status_code == 201

    child_id = child_response.json()["id"]

    assessment_response = client.post(
        "/api/v1/assessments/",
        json={"child_id": child_id, "assessment_type": "screening"},
    )
    assert assessment_response.status_code == 201

    assessment_id = assessment_response.json()["id"]

    response = client.patch(
        f"/api/v1/assessments/{assessment_id}/status",
        params={"status": "in_progress"},
    )
    assert response.status_code == 200


def test_create_and_get_result(client: TestClient):
    child_response = client.post(
        "/api/v1/children/",
        json={
            "participant_code": f"TEST_RESULT_{uuid.uuid4().hex[:8]}",
            "age_years": 10,
        },
    )
    assert child_response.status_code == 201

    child_id = child_response.json()["id"]

    assessment_response = client.post(
        "/api/v1/assessments/",
        json={"child_id": child_id, "assessment_type": "screening"},
    )
    assert assessment_response.status_code == 201

    assessment_id = assessment_response.json()["id"]

    result_response = client.post(
        "/api/v1/results/",
        json={
            "assessment_id": assessment_id,
            "model_version": "test-v1",
            "result_category": "test_result",
            "confidence_score": 0.75,
            "modality_scores": {
                "reading": 0.70,
                "writing": 0.80,
                "audio": 0.65,
            },
        },
    )
    assert result_response.status_code == 201

    result_id = result_response.json()["id"]
    get_response = client.get(f"/api/v1/results/{result_id}")

    assert get_response.status_code == 200

    result_data = get_response.json()
    assert result_data["confidence_score"] == 0.75
    assert result_data["modality_scores"]["reading"] == 0.70
    assert result_data["modality_scores"]["writing"] == 0.80
    assert result_data["modality_scores"]["audio"] == 0.65


def test_get_child_progress(client: TestClient):
    child_response = client.post(
        "/api/v1/children/",
        json={
            "participant_code": f"TEST_PROGRESS_{uuid.uuid4().hex[:8]}",
            "age_years": 10,
        },
    )
    assert child_response.status_code == 201

    child_id = child_response.json()["id"]

    assessment_response = client.post(
        "/api/v1/assessments/",
        json={"child_id": child_id, "assessment_type": "screening"},
    )
    assert assessment_response.status_code == 201

    assessment_id = assessment_response.json()["id"]

    result_response = client.post(
        "/api/v1/results/",
        json={
            "assessment_id": assessment_id,
            "model_version": "test-v1",
            "result_category": "test_result",
            "confidence_score": 0.75,
            "modality_scores": {
                "reading": 0.70,
                "writing": 0.80,
                "audio": 0.65,
            },
        },
    )
    assert result_response.status_code == 201

    progress_response = client.get(f"/api/v1/progress/{child_id}")
    assert progress_response.status_code == 200

    progress_data = progress_response.json()
    assert progress_data["child_id"] == child_id
    assert progress_data["total_assessments"] >= 1
    assert len(progress_data["assessment_history"]) >= 1

    history_item = next(
        item
        for item in progress_data["assessment_history"]
        if item["assessment_id"] == assessment_id
    )
    assert history_item["result"]["result_category"] == "test_result"