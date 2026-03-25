# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # Install dependencies
flutter analyze          # Lint (uses analysis_options.yaml)
flutter test             # Run all tests
flutter test test/unit/services/goal_task_test.dart  # Run single test file
flutter run              # Run on connected device/emulator
flutter build apk        # Build Android
flutter build ipa        # Build iOS
```

Code generation (when modifying mock-dependent files):
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Architecture

**Layers:**
- `lib/core/` — Business logic: 20+ services (TriggerEngine, NotificationService, MotivationalEngine, NLUParser, PrivacyGptService, GamificationService, etc.)
- `lib/data/` — Data layer: Firestore repositories + local models. Repository interfaces in `data/repositories/` abstract Firestore.
- `lib/presentation/` — UI: screens, providers (state), widgets, navigation, theme tokens

**State management:** `provider` package with `ChangeNotifier`. Key providers: `GrowthProvider` (goals/tasks/gamification), `ReminderProvider` (reminders/context events), `AuthProvider`, `ThemeProvider`. All wired in `lib/main.dart`.

**Data persistence:** Firestore is the primary store. All models implement `fromFirestore`/`toMap` for serialization. `SharedPreferences` for local settings. `Workmanager` runs background tasks every 15 minutes for context monitoring.

**Context-aware triggers:** `TriggerEngine` (initialized at app start) evaluates reminders against time, activity, WiFi, and location signals. `ActivityRecognitionService` provides stubbed activity detection (geolocator was removed; location features are being refactored).

**AI integration:** `PrivacyGptService` makes anonymized OpenAI API calls (premium feature). `NLUParser` handles local natural-language parsing. `ChatController` drives the chat screen.

## Key Patterns

- Models use named constructors: `Goal.fromFirestore(doc)` and `.toMap()`
- `GoalTask` has recursive subtasks — handle null-safety carefully when traversing
- Screens consume providers via `context.watch<Provider>()` / `context.read<Provider>()`
- Navigation uses `MainNavigator` with named routes; bottom nav index drives the active screen
- Theming uses Lumio design tokens in `lib/presentation/theme/` (colors, typography, spacing)

## Linting Rules

Single quotes, trailing commas, `const` constructors, `always_declare_return_types`, `sort_child_properties_last`. Generated files (`*.g.dart`, `*.freezed.dart`) are excluded from analysis.

## Environment

Requires a `.env` file (see `.env.example`) with `OPENAI_API_KEY` and `GOOGLE_MAPS_API_KEY`. Firebase config is in `lib/firebase_options.dart` (auto-generated — do not edit manually).

## CI/CD

Codemagic (`codemagic.yaml`) builds and publishes on `main` and `updated-homescreen` branches. The current development branch is `updated-homescreen`.
