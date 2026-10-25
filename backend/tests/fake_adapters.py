"""Adapters used only by tests to exercise the model boundary."""

from app.screening.adapter import ScreeningModelOutput


class RecordingAdapter:
    """Returns a fixed, test-only output and records every call."""

    def __init__(self, output=None, error: Exception | None = None):
        self.output = output if output is not None else ScreeningModelOutput(
            model_version="test-model-1",
            result_category="test_category",
            confidence_score=0.5,
            modality_scores={"reading": 0.4},
        )
        self.error = error
        self.calls = []

    def predict(self, screening_input):
        self.calls.append(screening_input)
        if self.error is not None:
            raise self.error
        return self.output


def make_adapter():
    return RecordingAdapter()


def not_an_adapter():
    return object()
