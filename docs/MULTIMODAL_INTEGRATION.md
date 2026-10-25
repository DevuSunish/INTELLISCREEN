# INTELLISCREEN: multimodal integration guide

For the developer implementing multimodal screening. It describes what exists
in the repository today, the boundary the model plugs into, and what is left for
the multimodal phase. Everything named here (paths, endpoints, schemas) exists
in the code unless it is explicitly marked **planned**.

INTELLISCREEN is an educational screening tool for early dyslexia and
dysgraphia indicators. It is not a diagnostic application. The four child
profiles are demonstration profiles, not real children.

---

## 1. Architecture and directory structure

```
INTELLISCREEN/
├── backend/                    FastAPI + SQLAlchemy + SQLite
│   ├── app/
│   │   ├── main.py             App, CORS, router registration, startup (init_db + adapter check)
│   │   ├── core/
│   │   │   ├── config.py       Settings from environment variables
│   │   │   ├── constants.py    Status vocabularies, activity keys, demo participant codes
│   │   │   └── security.py     PBKDF2 password hashing, HS256 access tokens
│   │   ├── api/
│   │   │   ├── deps.py         get_current_user (bearer-token dependency)
│   │   │   ├── access.py       Authorization rules (who can see which records)
│   │   │   └── v1/endpoints/   auth.py, children.py, assessments.py, results.py, progress.py
│   │   ├── db/
│   │   │   ├── database.py     Engine, SessionLocal, get_db
│   │   │   ├── init_db.py      Create tables, upgrade older schemas, seed
│   │   │   └── seed_demo_profiles.py
│   │   ├── models/             User, ChildProfile, Assessment, ActivityStatus, ScreeningResult
│   │   ├── schemas/            Pydantic request/response models
│   │   └── screening/          ← the model boundary (section 9)
│   │       ├── adapter.py      ScreeningModelAdapter protocol, ScreeningInput, errors, load_adapter
│   │       ├── service.py      run_screening / save_result: inference lifecycle and persistence
│   │       └── dependencies.py get_screening_adapter (FastAPI dependency)
│   └── tests/                  pytest suite (isolated in-memory database)
├── frontend/                   Flutter app (Linux desktop is the verified target)
│   ├── lib/
│   │   ├── main.dart           App root, sign-in/registration, dashboard, session expiry
│   │   ├── services/           api_client.dart, auth_api_service.dart, child_api_service.dart
│   │   ├── models/             assessment_activity.dart (activity catalog), progress.dart (API DTOs),
│   │   │                       child_record.dart (profiles + ChildrenStore), json_utils.dart
│   │   ├── state/              assessment_controller.dart (workflow state, backed by the API)
│   │   └── screens/            children, child profile, assessment workflow, activity detail
│   ├── test/                   Unit/widget tests with mocked HTTP
│   └── integration_test/       app_flow_test.dart: UI flow against a running backend
├── docs/MULTIMODAL_INTEGRATION.md   this file
└── IMPLEMENTATION_NOTES.md     Short operational notes
```

Layering on the backend: endpoints → access rules (`app/api/access.py`) →
models. The screening model is reached only through `app/screening/`. Nothing
else in the application imports model code.

## 2. Backend setup and launch

Requires Python 3.12 (the version used so far).

```bash
cd backend
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m uvicorn app.main:app --reload          # http://127.0.0.1:8000
```

Interactive API docs: `http://127.0.0.1:8000/docs`.

| Environment variable | Default | Purpose |
| --- | --- | --- |
| `INTELLISCREEN_DATABASE_URL` | `sqlite:///<backend>/intelliscreen.db` | Database (path does not depend on the working directory) |
| `INTELLISCREEN_TOKEN_SECRET` | random, generated once into `backend/.intelliscreen_secret` (git-ignored) | Token signing secret |
| `INTELLISCREEN_ACCESS_TOKEN_EXPIRE_MINUTES` | `720` | Token lifetime |
| `INTELLISCREEN_PASSWORD_HASH_ITERATIONS` | `600000` | PBKDF2 iterations for new passwords |
| `INTELLISCREEN_SCREENING_ADAPTER` | unset (no model) | `package.module:factory` of the model adapter (section 9) |

## 3. Flutter setup and launch

```bash
cd frontend
flutter pub get
flutter run -d linux
```

API base URL (`lib/services/api_client.dart`, `ApiConfig`): `http://127.0.0.1:8000/api/v1`
on Linux desktop and web, `http://10.0.2.2:8000/api/v1` on the Android emulator
(Android is not tested). Override with
`--dart-define=INTELLISCREEN_API_URL=http://<host>:8000/api/v1`.

## 4. Database initialization and demo profiles

`app/db/init_db.py:init_db()` runs on every startup (from the lifespan in
`app/main.py`), and can also be run by hand with `.venv/bin/python -m app.db.init_db`. It:

1. creates missing tables (`Base.metadata.create_all`);
2. upgrades databases created by earlier versions by adding missing columns
   (`_ADDED_COLUMNS`); it never drops or rewrites data except two status
   normalizations: legacy `pending` becomes `in_progress`, and assessments that already
   have a result get `inference_status = completed`;
3. inserts any missing demo profile (`app/db/seed_demo_profiles.py`, `DEMO_PROFILES`):
   `demo-1` (age 7), `demo-2` (6), `demo-3` (5), `demo-4` (8). Existing rows are
   never modified, so repeated starts create no duplicates.

There is no Alembic. If you add columns, add them to `_ADDED_COLUMNS` (and to
the model) so existing developer databases keep working, and add a case to
`tests/test_database.py`.

## 5. Authentication

- Public: `GET /api/v1/health`, `POST /api/v1/auth/register` (`RegisterRequest`:
  `email`, `password` 8–128 chars, `role` `parent|teacher`) and
  `POST /api/v1/auth/login` (`LoginRequest`). Both return `AuthResponse`
  (`access_token`, `token_type: "bearer"`, `expires_in`, `user`).
- Everything else requires `Authorization: Bearer <access_token>`; missing, malformed,
  tampered or expired tokens get `401`. The dependency is
  `app/api/deps.py:get_current_user`.
- Authorization (`app/api/access.py`): the four demo profiles are shared by all
  accounts. Assessments, activity statuses and results belong to the account
  that started the assessment; other accounts get `404`.
- In Flutter the token is kept in memory (`AuthSession` in `api_client.dart`); users
  sign in again after restarting the app.

Quick start with curl:

```bash
API=http://127.0.0.1:8000/api/v1
TOKEN=$(curl -s -X POST $API/auth/register -H 'Content-Type: application/json' \
  -d '{"email":"dev@example.com","password":"devPassword123"}' | python3 -c 'import json,sys;print(json.load(sys.stdin)["access_token"])')
curl -s $API/children/ -H "Authorization: Bearer $TOKEN"
```

(Use `/auth/login` with the same body once the account exists.)

## 6. Child profiles and ids

`GET /api/v1/children/` returns `ChildProfileResponse` items: `id` (database
id), `participant_code`, `age_years`, `is_demo`, `created_at`.

- Always use `id` in API calls. Do not derive it from the participant code; the
  ids of `demo-1`…`demo-4` depend on the database.
- The Flutter app matches profiles to presentation details (display name, grade,
  gender, date of birth, notes) by `participant_code`
  (`demoPresentations` in `lib/models/child_record.dart`). Those details are **not
  stored in the backend** and must not be used as model features.
- `POST /api/v1/children/` creates a profile owned by the caller. The app UI does not use it.

## 7. Assessments and activities

Vocabularies are in `app/core/constants.py` and mirrored in Flutter
(`ActivityStatusApi`, `AssessmentStatusApi`, `InferenceStatus`).

| Endpoint | Body / query | Response | Notes |
| --- | --- | --- | --- |
| `POST /api/v1/assessments/` | `AssessmentCreate` (`child_id`, `assessment_type: "screening"`) | `AssessmentResponse`, 201 | Returns the caller's open assessment for that child with **200** instead of creating a second one |
| `GET /api/v1/assessments/` | `?child_id=&status=` | `list[AssessmentResponse]` | Caller's assessments only |
| `GET /api/v1/assessments/{assessment_id}` | | `AssessmentResponse` | Includes `activities`, `inference_status`, `inference_error`, `has_result` |
| `PATCH /api/v1/assessments/{assessment_id}/status` | `AssessmentStatusUpdate` (`status`) | `AssessmentResponse` | See transitions below |
| `GET /api/v1/assessments/{assessment_id}/activities` | | `list[ActivityStatusResponse]` | |
| `PUT /api/v1/assessments/{assessment_id}/activities/{activity_key}` | `ActivityStatusUpdate` (`status`) | `ActivityStatusResponse` | Creates or updates; idempotent |

Activity keys (`SCREENING_ACTIVITY_KEYS`, matching `ScreeningActivities.all` in
`lib/models/assessment_activity.dart`): `handwriting`, `reading`, `phonological`, `ran`, `memory`.
Activity status: `not_started`, `in_progress`, `completed`. There is at most one row per
assessment and activity (unique constraint `uq_activity_status_assessment_key`).
Activities are read-only once the assessment is no longer `in_progress` (409).

Assessment transitions: `in_progress` → `completed` (only when all five
activities are `completed`, otherwise 409 listing the remaining ones) or
`in_progress` → `cancelled`. Both are final. Re-sending the current status returns 200 (safe retry).

## 8. Screening results: schemas and endpoints

Model: `app/models/result.py:ScreeningResult` (`assessment_id` unique, `model_version`,
`result_category`, `confidence_score`, `modality_scores` JSON, `created_at`).

Schemas (`app/schemas/result.py`):

- `ScreeningModelOutput`: what a model produces. `model_version` (1–50 chars,
  required), `result_category` (1–50 chars, required), `confidence_score` (0–1,
  optional), `modality_scores` (optional map of up to 20 names to scores in 0–1; NaN rejected).
  Unknown fields are rejected.
- `ScreeningResultCreate` = `ScreeningModelOutput` + `assessment_id`.
- `ScreeningResultResponse`: the stored row.

| Endpoint | Purpose |
| --- | --- |
| `POST /api/v1/assessments/{assessment_id}/screening` | Run the configured adapter and store its output (section 9) |
| `POST /api/v1/results/` | Store output produced outside the API (e.g. an offline batch job), body `ScreeningResultCreate` |
| `GET /api/v1/results/`, `GET /api/v1/results/{result_id}` | Read saved results (caller's own only) |
| `GET /api/v1/progress/{child_id}` | `ChildProgressResponse`: counts and `assessment_history` (`AssessmentHistoryItem`), each with `activities`, `inference_status`, `inference_error` and `result` |

Both write paths go through `app/screening/service.py:save_result`, so they
share the rules: only for `completed` assessments (409 otherwise), one result per
assessment (409 on duplicates, enforced by the unique column too), and the save
sets `inference_status = completed` in the same transaction. Reading a result
never runs the model.

## 9. The model adapter

Defined in `backend/app/screening/adapter.py`:

```python
class ScreeningModelAdapter(Protocol):
    def predict(self, screening_input: ScreeningInput) -> ScreeningModelOutput: ...
```

`ScreeningInput` (built by `service.build_screening_input`):

| Field | Meaning |
| --- | --- |
| `assessment_id`, `child_id`, `participant_code` | References to the assessment and child |
| `child_age_years` | From the backend profile (may be `None`) |
| `assessment_type` | Currently always `"screening"` |
| `completed_at` | Completion timestamp |
| `activity_statuses` | `{activity_key: status}` for activities with a saved status |
| `inputs` | `tuple[InputReference, ...]` (`activity_key`, `modality`, `storage_key`, `content_type`). **Always empty today**: the app collects no media or responses yet (section 10). Never assume a modality is present. |

How the adapter must behave:

- Return a `ScreeningModelOutput` (or a dict with its fields) only when the model actually
  produced it. Include only the modality scores the model computed from inputs that exist.
- Raise `ModelUnavailableError` when the model cannot run (missing weights, service down) and
  `InferenceError` when it ran but cannot score this input (e.g. insufficient data). Never
  return a placeholder result.
- Keep it free of database, authentication and HTTP concerns. The service handles them.

Connecting an adapter:

```python
# e.g. backend/app/screening/my_model.py  (planned; does not exist yet)
from app.screening.adapter import ScreeningInput, ScreeningModelOutput, InferenceError

class MultimodalAdapter:
    def __init__(self):
        ...  # load weights once

    def predict(self, screening_input: ScreeningInput) -> ScreeningModelOutput:
        if not screening_input.inputs:
            raise InferenceError("no assessment inputs available")
        ...

def create_adapter():
    return MultimodalAdapter()
```

```bash
INTELLISCREEN_SCREENING_ADAPTER=app.screening.my_model:create_adapter \
  .venv/bin/python -m uvicorn app.main:app
```

The factory is called once (cached by `get_screening_adapter`). A wrong setting
stops the server at startup with `ScreeningAdapterConfigError`. With the variable
unset, the app runs normally and screening requests return 503.

In tests, override the dependency instead of setting the environment variable
(see `tests/test_screening.py`, fixture `use_adapter`, and `tests/fake_adapters.py`;
those fake adapters exist only to test the boundary).

### Result lifecycle

| Stage | How it is represented |
| --- | --- |
| Assessment created / in progress | `assessments.status = in_progress` |
| Assessment completed | `status = completed`, `completed_at` set; requires all five activities completed |
| Inference not requested | `inference_status = NULL`. Completing an assessment never starts or completes inference |
| Inference pending | `inference_status = pending` (committed before `predict` runs) |
| Inference failed | `inference_status = failed`, `inference_error` holds a short reason; no result row |
| Inference completed and result saved | `inference_status = completed` and a `screening_results` row, written in one transaction |

`POST /api/v1/assessments/{assessment_id}/screening` responses:

| Code | When | State change |
| --- | --- | --- |
| 201 | Model produced valid output; result stored | → `completed` + result |
| 200 | A result already exists; returned as is, model **not** run | none |
| 409 | Assessment not completed (in progress or cancelled) | none |
| 503 | No adapter configured | none (stays `NULL`) |
| 503 | Adapter raised `ModelUnavailableError` | → `failed` |
| 502 | `InferenceError`, unexpected exception, or output failed validation | → `failed` |
| 401 / 404 | Bad token / not the caller's assessment | none |

Retrying is safe: `pending` and `failed` can be requested again, and the unique result
constraint guarantees at most one result. Inference runs synchronously inside the request;
see section 12.

## 10. Inputs: what exists and what the model will need

What each activity collects today (from `lib/screens/activity_detail_screen.dart`
and `lib/state/assessment_controller.dart`): the screens show the protocol text and three
buttons (Mark In Progress, Mark Completed, Reset to Not Started). **The only data captured
is the activity status.** No audio, images, handwriting strokes, timings, answers or
observer notes are recorded or sent.

| Activity (`key`) | Inputs collected now | Persisted | Reachable by backend | Work needed before a model can use it |
| --- | --- | --- | --- | --- |
| Handwriting (`handwriting`) | Activity status only | Status: yes (`activity_statuses`) | Status: yes | Capture a writing sample (photo/scan of paper, or pen strokes on a tablet), upload and store it, link it to the assessment |
| Reading (`reading`) | Activity status only | Status: yes | Status: yes | Record oral reading audio; store the word list/passage shown; optionally observer marks (errors, WCPM) |
| Phonological awareness (`phonological`) | Activity status only | Status: yes | Status: yes | Record spoken answers per item (audio) or observer correct/incorrect marks; store item ids |
| RAN (`ran`) | Activity status only | Status: yes | Status: yes | Record naming audio and timing (start/stop, total seconds); store the grid presented |
| Memory (`memory`) | Activity status only | Status: yes | Status: yes | Record responses per item (audio or typed/observer-scored sequences); store item ids |

The demo-profile notes in Flutter are illustrative presentation text, not observations, and
are not available to the backend.

Modalities relevant to these activities: **audio** (reading, phonological, RAN, memory),
**image or pen-stroke data** (handwriting), **timing data** (RAN, reading), and **structured
item responses/observer scores** (all activities). Video is not part of any current
activity protocol and is not proposed here.

### Proposed extension points (planned, not implemented)

Media upload is **not in the current scope**, so nothing below exists yet. Suggested design,
consistent with the existing code:

- Table `assessment_inputs`: `id`, `assessment_id` (FK), `activity_key`, `modality`
  (`audio`, `image`, `strokes`, `timing`, `responses`), `storage_key`, `content_type`,
  `size_bytes`, `sha256`, `created_at`. Add it with a model plus `init_db` (create_all covers new tables).
- `POST /api/v1/assessments/{assessment_id}/inputs` (multipart: `activity_key`, `modality`,
  file) and `GET /api/v1/assessments/{assessment_id}/inputs`. Same ownership rule as
  assessments (use `get_owned_assessment`), allowed only while the assessment is
  `in_progress`.
- Validation: allow-list of content types per modality (e.g. `audio/wav`, `audio/mp4`;
  `image/png`, `image/jpeg`; JSON for strokes/timing/responses), size limits (e.g. audio
  ≤ 20 MB, image ≤ 10 MB, JSON ≤ 1 MB, to be confirmed), sniff the actual file type
  rather than trusting the header, and reject unknown activity keys.
- Storage: files outside the web root under a configurable directory (or object storage)
  keyed by a random `storage_key`, never by user-supplied names. Do not serve them publicly.
  Treat them as children's data: retention and deletion policy, and consent, before real use.
- `build_screening_input` then fills `ScreeningInput.inputs` from that table. The adapter
  reads files through a storage helper, never through HTTP.
- Flutter: capture widgets in the activity screens, upload through `ApiClient` (it would
  need a multipart method), then mark the activity completed.

## 11. Tests and analysis

```bash
cd backend && .venv/bin/python -m pytest -q        # isolated in-memory DB, never touches intelliscreen.db
cd frontend && flutter analyze && flutter test     # HTTP mocked
```

UI flow on Linux against a running backend (registers the given account; run the second
command as a separate process to check persistence across an app restart):

```bash
cd frontend
flutter test integration_test/app_flow_test.dart -d linux \
  --dart-define=INTELLISCREEN_API_URL=http://127.0.0.1:8000/api/v1 \
  --dart-define=E2E_EMAIL=someone@example.com --dart-define=E2E_PHASE=assess
flutter test integration_test/app_flow_test.dart -d linux \
  --dart-define=INTELLISCREEN_API_URL=http://127.0.0.1:8000/api/v1 \
  --dart-define=E2E_EMAIL=someone@example.com --dart-define=E2E_PHASE=verify
```

Boundary tests to keep green: `backend/tests/test_screening.py`.

## 12. Limitations and work reserved for the multimodal phase

Current limitations:

- No model, and no input capture; `ScreeningInput.inputs` is always empty.
- The Flutter app never calls `POST /assessments/{assessment_id}/screening`. It shows
  `inference_status` and any saved result in the history (`child_profile_screen.dart`,
  `_noResultText`) but has no "run screening" action.
- Inference runs synchronously inside the HTTP request. A long-running model should move to a
  background worker; the `pending` state already exists for that. Stale `pending` rows are
  not cleaned up automatically, but they can be retried.
- Tokens are kept in memory only (no libsecret on Linux); Android is untested.
- SQLite with hand-written column upgrades, no Alembic.
- `result_category` is free text (max 50). Define the category set together with its
  non-diagnostic wording before showing results to parents or teachers.

Reserved for the multimodal developer:

- Model architecture, training, weights and dependencies (add them to
  `backend/requirements.txt` only when chosen).
- Input capture in Flutter and the upload/storage design in section 10.
- Modality-specific preprocessing (audio, handwriting image/strokes, timing, item responses).
- Inference and fusion across modalities, with missing modalities handled.
- Calibration of `confidence_score` and the meaning of `modality_scores`.
- Result categories, their user-facing wording, and how the app presents them.
- Triggering screening from the app and background execution if needed.
- Validation, evaluation and consent/data-protection review before use with real children.

Suggested start: branch from `feature/backend-integration`, e.g.
`git switch -c feature/multimodal-screening`.
