# TalentBridge — Flutter App

Mobile + web client for the TalentBridge recruitment platform. One codebase
targets iOS, Android, and web via `flutter build web` / `flutter run -d chrome`.

This is a scaffold, not a finished app — it covers the shared infrastructure
(networking, auth, routing) and one full feature (Jobs) end to end as a
pattern to copy for the rest.

## Setup

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api
```

Set `API_BASE_URL` per environment (local/staging/prod) via `--dart-define`,
or bake environment-specific defaults into a build script.

## Structure

```
lib/
├── main.dart              # entrypoint, wraps app in ProviderScope
├── app.dart                # MaterialApp.router + theme + router wiring
├── core/
│   ├── network/
│   │   ├── dio_client.dart     # bearer token attach + 401 refresh interceptor
│   │   └── api_exception.dart  # normalizes backend error responses
│   ├── storage/
│   │   └── secure_storage_service.dart  # Keychain/Keystore token storage
│   ├── router/
│   │   └── app_router.dart     # go_router + auth redirect guard
│   └── theme/
│       └── app_theme.dart
└── features/
    ├── auth/
    │   ├── data/
    │   │   ├── models/user_model.dart
    │   │   └── auth_repository.dart
    │   ├── application/auth_provider.dart   # also hosts shared dio/storage providers
    │   └── presentation/screens/login_screen.dart
    └── jobs/
        ├── data/
        │   ├── models/job_model.dart
        │   └── jobs_repository.dart
        ├── application/jobs_provider.dart
        └── presentation/screens/job_list_screen.dart
```

## Adding a new feature

Follow the `jobs/` folder as the template. For each new feature
(candidate profile, applications, competency tests, assessments, reports):

1. **`data/models/*.dart`** — plain Dart class with `fromJson`, mirroring the
   backend's Zod/Mongoose shape field-for-field (see the model files in the
   backend repo — `CandidateProfile`, `Assessment`, `CompetencyTest`, etc.)
2. **`data/*_repository.dart`** — wraps `Dio` calls to the matching backend
   routes, throws `ApiException` on failure
3. **`application/*_provider.dart`** — a `StateNotifier` + `Provider` pair
   holding loading/data/error state for that feature's screens
4. **`presentation/screens/*.dart`** — `ConsumerWidget`/`ConsumerStatefulWidget`
   reading from the provider

Then register the screen's route in `core/router/app_router.dart`.

## Known gaps to fill in before this runs against your real backend

- `dio_client.dart` and `auth_repository.dart` have `TODO`s marked where the
  exact request/response field names need to match your actual `/auth/login`
  and `/auth/refresh` endpoints
- No candidate-profile CV upload screen yet (needs `file_picker` +
  `dio`'s `MultipartFile`, mirroring the backend's `multipart/form-data` CV
  upload endpoint)
- No role-based redirect for a recruiter who hasn't created a company yet
  (`UserModel.needsCompanySetup` is there to build that check on)
- No web-specific CORS handling — confirm your Express backend's CORS config
  allows the Flutter web app's origin
