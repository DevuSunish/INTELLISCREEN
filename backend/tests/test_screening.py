"""The boundary between the application and the screening model."""

import pytest
from fastapi.testclient import TestClient

from app.db.database import SessionLocal
from app.main import app
from app.models.assessment import Assessment
from app.models.result import ScreeningResult
from app.screening.adapter import (
    InferenceError,
    ModelUnavailableError,
    ScreeningAdapterConfigError,
    ScreeningModelOutput,
    load_adapter,
)
from app.screening.dependencies import get_screening_adapter
from tests.conftest import API, complete_assessment, demo_child_id, start_assessment
from tests.fake_adapters import RecordingAdapter


@pytest.fixture
def use_adapter():
    """Install an adapter for the duration of a test (None = not configured)."""

    def install(adapter):
        app.dependency_overrides[get_screening_adapter] = lambda: adapter
        return adapter

    yield install
    app.dependency_overrides.pop(get_screening_adapter, None)


def screening(client, headers, assessment_id):
    return client.post(f"{API}/assessments/{assessment_id}/screening", headers=headers)


def stored(assessment_id):
    with SessionLocal() as session:
        assessment = session.get(Assessment, assessment_id)
        results = session.query(ScreeningResult).filter_by(assessment_id=assessment_id).count()
        return assessment.inference_status, assessment.inference_error, results


def test_app_works_without_a_model(client: TestClient, headers):
    # The default configuration has no adapter.
    assert get_screening_adapter() is None
    child_id = demo_child_id(client, headers)
    assessment_id = complete_assessment(client, headers, child_id)

    assessment = client.get(f"{API}/assessments/{assessment_id}", headers=headers).json()
    assert assessment["status"] == "completed"
    assert assessment["inference_status"] is None
    assert assessment["has_result"] is False
    assert len(assessment["activities"]) == 5

    response = screening(client, headers, assessment_id)
    assert response.status_code == 503
    assert "No screening model is configured" in response.json()["detail"]
    # Nothing was attempted, so nothing is marked failed or completed.
    assert stored(assessment_id) == (None, None, 0)

    history = client.get(f"{API}/progress/{child_id}", headers=headers).json()["assessment_history"]
    assert history[0]["result"] is None
    assert history[0]["inference_status"] is None


def test_completing_an_assessment_does_not_run_or_complete_inference(client, headers, use_adapter):
    adapter = use_adapter(RecordingAdapter())
    assessment_id = complete_assessment(client, headers, demo_child_id(client, headers))
    assert adapter.calls == []
    assert stored(assessment_id) == (None, None, 0)


def test_screening_requires_a_completed_assessment(client, headers, use_adapter):
    adapter = use_adapter(RecordingAdapter())
    assessment_id = start_assessment(client, headers, demo_child_id(client, headers))["id"]
    assert screening(client, headers, assessment_id).status_code == 409

    client.patch(f"{API}/assessments/{assessment_id}/status", json={"status": "cancelled"}, headers=headers)
    assert screening(client, headers, assessment_id).status_code == 409
    assert adapter.calls == []


def test_successful_inference_is_saved_and_not_repeated(client, headers, use_adapter):
    adapter = use_adapter(RecordingAdapter())
    child_id = demo_child_id(client, headers, "demo-4")
    assessment_id = complete_assessment(client, headers, child_id)

    created = screening(client, headers, assessment_id)
    assert created.status_code == 201
    result = created.json()
    assert result["assessment_id"] == assessment_id
    assert result["model_version"] == "test-model-1"
    assert stored(assessment_id) == ("completed", None, 1)

    # The adapter received the application's view of the assessment.
    (screening_input,) = adapter.calls
    assert screening_input.assessment_id == assessment_id
    assert screening_input.child_id == child_id
    assert screening_input.participant_code == "demo-4"
    assert screening_input.child_age_years == 8
    assert screening_input.activity_statuses == {
        key: "completed" for key in ("handwriting", "reading", "phonological", "ran", "memory")
    }
    assert screening_input.inputs == ()

    # Repeating the request returns the saved result without running the model.
    again = screening(client, headers, assessment_id)
    assert again.status_code == 200
    assert again.json()["id"] == result["id"]
    assert len(adapter.calls) == 1

    # Retrieval paths never run the model.
    assert client.get(f"{API}/results/{result['id']}", headers=headers).json()["id"] == result["id"]
    progress = client.get(f"{API}/progress/{child_id}", headers=headers).json()
    assert progress["results_available"] == 1
    assert progress["assessment_history"][0]["result"]["id"] == result["id"]
    assert progress["assessment_history"][0]["inference_status"] == "completed"
    assert len(adapter.calls) == 1


def test_dict_output_is_accepted(client, headers, use_adapter):
    use_adapter(RecordingAdapter(output={"model_version": "m-2", "result_category": "c"}))
    assessment_id = complete_assessment(client, headers, demo_child_id(client, headers))
    response = screening(client, headers, assessment_id)
    assert response.status_code == 201
    assert response.json()["confidence_score"] is None
    assert response.json()["modality_scores"] is None


@pytest.mark.parametrize(
    "output",
    [
        {"model_version": "m", "result_category": "c", "confidence_score": 1.2},
        {"model_version": "m", "result_category": "c", "modality_scores": {"audio": -0.1}},
        {"model_version": "m"},
        {"model_version": "", "result_category": "c"},
        {"model_version": "m", "result_category": "c", "diagnosis": "x"},
        ScreeningModelOutput.model_construct(model_version="m", result_category="c", confidence_score=7.0),
        "not a result",
        None,
    ],
)
def test_invalid_model_output_is_rejected(client, headers, use_adapter, output):
    adapter = use_adapter(RecordingAdapter())
    adapter.output = output
    assessment_id = complete_assessment(client, headers, demo_child_id(client, headers))

    response = screening(client, headers, assessment_id)
    assert response.status_code == 502
    status, error, results = stored(assessment_id)
    assert (status, results) == ("failed", 0)
    assert error.startswith("Invalid model output")


@pytest.mark.parametrize(
    ("error", "status_code", "reason"),
    [
        (ModelUnavailableError("weights not found"), 503, "Model unavailable: weights not found"),
        (InferenceError("audio too short"), 502, "Inference failed: audio too short"),
        (RuntimeError("bug in model code"), 502, "Inference failed: unexpected model error"),
    ],
)
def test_failed_inference_is_recorded_and_can_be_retried(
    client, headers, use_adapter, error, status_code, reason
):
    adapter = use_adapter(RecordingAdapter(error=error))
    child_id = demo_child_id(client, headers)
    assessment_id = complete_assessment(client, headers, child_id)

    response = screening(client, headers, assessment_id)
    assert response.status_code == status_code
    assert "bug in model code" not in response.text
    assert stored(assessment_id) == ("failed", reason, 0)
    history = client.get(f"{API}/progress/{child_id}", headers=headers).json()["assessment_history"]
    assert (history[0]["inference_status"], history[0]["result"]) == ("failed", None)

    # Retry after the model is fixed: exactly one result, failure cleared.
    adapter.error = None
    assert screening(client, headers, assessment_id).status_code == 201
    assert screening(client, headers, assessment_id).status_code == 200
    assert stored(assessment_id) == ("completed", None, 1)


def test_direct_result_upload_shares_the_lifecycle(client, headers, use_adapter):
    adapter = use_adapter(RecordingAdapter())
    assessment_id = complete_assessment(client, headers, demo_child_id(client, headers))
    posted = client.post(
        f"{API}/results/",
        json={"assessment_id": assessment_id, "model_version": "offline-1", "result_category": "c"},
        headers=headers,
    )
    assert posted.status_code == 201
    assert stored(assessment_id) == ("completed", None, 1)

    # The screening endpoint returns the existing result instead of running the model.
    assert screening(client, headers, assessment_id).json()["id"] == posted.json()["id"]
    assert adapter.calls == []


def test_screening_requires_authentication_and_ownership(client, headers, other_headers, use_adapter):
    adapter = use_adapter(RecordingAdapter())
    assessment_id = complete_assessment(client, headers, demo_child_id(client, headers))
    assert screening(client, {}, assessment_id).status_code == 401
    assert screening(client, {"Authorization": "Bearer invalid"}, assessment_id).status_code == 401
    assert screening(client, other_headers, assessment_id).status_code == 404
    assert screening(client, headers, 99999).status_code == 404
    assert adapter.calls == []


def test_load_adapter_from_setting():
    assert load_adapter("") is None
    assert isinstance(load_adapter("tests.fake_adapters:make_adapter"), RecordingAdapter)
    for spec in ("no_colon", "missing.module:factory", "tests.fake_adapters:missing", "tests.fake_adapters:not_an_adapter"):
        with pytest.raises(ScreeningAdapterConfigError):
            load_adapter(spec)
