# INTELLISCREEN

**A Cross-Platform Screening Application for Early Identification of Potential Dyslexia-Related Difficulties**

INTELLISCREEN is a screening application designed to support the structured assessment of children through interactive activities. It combines a Flutter frontend with a FastAPI backend to manage user authentication, child profiles, assessment sessions, activity progress, and screening results.

The project establishes the application and backend infrastructure for future integration with multimodal screening models. The screening model itself is a separate component and must be integrated and validated before the application can produce model-based screening results.

> **Important:** INTELLISCREEN is intended for screening support, not as a standalone diagnostic system. It must not be used to diagnose dyslexia or replace assessment by a qualified professional.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Features](#features)
3. [Technology Stack](#technology-stack)
4. [Project Structure](#project-structure)
5. [System Architecture](#system-architecture)
6. [Prerequisites](#prerequisites)
7. [Installation and Setup](#installation-and-setup)
8. [Configuration](#configuration)
9. [Running the Application](#running-the-application)
10. [Authentication and Authorization](#authentication-and-authorization)
11. [Demo Child Profiles](#demo-child-profiles)
12. [Assessment Workflow](#assessment-workflow)
13. [Database and Data Persistence](#database-and-data-persistence)
14. [API Overview](#api-overview)
15. [Testing](#testing)
16. [Multimodal Model Integration](#multimodal-model-integration)
17. [Security and Privacy](#security-and-privacy)
18. [Known Limitations](#known-limitations)
19. [Git Workflow](#git-workflow)
20. [Troubleshooting](#troubleshooting)
21. [Future Development](#future-development)
22. [Contributing](#contributing)

---

## 1. Project Overview

INTELLISCREEN is structured as a client-server application.

The frontend provides the user interface for signing in, viewing child profiles, managing assessment sessions, completing activities, and viewing saved assessment history.

The backend exposes a REST API that handles authentication, database operations, assessment lifecycle management, activity progress, and results.

The database stores persistent application data. A future multimodal screening component will process appropriate assessment inputs and return validated model outputs through a defined integration interface.

### Project objectives

- Provide a cross-platform application using Flutter.
- Manage authentication through the backend.
- Retrieve child profiles from persistent storage.
- Track assessment sessions and activity completion.
- Preserve progress when the application is closed and reopened.
- Keep assessment results separate from activity completion.
- Avoid generating fabricated screening scores or diagnoses.
- Establish a maintainable integration point for future multimodal screening models.

### Current development stage

The application and backend integration have been implemented and tested according to the project's development report.

The multimodal screening model is **not yet integrated**. Model-based screening results should not be considered available until that integration is completed and validated.

---

## 2. Features

### Frontend

- User registration and login.
- Backend-authenticated application access.
- Dashboard with backend-derived information.
- Child profile listing.
- Child profile details and assessment history.
- Assessment creation and lifecycle management.
- Activity completion tracking.
- Loading, error, retry, and empty states.
- Persistent assessment and activity information retrieved from the backend.
- Sign-out functionality.
- Cross-platform application structure through Flutter.

### Backend

- FastAPI REST API.
- SQLAlchemy database integration.
- SQLite database support.
- Password hashing.
- Signed bearer-token authentication.
- Protected API endpoints.
- Child profile retrieval.
- Assessment creation and lifecycle management.
- Activity status persistence.
- Assessment result storage and validation.
- Progress and history retrieval.
- Idempotent creation of required demo profiles.
- Database constraints to prevent duplicate assessment activity records.

### Data integrity

- Assessment activities are persisted rather than held only in frontend memory.
- In-progress assessments can be reopened.
- Assessment completion is restricted until all required activities have been completed.
- Results are associated with completed assessments.
- Screening scores must fall within the supported range of 0 to 1.
- The application does not fabricate model scores when no screening model has produced an output.

---

## 3. Technology Stack

| Component | Technology |
|---|---|
| Frontend | Flutter |
| Frontend language | Dart |
| Backend | FastAPI |
| Backend language | Python |
| API style | REST |
| Database | SQLite |
| ORM | SQLAlchemy |
| Authentication | Signed bearer tokens |
| Password security | Password hashing |
| API server | Uvicorn |
| Testing | Python test framework and Flutter tests |
| Version control | Git |

The project may be extended with a different database, secure token storage, or a separate model-serving service as requirements evolve.

---

## 4. Project Structure

The repository is organized into frontend and backend components. The exact file layout may evolve as development continues.

```text
INTELLISCREEN/
├── frontend/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/
│   │   ├── services/
│   │   ├── screens/
│   │   └── widgets/
│   ├── test/
│   └── pubspec.yaml
│
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── models/
│   │   ├── routes/
│   │   ├── schemas/
│   │   ├── services/
│   │   └── database.py
│   ├── tests/
│   ├── requirements.txt
│   └── intelliscreen.db
│
├── docs/
│
├── IMPLEMENTATION_NOTES.md
└── README.md
```

This is a conceptual layout. Some modules may be organized differently in the current repository. Refer to the actual files when navigating or extending the codebase.

### Frontend responsibilities

The frontend is responsible for:

- Rendering application screens.
- Collecting user input.
- Sending HTTP requests to the backend.
- Managing loading and error states.
- Displaying data returned by the backend.
- Updating the interface after successful API operations.

The frontend should not be treated as the source of truth for persistent child, assessment, activity, or result data.

### Backend responsibilities

The backend is responsible for:

- Authenticating users.
- Authorizing access to protected resources.
- Validating incoming requests.
- Enforcing assessment lifecycle rules.
- Persisting application data.
- Returning consistent API responses.
- Validating screening results before storage.

### Database responsibilities

The database stores application records, including user accounts, child profiles, assessments, activity statuses, and screening results.

Database schema changes must be handled carefully to preserve existing records.

---

## 5. System Architecture

The general request flow is:

```text
┌──────────────────────────┐
│      Flutter App         │
│                          │
│ Login / Dashboard        │
│ Child Profiles           │
│ Assessment Activities    │
│ Progress and History     │
└────────────┬─────────────┘
             │
             │ HTTPS in production
             │ REST API requests
             ▼
┌──────────────────────────┐
│      FastAPI Backend     │
│                          │
│ Authentication           │
│ Authorization             │
│ Request Validation        │
│ Assessment Management     │
│ Activity Tracking         │
│ Result Management         │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│       SQLAlchemy         │
│                          │
│ Database Operations      │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│       SQLite Database    │
│                          │
│ Users                    │
│ Child Profiles           │
│ Assessments              │
│ Activity Statuses        │
│ Screening Results        │
└──────────────────────────┘
```

### Planned model integration

The multimodal model should be integrated as a separate component rather than embedding model-specific logic throughout the Flutter interface.

```text
Flutter Application
        │
        ▼
FastAPI Backend
        │
        ├── Authentication and authorization
        ├── Assessment and activity management
        ├── Input validation
        │
        ▼
Multimodal Integration Service
        │
        ├── Input preparation
        ├── Model invocation
        ├── Output validation
        └── Error and timeout handling
        │
        ▼
Multimodal Screening Model
        │
        ▼
Validated Model Output
        │
        ▼
Backend Result Persistence
```

The final model interface will depend on the selected model, its input requirements, and the agreed output schema.

---

## 6. Prerequisites

Install the following tools before setting up the project:

- Git.
- Flutter SDK and a compatible Dart SDK.
- Python version supported by the backend dependencies.
- A Python virtual environment.
- A package manager such as `pip`.
- A compatible code editor or IDE.
- A supported Flutter target, such as a desktop environment, browser, emulator, or physical device.

Additional platform-specific dependencies may be required by Flutter.

Check the installed versions:

```bash
git --version
flutter --version
dart --version
python --version
```

If your system uses `python3` instead of `python`, use the appropriate command for your environment.

Check Flutter's platform setup:

```bash
flutter doctor
```

Resolve the relevant issues reported by Flutter before running the application on your chosen target.

---

## 7. Installation and Setup

### 7.1 Clone the repository

Clone the repository using the URL for the repository you have permission to access:

```bash
git clone <REPOSITORY_URL>
cd INTELLISCREEN
```

Replace `<REPOSITORY_URL>` with the actual repository address.

If you already have a local copy, navigate to the repository directory instead.

### 7.2 Select the appropriate branch

List available branches:

```bash
git branch -a
```

To work on the integration branch:

```bash
git switch feature/backend-integration
```

If the branch exists only on the remote, fetch the repository first:

```bash
git fetch origin
git switch --track origin/feature/backend-integration
```

Use the actual branch name if it has changed.

### 7.3 Set up the backend environment

Navigate to the backend directory:

```bash
cd backend
```

Create a virtual environment:

```bash
python -m venv .venv
```

Activate it using the command appropriate for your operating system.

**Windows Command Prompt:**

```bat
.venv\Scripts\activate.bat
```

**Windows PowerShell:**

```powershell
.\.venv\Scripts\Activate.ps1
```

**macOS or Linux:**

```bash
source .venv/bin/activate
```

Install the backend dependencies:

```bash
python -m pip install --upgrade pip
pip install -r requirements.txt
```

If the repository uses a different dependency-management file, follow that file's instructions.

### 7.4 Set up the Flutter frontend

Open a separate terminal and navigate to the frontend directory:

```bash
cd frontend
```

Fetch the Flutter dependencies:

```bash
flutter pub get
```

Check the project's static analysis:

```bash
flutter analyze
```

If the repository contains Flutter tests, run them with:

```bash
flutter test
```

---

## 8. Configuration

Configuration values should be supplied through environment variables or a local configuration mechanism appropriate for the deployment environment.

Do not commit secrets, access tokens, passwords, or production credentials.

### 8.1 Backend configuration

The backend may require configuration for:

- Database connection.
- Authentication signing secret.
- Token expiration.
- CORS policy.
- Logging.
- Model service configuration.
- Request and processing timeouts.

Inspect the backend configuration and application startup code to determine which variables are currently supported.

#### Authentication secret

Configure a strong, private signing secret for authentication in deployed environments.

If the application supports an environment variable such as `INTELLISCREEN_TOKEN_SECRET`, set it to a securely generated value before starting the backend.

Do not use a public example secret in production.

If the application generates a local development secret automatically, treat that behavior as development convenience rather than production configuration.

### 8.2 Frontend API configuration

The Flutter app must know the backend API base URL.

If the frontend supports the compile-time setting `INTELLISCREEN_API_URL`, configure it when launching the app.

Example:

```bash
flutter run --dart-define=INTELLISCREEN_API_URL=http://localhost:8000/api/v1
```

Use the base URL expected by the frontend API service. Do not append individual endpoint paths to the configured base URL unless the implementation explicitly requires that.

#### Device-specific networking

The correct API address depends on where the frontend and backend are running.

- When both run in the same environment, `localhost` may work.
- When the frontend runs inside an emulator, `localhost` may refer to the emulator itself rather than the host machine.
- When using a physical device, the backend must be reachable through an appropriate network address.
- When deploying remotely, use the backend's configured public or private service address.

Use HTTPS for production deployments.

---

## 9. Running the Application

### 9.1 Start the backend

From the repository root:

```bash
cd backend
```

Activate the backend virtual environment if it is not already active.

Start the FastAPI application:

```bash
python -m uvicorn app.main:app --reload
```

The `--reload` option is intended for development and automatically restarts the server when relevant code changes are detected.

For production, use a deployment configuration appropriate for the hosting environment.

If the default port is unavailable, configure another port and update the frontend API URL accordingly.

### 9.2 Verify backend availability

Open the backend's health endpoint if one is implemented:

```text
http://localhost:8000/health
```

The API documentation may be available at:

```text
http://localhost:8000/docs
```

These paths depend on the backend configuration. Confirm the actual routes in the FastAPI application.

### 9.3 Start the frontend

In another terminal:

```bash
cd frontend
```

Start the app on a supported target:

```bash
flutter run
```

If multiple devices are available, list them:

```bash
flutter devices
```

Select a specific target when necessary:

```bash
flutter run -d <DEVICE_ID>
```

Replace `<DEVICE_ID>` with an ID reported by Flutter.

### 9.4 Basic application verification

After startup:

1. Open the application.
2. Register a test account or sign in with an existing account.
3. Confirm that the dashboard loads.
4. Open the available child profiles.
5. Start an assessment.
6. Complete an activity and confirm that its status is saved.
7. Leave the assessment and reopen it.
8. Confirm that saved activity progress is restored.
9. Complete all required activities.
10. Verify that the assessment status changes to completed.
11. Sign out and confirm that protected screens require authentication again.

Do not interpret successful activity completion as evidence that a screening model has evaluated the child.

---

## 10. Authentication and Authorization

The application uses backend authentication rather than relying only on frontend state.

### Registration

Registration creates a user account through the backend.

The backend should validate submitted data and store a password hash rather than a plaintext password.

### Login

The frontend sends credentials to the login endpoint.

After successful authentication, the backend returns a signed bearer token.

The frontend includes the token in subsequent protected API requests:

```http
Authorization: Bearer <ACCESS_TOKEN>
```

Never commit or publish real access tokens.

### Protected resources

Protected routes require a valid authentication token.

The backend validates the token before processing protected requests.

Invalid, expired, or missing tokens should not grant access to protected resources.

### Sign-out

Signing out should clear the frontend's active authentication state and token.

If tokens are held only in memory, the user will need to sign in again after the app process restarts. Persistent, secure token storage may be added separately.

### Resource ownership

The implementation documents an ownership model in which assessments, activity statuses, and results are associated with the account that started the assessment.

Shared demo child profiles may be visible to multiple accounts, while account-owned assessment records should not be exposed to unrelated accounts.

Always enforce authorization in the backend. Hiding a screen or button in the frontend is not a security boundary.

---

## 11. Demo Child Profiles

The application includes four demo child profiles for development and testing.

| Participant code | Display name | Age |
|---|---|---:|
| `demo-1` | Leo M. | 7 |
| `demo-2` | Maya S. | 6 |
| `demo-3` | Sam T. | 5 |
| `demo-4` | Zoe K. | 8 |

These are demonstration profiles and must not be treated as real clinical records.

### Profile loading

The frontend retrieves the profiles from the backend.

Participant codes are used to identify the corresponding demo profiles, while the application uses the actual database IDs returned by the backend for API operations.

Do not assume that a participant code is the same as a database primary key.

### Seeding behavior

The backend is designed to create required demo profiles when they are missing.

Seeding should be idempotent: restarting the backend should not create duplicate copies of the demo profiles.

Existing records should not be deleted or overwritten merely to restore demo data.

### Adding new profiles

The current application design intentionally removes the separate Backend Profiles interface and Add Child functionality.

Do not reintroduce child creation or profile-management screens unless that requirement is explicitly approved and implemented across the frontend, backend, authorization rules, and database.

---

## 12. Assessment Workflow

The assessment lifecycle is designed to persist progress and enforce basic workflow rules.

### Assessment states

The documented lifecycle includes:

- `in_progress`
- `completed`
- `cancelled`

The backend is responsible for validating transitions and preserving the authoritative assessment state.

### Typical workflow

1. The authenticated user selects a child.
2. The user starts an assessment.
3. The backend creates or returns the appropriate assessment record.
4. The user completes the required activities.
5. Activity statuses are saved through the API.
6. The user can leave and reopen the assessment.
7. The backend returns the saved activity statuses.
8. The assessment can be completed after all five required activities are done.
9. The completed assessment becomes available in the relevant history or progress views.

The backend is designed to avoid creating duplicate active assessment records when a user resumes an existing in-progress assessment.

### Activity persistence

Activity state should be written to the backend instead of being stored only in the Flutter widget state.

When the user reopens an assessment, the frontend should reconstruct its display from backend data.

### Results versus activity status

Activity completion and screening results are different concepts.

Completing an activity records that the workflow step has been completed. It does not mean that a model has analyzed the input or produced a valid screening result.

Until a screening model has been integrated, validated, and invoked successfully, the application should not fabricate scores, labels, or diagnostic conclusions.

---

## 13. Database and Data Persistence

The backend uses SQLAlchemy to access a SQLite database.

The database may contain records for:

- Users.
- Child profiles.
- Assessments.
- Activity statuses.
- Screening results.

The actual table and column names should be confirmed from the current SQLAlchemy models and database schema.

### Database safety

**Always back up the database before schema changes, migrations, or destructive development operations.**

A database file may contain valuable user or assessment data even if it is part of a local development environment.

Do not delete the database simply because the application fails to start.

### Schema changes

When modifying models or database structure:

1. Inspect the current schema.
2. Back up existing data.
3. Use an appropriate migration strategy.
4. Preserve existing records and identifiers.
5. Test the migration against a copy of the database.
6. Verify the application against the migrated database.
7. Document any migration that must be run during deployment.

Automatic table creation or startup-time schema updates may be sufficient for simple development environments, but they are not a substitute for a deliberate migration strategy in a production application.

### Result validation

The backend validates stored result scores within the range 0 to 1.

The precise meaning of each score, its calibration, the interpretation of thresholds, and any risk classification must be defined by the model and the project's validated assessment methodology.

A numeric score alone is not a diagnosis.

---

## 14. API Overview

The backend exposes REST endpoints for authentication, child profiles, assessments, activity statuses, results, and progress.

The following table describes the documented API capabilities. Confirm exact HTTP methods, payload schemas, and route paths in the current FastAPI code or interactive API documentation.

| API area | Purpose | Authentication |
|---|---|---|
| Health | Check backend availability | Public, if configured that way |
| Registration | Create an account | Public |
| Login | Authenticate an account | Public |
| Current user | Retrieve the authenticated user | Protected |
| Children | Retrieve available child profiles | Protected |
| Assessments | Create and retrieve assessment sessions | Protected |
| Assessment lifecycle | Complete or cancel assessments | Protected |
| Activity statuses | Save and retrieve activity progress | Protected |
| Results | Store and retrieve valid assessment results | Protected |
| Progress | Retrieve progress and assessment history | Protected |

### API documentation

During development, FastAPI may expose interactive documentation at:

```text
http://localhost:8000/docs
```

Use it to inspect the actual routes, schemas, authentication requirements, and available responses.

### API design expectations

New endpoints should:

- Validate request bodies.
- Return consistent HTTP status codes.
- Enforce authentication and resource ownership.
- Avoid leaking internal exception details.
- Handle missing resources appropriately.
- Avoid duplicate records where uniqueness is required.
- Return structured error responses.
- Be covered by automated tests.

The frontend should handle API failures explicitly rather than assuming that every request succeeds.

---

## 15. Testing

Run the backend and frontend test suites after changing application behavior.

### Backend tests

From the backend directory, activate the virtual environment and run:

```bash
pytest
```

If the test suite is configured to require a particular settings file or environment, use the configuration documented in the repository.

Backend tests should cover:

- Registration and login.
- Password hashing.
- Token validation.
- Protected endpoint access.
- Child profile retrieval.
- Assessment creation and lifecycle transitions.
- Activity persistence.
- Assessment resumption.
- Prevention of duplicate records.
- Resource ownership and authorization.
- Result validation.
- Database behavior.

### Frontend static analysis

From the frontend directory:

```bash
flutter analyze
```

### Frontend tests

Run:

```bash
flutter test
```

Frontend tests should cover:

- Authentication screens.
- API request behavior.
- Loading and error states.
- Child profile rendering.
- Assessment activity updates.
- Resuming saved progress.
- Sign-out behavior.
- Result and history display.

Where appropriate, mock API responses rather than depending on a live backend for every unit or widget test.

### Integration tests

An end-to-end integration test should verify the full flow between the frontend, backend, and database.

At minimum, verify that:

1. A user can authenticate.
2. The child list loads from the backend.
3. An assessment can be started.
4. An activity status can be saved.
5. Saved progress can be retrieved.
6. Assessment completion rules are enforced.
7. Results cannot be fabricated or saved in an invalid state.
8. Unauthorized users cannot access another account's protected assessment data.

Use a disposable test database for automated integration tests.

**Do not run destructive tests against the database containing real or important development records.**

### Test reporting

When reporting test results, distinguish between:

- Tests that were actually executed.
- Tests that passed.
- Tests that failed.
- Tests that were skipped.
- Functionality that has not yet been tested.

Do not describe the model integration as tested until the actual model has been integrated and tested.

---

## 16. Multimodal Model Integration

The multimodal screening model is the next major development component.

The existing application provides the surrounding infrastructure for authentication, assessment sessions, activity persistence, and result storage. The model integration must connect that infrastructure to the actual screening implementation.

### Integration objective

The goal is to accept the appropriate assessment inputs, pass them through a defined model interface, validate the model's output, and store the result against the correct assessment.

The exact input modalities depend on the selected model and assessment design. They might include text, audio, image data, interaction measurements, or other supported features.

Do not assume that every modality is required or currently implemented.

### Recommended separation of responsibilities

Keep the following responsibilities separate:

**Flutter frontend**
- Collects permitted assessment inputs.
- Provides the relevant user interface.
- Sends input or references to the backend.
- Displays validated status and result information.

**FastAPI backend**
- Authenticates the user.
- Authorizes access to the assessment.
- Validates the input.
- Orchestrates model invocation.
- Handles errors and timeouts.
- Validates the model output.
- Persists valid results.

**Model adapter**
- Defines a stable interface to the model.
- Prepares model-specific inputs.
- Calls the selected model or inference service.
- Converts model-specific outputs into the agreed application schema.
- Reports failures without inventing successful results.

**Screening model**
- Performs the actual inference.
- Returns outputs according to its documented contract.
- Must be evaluated and validated for the intended use.

### Recommended integration process

1. **Inspect the existing backend.**  
   Identify assessment models, result schemas, API routes, database relationships, and current validation rules.

2. **Define the model contract.**  
   Specify accepted inputs, required fields, output structure, score interpretation, and error behavior before connecting the model.

3. **Create a model adapter.**  
   Keep model-specific dependencies and transformations isolated from the rest of the application.

4. **Connect the adapter to the backend.**  
   The backend should invoke the adapter only when the required assessment inputs are available and valid.

5. **Validate the output.**  
   Check required fields, value ranges, model version, assessment association, and any relevant confidence or quality indicators.

6. **Persist results only after successful inference.**  
   A failed request, missing input, or incomplete activity must not produce a fabricated result.

7. **Update the frontend.**  
   Display a result only when the backend confirms that a valid result exists.

8. **Add automated tests.**  
   Use a mock model for routine tests and a separate integration test for the real model.

9. **Document the model.**  
   Record the model version, expected inputs, output interpretation, dependencies, known limitations, and deployment requirements.

10. **Validate the screening methodology.**  
    Confirm that model outputs are appropriate for the intended screening purpose before using them with children.

### Example adapter contract

The following is an illustrative Python interface, not a claim that the current repository already contains this exact implementation.

```python
from typing import Any, Protocol


class ScreeningModelAdapter(Protocol):
    def predict(
        self,
        assessment_input: dict[str, Any],
    ) -> dict[str, Any]:
        """
        Run screening inference and return a documented,
        validated output structure.

        Raise an appropriate exception if inference fails.
        Do not return fabricated scores or diagnoses.
        """
        ...
```

The actual method may need to be asynchronous if inference is performed through a remote service or a long-running task.

### Example result structure

A possible output contract could look like this:

```json
{
  "assessment_id": 123,
  "model_name": "example-model",
  "model_version": "1.0.0",
  "status": "completed",
  "score": 0.72,
  "interpretation": null
}
```

This is an example only. It is not a real screening result, and the values are not validated clinical thresholds.

Before implementing the schema, agree on whether the model returns a single score, multiple modality-specific scores, quality indicators, confidence estimates, or another structure.

Do not assign diagnostic meaning to example scores.

### Model integration safeguards

- Never substitute random or hardcoded values for model output.
- Do not create a result when inference fails.
- Do not expose sensitive input data in application logs.
- Restrict access to assessment inputs and results.
- Record the model version associated with each result.
- Define behavior for missing or low-quality input.
- Handle timeouts and unavailable model services.
- Avoid blocking the frontend while long-running inference is in progress.
- Ensure that the result belongs to the correct assessment and authorized account.
- Evaluate model performance and limitations before real-world use.

### Definition of done

Model integration should not be considered complete until:

- The real model or inference service is connected.
- The input and output contracts are documented.
- Invalid inputs are rejected safely.
- Inference failures are handled correctly.
- Results are persisted only after successful inference.
- The frontend retrieves and displays the persisted output.
- Tests cover success, failure, and invalid-output cases.
- Model versioning and result interpretation are documented.
- The screening methodology has undergone appropriate evaluation.

---

## 17. Security and Privacy

INTELLISCREEN may handle sensitive information relating to children. Security and privacy must therefore be considered throughout development.

### Credentials

- Store password hashes, not plaintext passwords.
- Never commit secrets or access tokens.
- Use a strong signing secret in deployed environments.
- Protect configuration files containing credentials.
- Rotate credentials if they are exposed.

### API security

- Require authentication for protected endpoints.
- Enforce resource ownership in the backend.
- Validate user input.
- Use HTTPS for deployed services.
- Configure CORS for the intended clients.
- Apply appropriate rate limits and request-size limits.
- Avoid returning internal exception details to clients.

### Sensitive assessment data

- Collect only data required for the approved screening purpose.
- Avoid logging raw assessment inputs unless there is a documented and secure need.
- Restrict access to uploaded files and stored results.
- Define retention and deletion policies.
- Protect database backups.
- Obtain appropriate consent and permissions before collecting children's data.
- Follow the privacy and legal requirements applicable to the deployment location.

### Development database

The SQLite database is suitable for local development and some limited deployments. It should not be assumed to be sufficient for every production workload or multi-user deployment.

Production architecture should be reviewed for backup, access control, concurrent access, monitoring, and recovery requirements.

### Screening limitations

The application must clearly distinguish between a screening indication and a clinical diagnosis.

Any result interpretation should be grounded in a validated assessment methodology and reviewed by qualified professionals where appropriate.

---

## 18. Known Limitations

The following limitations were documented during the current integration stage.

### 1. Multimodal model not connected

The application infrastructure is in place, but the actual screening model still needs to be integrated.

Model-based screening results should not be represented as available until that work is complete.

### 2. Token persistence

Authentication tokens may be held in memory. If so, users must sign in again after restarting the application.

Secure persistent token storage should be implemented using an appropriate platform-supported solution before production deployment.

### 3. Platform coverage

Successful testing on one platform does not guarantee that every Flutter target works correctly.

Test the platforms intended for release, including platform-specific networking and secure storage.

### 4. Demo profile data

Demo profile presentation information is intended for development and testing. It must not be mistaken for verified information about real children.

### 5. Database migrations

Existing databases may require schema updates as backend models change.

Back up the database and verify schema migrations against a copy before applying changes to valuable data.

### 6. Production readiness

The project should undergo additional security, privacy, deployment, accessibility, and screening-methodology review before being used with real children.

---

## 19. Git Workflow

Use feature branches to keep application integration and model development separate.

### Check the current branch and working tree

```bash
git status
git branch --show-current
git log -1 --oneline
```

### Fetch the latest changes

```bash
git fetch origin
```

### Create a feature branch

```bash
git switch -c feature/<short-description>
```

Replace `<short-description>` with a meaningful name, such as `multimodal-adapter`.

### Review changes

```bash
git diff
git diff --staged
git status
```

Before committing, inspect the changes and ensure they do not contain secrets, database contents, local environments, or generated build artifacts.

### Commit changes

```bash
git add <files-to-include>
git commit -m "Describe the change"
```

Avoid blindly staging every file when local databases, credentials, or generated artifacts may be present.

### Push a branch

```bash
git push -u origin <branch-name>
```

The remote repository must be correct, and the user must have permission to push to it.

### Pull request guidance

For model integration:

1. Start from the agreed integration branch.
2. Create a separate feature branch.
3. Keep model dependencies isolated.
4. Add or update tests.
5. Update documentation.
6. Review security and privacy implications.
7. Open a pull request.
8. Merge only after the required checks pass.

### Files that should not be committed

Examples of files that generally should not be committed include:

- Python virtual environments.
- Authentication secrets.
- Access tokens.
- Local environment files containing secrets.
- Generated application builds.
- Cache directories.
- Temporary test output.
- Local database files containing private or changing data, unless the repository explicitly requires a controlled, sanitized fixture.

Check `.gitignore` and review the Git index to ensure sensitive files are excluded.

---

## 20. Troubleshooting

### Backend fails to start

Check that:

- The correct Python environment is active.
- Required dependencies are installed.
- The working directory is correct.
- The application module path matches the actual project structure.
- The configured port is available.
- Database access succeeds.
- Required environment variables are configured.

Review the server error message before changing database files or reinstalling dependencies.

### Frontend cannot reach the backend

Check that:

- The backend is running.
- The configured API base URL is correct.
- The frontend is using the expected API prefix.
- The backend is reachable from the frontend's runtime environment.
- Emulator or device networking is configured correctly.
- CORS is configured if the client runs in a browser.
- HTTP and HTTPS settings are compatible.

Remember that `localhost` may refer to the frontend device rather than the computer hosting the backend.

### Login fails

Check that:

- The backend is running.
- Registration or account creation completed successfully.
- The credentials are correct.
- The frontend is calling the correct login endpoint.
- The backend returns the expected token response.
- Protected requests include the bearer token.
- The signing secret and token-validation configuration are consistent.

Do not bypass authentication checks to make the interface appear functional.

### Child profiles do not load

Check that:

- The user is authenticated.
- The child endpoint is available.
- The backend database contains the expected demo profiles.
- Participant codes map to the expected database records.
- The frontend uses actual backend IDs for subsequent requests.
- The API response matches the frontend model's expected schema.

Do not delete the database as the first troubleshooting step.

### Assessment progress does not persist

Check that:

- Activity updates are sent to the backend.
- The API request succeeds.
- The correct assessment ID is used.
- The authenticated account owns the assessment.
- The backend stores and returns the updated activity status.
- The frontend refreshes or reconstructs state from the API response.

### Assessment cannot be completed

Check that all five required activities have been marked complete by the backend.

The frontend should not bypass backend lifecycle validation.

### No screening result is available

This is expected until a real screening model has been integrated and invoked successfully.

Do not add hardcoded scores or fake result records as a workaround.

### Flutter analysis or tests fail

Run:

```bash
flutter pub get
flutter analyze
flutter test
```

Review the first meaningful error in the output and address the underlying issue rather than suppressing the warning without understanding it.

### Backend tests fail

Run:

```bash
pytest
```

Check the traceback, test configuration, database fixture setup, and required environment variables.

Ensure automated tests use a test database rather than the development database containing valuable records.

---

## 21. Future Development

The next development milestones are:

### Milestone 1: Stabilize application integration

- Keep frontend and backend API contracts aligned.
- Verify authentication and authorization.
- Confirm persistence and assessment lifecycle behavior.
- Maintain automated test coverage.
- Document setup and configuration.

### Milestone 2: Integrate the multimodal model

- Agree on the model contract.
- Implement the adapter.
- Connect inference to the backend.
- Validate and persist real model outputs.
- Add failure handling and integration tests.

### Milestone 3: Improve deployment security

- Add secure persistent token storage.
- Configure HTTPS.
- Review secrets management.
- Establish database backup and migration procedures.
- Review access controls and logging.

### Milestone 4: Validate the screening workflow

- Define the meaning of model outputs.
- Establish appropriate assessment protocols.
- Evaluate performance and limitations.
- Review how uncertainty is communicated.
- Ensure the application does not present screening outputs as a definitive diagnosis.

### Milestone 5: Prepare for release

- Test all intended platforms.
- Review accessibility and usability.
- Conduct privacy and security assessments.
- Document deployment and recovery procedures.
- Establish support and maintenance practices.

---

## 22. Contributing

Contributions should be focused, tested, and documented.

Before submitting changes:

1. Read the existing implementation notes.
2. Understand the frontend/backend boundary.
3. Confirm whether the change affects the API contract or database schema.
4. Avoid unrelated refactoring.
5. Add or update automated tests.
6. Run the relevant test suites.
7. Update this README when setup or behavior changes.
8. Review the Git diff for secrets and unrelated files.
9. Submit the changes through the project's agreed review process.

Changes involving authentication, database migrations, assessment lifecycle rules, or screening result interpretation require particular care.

---

## Final Note

INTELLISCREEN provides the foundation for a cross-platform screening workflow with backend-managed authentication, child profiles, assessment sessions, activity persistence, and result storage.

The immediate priority for continued development is to preserve this working foundation while integrating the actual multimodal screening model through a clearly defined, testable interface.

**The application must only store and display screening results produced by a real, successfully executed, and appropriately validated model.** Screening outputs should support informed follow-up and must not be presented as a standalone diagnosis of dyslexia.