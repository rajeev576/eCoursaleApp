# Ecoursale App (Flutter)

White-label **student** app for Ecoursale schools. Front-end only — it talks to the
ProjectBigBang Django backend at `/api/v1/...`. Admins manage everything on the web;
students use this app.

**New here? Read [`SETUP.md`](SETUP.md)** — step-by-step from zero (install Flutter,
generate the Android project, run, build an APK).

## At a glance
- **Stack:** Flutter (Dart), Riverpod, Dio, go_router, flutter_secure_storage.
- **Auth:** JWT (access + refresh) with automatic silent refresh.
- **Tenant:** identity-first — resolved server-side from the logged-in user.
- **Theming:** server-driven from `GET /api/v1/school/config/` (no rebuild to re-brand).
- **Platforms:** Android now; iOS-ready (kept buildable, not published yet).
- **Phase:** D of the white-label initiative — see
  `../ProjectBigBang/docs/custom_app_STATUS.md`.

## Quick start (after tools installed — see SETUP.md)
```
flutter create . --org com.ecoursale --project-name ecoursale_app --platforms=android,ios
copy .env.example .env      # then set API_BASE
flutter pub get
flutter run
```
