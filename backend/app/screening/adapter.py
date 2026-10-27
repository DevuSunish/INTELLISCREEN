"""Contract for the screening-model implementation.

Implement ScreeningModelAdapter and point INTELLISCREEN_SCREENING_ADAPTER at a
factory ("package.module:factory") that returns an instance. Without that
setting no model is connected and inference requests return 503.
"""

import importlib
from dataclasses import dataclass, field
from datetime import datetime
from typing import Mapping, Protocol, runtime_checkable

from app.schemas.result import ScreeningModelOutput

__all__ = [
    "InputReference",
    "ScreeningInput",
    "ScreeningModelOutput",
    "ScreeningModelAdapter",
    "ModelUnavailableError",
    "InferenceError",
    "ScreeningAdapterConfigError",
    "load_adapter",
]


@dataclass(frozen=True)
class InputReference:
    """A stored input captured during an activity (audio, image, ...).

    The app does not capture or upload any inputs yet, so ScreeningInput.inputs
    is always empty today. See docs/MULTIMODAL_INTEGRATION.md.
    """

    activity_key: str
    modality: str
    storage_key: str
    content_type: str


@dataclass(frozen=True)
class ScreeningInput:
    """Everything the application knows about a completed assessment."""

    assessment_id: int
    child_id: int
    participant_code: str
    child_age_years: int | None
    assessment_type: str
    completed_at: datetime | None
    # activity key -> status, for the activities that have a saved status.
    activity_statuses: Mapping[str, str]
    # Inputs available for this assessment; empty until input capture exists.
    # A model must not assume any modality is present.
    inputs: tuple[InputReference, ...] = field(default_factory=tuple)


class ModelUnavailableError(Exception):
    """The model cannot run right now (e.g. weights or service unavailable)."""


class InferenceError(Exception):
    """The model ran but could not produce a result for this input."""


class ScreeningAdapterConfigError(Exception):
    """INTELLISCREEN_SCREENING_ADAPTER does not point at a usable adapter."""


@runtime_checkable
class ScreeningModelAdapter(Protocol):
    def predict(self, screening_input: ScreeningInput) -> ScreeningModelOutput:
        """Return the model output for one assessment.

        Raise ModelUnavailableError or InferenceError instead of returning a
        placeholder. Returning a ScreeningModelOutput means the model genuinely
        produced it. A plain dict with the same fields is also accepted; it is
        validated the same way.
        """
        ...


def load_adapter(spec: str) -> ScreeningModelAdapter | None:
    """Build the adapter named by "package.module:factory", or None if unset."""
    if not spec:
        return None
    module_name, _, attribute = spec.partition(":")
    if not module_name or not attribute:
        raise ScreeningAdapterConfigError(
            f"Expected 'package.module:factory', got {spec!r}"
        )
    try:
        factory = getattr(importlib.import_module(module_name), attribute)
    except (ImportError, AttributeError) as error:
        raise ScreeningAdapterConfigError(f"Cannot load {spec!r}: {error}") from error

    adapter = factory()
    if not isinstance(adapter, ScreeningModelAdapter):
        raise ScreeningAdapterConfigError(f"{spec!r} did not return an object with predict()")
    return adapter
