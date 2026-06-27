# Ecoursale App — Setup Guide (for absolute beginners)

This is the **white-label student app** (Flutter). It talks to your existing
ProjectBigBang backend at `/api/v1/...`. This guide assumes you have **never used
Flutter or built an Android app**. Follow it top to bottom.

> **What I (Claude) already created:** all the app's Dart source code (`lib/`), the
> `pubspec.yaml` (dependency list), and config files.
> **What YOU must do once:** install the tools, then run a single command that
> generates the Android/iOS project folders around this code, then run the app.
> (Those platform folders are produced by the `flutter` tool — they can't be
> hand-written, which is why this step is yours.)

---

## PART 1 — Install the tools (one time, ~30–45 min)

### 1.1 Install Flutter SDK
1. Go to <https://docs.flutter.dev/get-started/install/windows> (you're on Windows).
2. Download the **Flutter SDK zip**.
3. Extract it to a simple path, e.g. `C:\src\flutter` (avoid spaces/`Program Files`).
4. Add `C:\src\flutter\bin` to your **PATH**:
   - Start → search "environment variables" → *Edit the system environment variables*
     → *Environment Variables* → under *User variables* select **Path** → *Edit* →
     *New* → paste `C:\src\flutter\bin` → OK everything.
5. Open a **new** terminal (PowerShell) and run:
   ```
   flutter --version
   ```
   You should see version info. If "not recognized", the PATH step didn't take —
   reopen the terminal or recheck step 4.

### 1.2 Install Android Studio (gives you the Android SDK + an emulator)
1. Download from <https://developer.android.com/studio> and install (accept defaults).
2. Open Android Studio once → it downloads the **Android SDK** automatically.
3. In Android Studio: *More Actions* → *SDK Manager* → **SDK Tools** tab → make sure
   **Android SDK Command-line Tools** is checked → Apply.

### 1.3 Accept Android licenses
In your terminal:
```
flutter doctor --android-licenses
```
Press `y` to accept each.

### 1.4 Verify everything
```
flutter doctor
```
You want green checks for **Flutter** and **Android toolchain**. Ignore the
"Visual Studio" (Windows desktop) and "Chrome" lines — we only need Android.
If anything Android-related is red, `flutter doctor` prints the exact fix.

---

## PART 2 — Prepare a device to run on
Pick ONE:

**Option A — Android emulator (no physical phone needed):**
1. Android Studio → *More Actions* → *Virtual Device Manager* → *Create Device*.
2. Pick e.g. **Pixel 7**, a system image (e.g. latest "Tiramisu/UpsideDownCake"),
   Finish, then press ▶ to boot it.

**Option B — Your real Android phone:**
1. On the phone: Settings → About phone → tap *Build number* 7 times to unlock
   *Developer options*.
2. Settings → Developer options → enable **USB debugging**.
3. Plug the phone into the PC via USB, tap *Allow* on the phone.

Verify the device is seen:
```
flutter devices
```

---

## PART 3 — Set up THIS app

Open a terminal **in this folder** (`e:\MindSpan Program\ecoursale_app`).

### 3.1 Generate the Android/iOS project folders
This wraps the existing `lib/` code with the native project scaffolding. It will
NOT overwrite my source files.
```
flutter create . --org com.ecoursale --project-name ecoursale_app --platforms=android,ios
```
> `--org com.ecoursale` sets the package id base to `com.ecoursale.ecoursale_app`.
> (For real white-label builds each school gets its own id — that's Phase E.)

### 3.2 Create your `.env`
Copy the example and confirm the backend URL:
```
copy .env.example .env
```
Open `.env` and make sure `API_BASE` points at a backend you can reach over HTTPS,
e.g. your dev box:
```
API_BASE=https://dev-mse.ecoursale.com
```

### 3.3 Get the dependencies
```
flutter pub get
```

### 3.4 Run the app
With your emulator booted (or phone plugged in):
```
flutter run
```
The app compiles and launches. **Log in with a real STUDENT account** of the school
(the same email/password they use on the website). You should see the school's
branding (colour + name from the backend), then Courses / Tests / Alerts / Profile.

> While `flutter run` is active: press `r` = hot reload, `R` = hot restart, `q` = quit.

---

## PART 4 — Build an installable APK (to share/test on a phone)
```
flutter build apk --release
```
The file appears at:
```
build\app\outputs\flutter-apk\app-release.apk
```
Copy it to an Android phone and tap to install (allow "install from unknown
sources" if prompted). This is a **plain APK for testing** — Play Store publishing
is Phase E (separate, later).

---

## Troubleshooting
- **`flutter` not recognized** → PATH (step 1.1.4); reopen terminal.
- **No devices** → boot the emulator or plug in the phone with USB debugging on.
- **Login fails / network error** → `API_BASE` must be reachable from the device
  over **HTTPS**. An emulator can't reach `localhost` of your PC as `localhost` —
  use the dev box URL (`https://dev-mse.ecoursale.com`).
- **Gradle/Android build errors first time** → usually a missing SDK piece;
  `flutter doctor` tells you what. First build is slow (downloads Gradle) — let it.

---

## What's where (for the curious)
```
lib/main.dart                      app entry (loads .env, applies server theme)
lib/src/core/                      config, api client (JWT+refresh), tokens, router, providers
lib/src/data/models/               data shapes matching /api/v1 responses
lib/src/data/repositories/         auth + content API calls
lib/src/theme/                     server-driven theme builder
lib/src/features/                  screens: auth, home, courses, tests, notifications, profile
.env                               API_BASE + school code (you create this)
```

## Notes on design (why it's built this way)
- **Server-driven**: the app's colours/branding/feature flags come from
  `GET /api/v1/school/config/`. Change the school in the backend DB → the app
  re-themes with **no rebuild**. (Maximum automation, per the plan.)
- **Identity-first tenant**: the app never sends a school id. The backend resolves
  the school from the logged-in user, so one app codebase serves any school safely.
- **iOS-ready, not iOS-built**: `flutter create` above includes the `ios` platform
  so adding iOS later is a config step, not a rewrite. We don't build/publish iOS now.
- **Payments stay on web**: the app links out to the web checkout (avoids Play/Apple
  in-app-purchase fees), by design.
