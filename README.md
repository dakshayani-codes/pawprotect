# 🐾 PawProtect

> **A gamified digital wellbeing Android app where your virtual pet's mood reflects your screen time habits.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%2B%20Firestore-FFCA28?logo=firebase)](https://firebase.google.com)
[![SQLite](https://img.shields.io/badge/SQLite-Offline--First-003B57?logo=sqlite)](https://www.sqlite.org)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://android.com)

---

## 📱 What Is This?

Most screen time apps show you numbers. You look at them. Then you keep scrolling.

PawProtect adds **consequence** — a virtual pet whose emotional state is directly tied to your daily phone usage. Stay under your limit → pet is happy. Overuse your phone → pet gets angry.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🐱 **Animated Virtual Pet** | 4 mood states (Happy / Neutral / Sad / Angry) driven by usage thresholds |
| 📊 **Behavioral Analytics** | 4-tab dashboard: Usage, Apps, Heatmap, Leaderboard |
| 🤖 **AI Insight Engine** | On-device analysis — addiction score, trend detection, linear regression prediction |
| 🔥 **Streak System** | Consecutive days under limit tracked with Firebase leaderboard |
| 🔐 **Firebase Auth** | Email/password + Google Sign-In + Forgot Password |
| 💾 **Offline-First Sync** | SQLite → sync_queue → Firebase Firestore (works without internet) |
| 🌙 **Time-of-Day Heatmap** | Morning / Afternoon / Evening / Night usage breakdown |
| 📈 **Improvement Tracking** | Week-over-week comparison with trend arrows |

---

## 🧠 AI Analytics Engine

The `AiInsightEngine` runs entirely **on-device** — no API calls, no cost, no latency.

**Addiction Score Formula:**
```
Score = (weekend_usage × 1.3) + (night_usage × 1.5) + (streak_breaks × 2)
Normalized to 0–100

Level:  0–19 = Low  |  20–44 = Medium  |  45–69 = High  |  70–100 = Critical
```

**Additional analyses:**
- Today vs personal average comparison
- Week-over-week trend detection (7-day vs previous 7-day)
- Weekend spike detection (weekend avg > weekday avg × 1.4)
- Linear regression prediction for tomorrow's usage
- Consistency score across active days

---

## 🏗️ Architecture

```
Flutter UI Layer
    │  context.watch() / read()
    ▼
ViewModel Layer (Provider + ChangeNotifier)
    │  AuthViewModel  │  PetViewModel
    ▼                 ▼
Data Layer          Service Layer
  DatabaseHelper      AiInsightEngine
  FirebaseService     (stateless, on-device)
    │
    ▼
Persistence Layer
  SQLite (offline)  →  Firebase Firestore (cloud)
  usage_logs            users/{uid}/daily_reports
  sync_queue            users/{uid} (streak, leaderboard)
```

**Pattern:** MVVM with Provider
**Sync Strategy:** Offline-first — SQLite is source of truth, Firestore receives daily summaries via sync queue

---

## Screens

| Screen | Description |
|---|---|
| **Auth** | Sign in / Sign up / Google / Forgot password / Guest mode |
| **Home** | Pet + usage card + streak + app launchers + AI insight cards |
| **Analytics** | 4 tabs: bar chart, pie chart, heatmap, leaderboard |
| **Settings** | Daily limit slider, account card, demo data loader |

---

## How Tracking Works (No Special Permissions)

Android's `PACKAGE_USAGE_STATS` permission requires manual system-settings navigation. PawProtect avoids it entirely using a **monitored launcher approach**:

1. User taps an app button (Instagram, YouTube, Twitter)
2. App records `startTime` and launches the external app via `url_launcher`
3. Flutter's `AppLifecycleState.paused` fires when user enters the other app
4. `AppLifecycleState.resumed` fires when user returns to PawProtect
5. Duration is calculated → saved to SQLite → pet mood updates

> Sessions under 1 minute are discarded to prevent noise data.

---

## Database Schema

**Local SQLite (2 tables):**

```sql
-- Every individual app session
CREATE TABLE usage_logs (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  date      TEXT NOT NULL,
  app_name  TEXT NOT NULL,
  minutes   INTEGER NOT NULL,
  timestamp TEXT NOT NULL   -- ISO8601, used for night-usage detection
);

-- Offline-first sync buffer
CREATE TABLE sync_queue (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  date            TEXT NOT NULL UNIQUE,
  total_usage     INTEGER NOT NULL DEFAULT 0,
  mood            TEXT NOT NULL DEFAULT 'happy',
  streak          INTEGER NOT NULL DEFAULT 0,
  addiction_score REAL NOT NULL DEFAULT 0,
  synced          INTEGER NOT NULL DEFAULT 0  -- 0=pending, 1=uploaded
);
```

**Firebase Firestore:**
```
users/{userId}/daily_reports/{date}
  total_minutes, streak, mood, addiction_score, app_breakdown, synced_at
```

---

## Getting Started

### Prerequisites
- Flutter SDK 3.x
- Android Studio / VS Code
- Firebase project (free tier works)

### Setup

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/pawprotect.git
cd pawprotect

# 2. Install dependencies
flutter pub get

# 3. Firebase setup (if not already done)
npm install -g firebase-tools
dart pub global activate flutterfire_cli
flutterfire configure
# Select your Firebase project → generates firebase_options.dart automatically

# 4. Enable in Firebase Console:
#    Authentication → Email/Password → Enable
#    Authentication → Google → Enable (add SHA-1 fingerprint)
#    Firestore Database → Create database → Start in test mode

# 5. Run on physical device (recommended over emulator)
flutter devices
flutter run
```

### Building Release APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## Tech Stack

| Package | Version | Purpose |
|---|---|---|
| `flutter` | 3.x | UI framework |
| `provider` | ^6.1.1 | State management (MVVM) |
| `sqflite` | ^2.3.0 | Local SQLite database |
| `path_provider` | ^2.1.2 | Database path resolution |
| `firebase_core` | ^3.3.0 | Firebase initialization |
| `firebase_auth` | ^5.1.4 | Authentication |
| `cloud_firestore` | ^5.3.0 | Cloud database |
| `google_sign_in` | ^6.2.1 | Google Sign-In |
| `url_launcher` | ^6.2.5 | Opening monitored apps |
| `fl_chart` | ^0.66.2 | Analytics charts |
| `google_fonts` | ^6.2.1 | Typography |

---

## Project Structure

```
lib/
├── main.dart
├── firebase_options.dart
├── data/
│   ├── local/database_helper.dart     # SQLite CRUD + sync queue
│   └── remote/firebase_service.dart   # Firebase Auth + Firestore
├── models/
│   └── models.dart                    # UsageSession, AiInsight, AnalyticsData
├── services/
│   └── ai_insight_engine.dart         # On-device behavioral analytics
├── viewmodels/
│   ├── pet_viewmodel.dart             # Core app state + mood + sync
│   └── auth_viewmodel.dart            # Auth state management
└── views/
    ├── home/
    │   ├── home_screen.dart
    │   └── animated_pet.dart
    ├── analytics/analytics_screen.dart
    ├── auth/auth_screen.dart
    └── settings/settings_screen.dart
```

---

## Known Limitations

- Only apps launched **through PawProtect** are tracked (by design — avoids system permissions)
- Android only (iOS deep-link schemes not tested)
- Google Sign-In requires SHA-1 fingerprint configured in Firebase Console
- AI prediction needs minimum 5 days of data for meaningful results

---

## Future Work

- Background tracking with `PACKAGE_USAGE_STATS` permission + user consent flow
- TensorFlow Lite model for personalized usage prediction
- Local push notifications when approaching daily limit
- Android home screen widget showing pet mood
- iOS support

---

