# INTELLISCREEN: implementation notes

## Running

Backend (from `backend/`):

```bash
python -m pip install -r requirements.txt
python -m uvicorn app.main:app --reload
```

Startup creates missing tables, upgrades older databases in place (adds columns,
never drops data) and seeds the four demo profiles if they are missing.

| Variable | Default | Purpose |
| --- | --- | --- |
| `INTELLISCREEN_TOKEN_SECRET` | random value generated once into `backend/.intelliscreen_secret` (git-ignored) | Token signing secret. Set it explicitly in any shared deployment. |
| `INTELLISCREEN_DATABASE_URL` | `sqlite:///<backend>/intelliscreen.db` | Database location (independent of the working directory). |
| `INTELLISCREEN_ACCESS_TOKEN_EXPIRE_MINUTES` | `720` | Token lifetime. |

Frontend (from `frontend/`): `flutter run -d linux`. The API defaults to
`http://127.0.0.1:8000/api/v1` (Linux desktop/web) and `http://10.0.2.2:8000/api/v1`
on the Android emulator. Override with
`--dart-define=INTELLISCREEN_API_URL=http://<host>:8000/api/v1`.

## API

Public: `GET /api/v1/health`, `POST /auth/register`, `POST /auth/login`.
Everything else requires `Authorization: Bearer <token>`.

| Endpoint | Purpose |
| --- | --- |
| `GET /auth/me` | Current account |
| `GET /children/`, `GET /children/{id}` | Profiles visible to the account |
| `POST /children/` | Create a profile owned by the account (not used by the app UI) |
| `POST /assessments/` | Start an assessment; returns the open one (200) if the account already has one in progress for that child, otherwise creates it (201) |
| `GET /assessments/?child_id=&status=` | The account's assessments |
| `GET /assessments/{id}` | One assessment with its activity statuses |
| `PATCH /assessments/{id}/status` | `{"status": "completed" \| "cancelled"}` |
| `GET /assessments/{id}/activities` | Activity statuses |
| `PUT /assessments/{id}/activities/{key}` | `{"status": ...}`; creates or updates (idempotent) |
| `POST /results/`, `GET /results/`, `GET /results/{id}` | Screening model output |
| `GET /progress/{child_id}` | Counts and full history (activities, result) for the account |

### Status vocabulary

- Assessment: `in_progress` → `completed` or `cancelled` (both final). "Not started"
  means no assessment exists. Completing requires all five activities completed.
  Repeating the current status is accepted so retries are harmless.
- Activity keys: `handwriting`, `reading`, `phonological`, `ran`, `memory`.
  Activity status: `not_started`, `in_progress`, `completed`. One row per
  assessment and activity (unique constraint). Read-only once the assessment is finished.
- Results: one per assessment, only for completed assessments; `model_version`
  and `result_category` required, scores within 0–1.

### Authorization rules

- The four demo profiles (`demo-1`…`demo-4`, no owner) are shared: every signed-in
  account can see them and run assessments for them.
- Other profiles are visible only to their owner. Older profiles without an owner
  that are not demo profiles (for example ones created with the removed Add Child
  screen) stay in the database but are not exposed by the API.
- Assessments, activity statuses and results belong to the account that started the
  assessment. Other accounts get 404 and do not see them in lists or progress. Each
  account therefore has its own history for the shared demo profiles.
- Assessments created before this change have no owner and are not exposed.

## Frontend

- Sign-in and registration use the backend; the dashboard opens only after a real
  token is returned. Closing the dashboard (Sign Out or back) clears the token. Any
  401 from a protected endpoint ends the session and returns to sign-in.
- The token is held in memory only. Secure storage on Linux needs libsecret, which
  is not installed or used, so users sign in again after restarting the app. Saved
  data is unaffected.
- Child Profiles shows the profiles returned by `GET /children/` and uses their
  database ids. Names, grade, gender, date of birth and notes of the four demo
  children are presentation-only defaults keyed by participant code; age and
  registration date come from the backend.
- The profile screen's history, status and counts, and the dashboard statistics, come
  from `GET /progress/{id}`. There is no hardcoded history.
- The assessment workflow resumes the saved in-progress assessment, saves each
  activity status via `PUT`, and completes or cancels it via `PATCH`.

## Screening model

No screening model is integrated. Completing an assessment records the completed
activities only; no result is created, and the app says that no result has been
generated. The result endpoints are ready for real model output.

## Tests

- Backend: `cd backend && python -m pytest` (in-memory database; never touches
  `intelliscreen.db`).
- Frontend: `cd frontend && flutter analyze && flutter test` (HTTP is mocked).
- UI end-to-end on Linux against a running backend (registers the given account):

  ```bash
  flutter test integration_test/app_flow_test.dart -d linux \
    --dart-define=INTELLISCREEN_API_URL=http://127.0.0.1:8000/api/v1 \
    --dart-define=E2E_EMAIL=someone@example.com --dart-define=E2E_PHASE=assess
  # then the same command with E2E_PHASE=verify (a fresh app process)
  ```
