# Money Tracker App (Personal & Group Expense Manager)

A modern, offline-first personal and group financial management mobile application built with **Flutter** and **Firebase**, featuring precision double-entry accounting, multi-wallet management, group bill splitting, location-tagged transactions, AI financial assistance, and reliable cloud synchronization.

---

## Key Features

### 1. Income/Expense & Multi-Wallet Management
- **Multiple Wallet Types**: Manage Cash, Bank Accounts, E-wallets (MoMo, ZaloPay, etc.), Credit Cards, and Savings with customizable palettes and default wallet support.
- **Fast Transaction Logging**: Record amount, category, date & time, receipt photos (with instant thumbnail preview, full-screen zoom, and offline-first background upload), notes, and interactive **GPS location tagging** with multi-source place-name resolution (ArcGIS POI, Photon, Nominatim, plus optional Google Places / Goong Maps) and mini-map previews.
- **Double-Entry Inter-Wallet Transfers**: Transfer funds between accounts with atomic balance updates, strict balance verification, and ledger reconciliation.
- **Day-Grouped History & Calendar View**: Browse transactions grouped by day, search/filter across periods, or inspect daily cashflow in the calendar view.
- **Recurring Transactions**: Manage scheduled payments such as salary, rent, subscriptions, and utilities.

### 2. Budgets & Savings Goals
- **Category-Based Budgets**: Set spending limits per category on monthly or custom cycles.
- **Real-Time Tracking & Smart Alerts**: Automated notifications when approaching or exceeding spending thresholds (80% / 100%).
- **Savings Goals**: Create savings targets, log deposits with atomic integrity, and track progress toward completion.

### 3. Group Expenses & Bill Splitting
- **Shared Expense Groups**: Create and manage expense groups for families, roommates, trips, or events with secure invite-token/QR code workflows (`group_invites`) validated by Cloud Firestore security rules.
- **Flexible Bill Splitting**: Split equally or customize amounts and percentages per participant.
- **Debt Resolution & Settlement**: Real-time member balance summaries and optimized settlement tracking backed by both SQLite and Cloud Firestore.

### 4. Financial Reports & Analytics
- **Interactive Charts**: Pie charts, bar charts, and trend visualizations powered by `fl_chart`.
- **Precision Financial Metrics**: Dedicated calculation engine (`FinancialCalculationService` & integer minor-unit arithmetic) ensuring accurate totals, category breakdowns, and net worth without floating-point drift.
- **Data Export**: Export financial reports to **PDF**, **Excel (.xlsx)**, and **CSV**.

### 5. Smart Utilities & AI Integration
- **AI Financial Assistant**: Powered by Google Gemini API to analyze spending habits, answer financial questions, and provide budgeting insights.
- **Voice Input**: Log transactions hands-free using speech-to-text (`speech_to_text`).
- **Home Screen Widgets**: Quick balance/expense overview directly on the device home screen (`home_widget`).
- **Smart Notifications**: Budget threshold alerts, bill reminders, and distraction-free background sync notifications with monochrome Android status bar icons.
- **Personalization**: Light/Dark theme switching and multi-language support.

### 6. Security, Data Isolation & Offline-First Architecture
- **Firebase Auth & App Check**: Native Firebase Authentication (email verification, password reset) protected by Firebase App Check, plus Firestore and Storage security rules (`firestore.rules`, `storage.rules`).
- **Biometric & Encrypted Storage**: Fingerprint / Face ID app lock via `local_auth` and encrypted credential storage via `flutter_secure_storage`.
- **Per-User SQLite Isolation & Clean Session Lifecycle**: Strict multi-user data scoping (`SessionManager` & `OwnedTableOps`), uid-bound biometric unlock, complete local/cloud wipe on account deletion, and destructive-operation safeguards (`DestructiveOpsGuard`).
- **Reliable Offline-First Sync & Automated Daily Backup**: Local SQLite persistence (`sqflite`) paired with a durable sync queue (`SyncQueueWriter`, `SyncTrigger` & `SyncService`), multi-device sync convergence, initial cloud bootstrap before default-wallet creation, defensive Firestore parsing (`firestore_parse`), ledger reconciliation (`LedgerReconciliationService`), and scheduled midnight auto-backup (`MidnightSyncService` + Android `WorkManager` `MidnightBackupWorker`) with manual backup/restore in Privacy Settings.
- **Structured Logging**: Centralized `AppLogger` for diagnostics without leaking sensitive user data.

---

## Tech Stack

- **Framework**: Flutter (Dart SDK `^3.10.7`)
- **State Management**: `flutter_riverpod`
- **Backend & Cloud**: Firebase Core, Firebase Auth, Cloud Firestore, Firebase Storage, Firebase Messaging (FCM), Firebase App Check
- **Local Storage**: SQLite (`sqflite`), `shared_preferences`, `flutter_secure_storage`
- **Location & Maps**: `geolocator`, `geocoding`
- **Charts & UI**: `fl_chart`, `cached_network_image`, `home_widget`, Dark/Light Theme
- **Security**: `local_auth`, `crypto`, `firebase_app_check`
- **QR & Media**: `qr_flutter`, `mobile_scanner`, `image_picker`, `speech_to_text`, `record`
- **Reporting & Export**: `pdf`, `printing`, `excel`, `csv`, `file_saver`, `share_plus`
- **AI Integration**: Google Gemini API (`http`)

---

## Project Structure

```text
lib/
├── core/                  # Config, constants, errors, AppLogger, Riverpod providers,
│                          # SessionManager, DestructiveOpsGuard, themes
├── data/
│   ├── local/             # SQLite DatabaseHelper, OwnedTableOps, SyncQueueWriter
│   └── repositories/      # Domain repositories (Wallet, Transaction, Budget, Goal, etc.)
├── features/
│   └── group_expense/     # Clean-architecture group expense module (data/domain/presentation)
├── models/                # Core domain models (User, Wallet, Transaction, Budget, Goal, etc.)
├── modules/               # Feature UI screens
│   ├── ai_assistant/      # AI financial assistant chat
│   ├── auth/              # Sign in, sign up, password recovery
│   ├── budget/            # Budgets & savings goals
│   ├── calendar/          # Calendar transaction tracker
│   ├── home/              # Dashboard, wallets, statistics, notifications
│   ├── onboarding/        # First-launch onboarding
│   ├── settings/          # Profile, security, language, theme, data usage, support
│   ├── splash/            # App splash & session bootstrap
│   ├── transaction/       # Add, edit, detail, list, and categories
│   └── wallet/            # Wallet creation & transaction history
├── services/              # Auth, Firestore, Sync, SyncTrigger, MidnightSync, FinancialCalculation,
│                          # LedgerReconciliation, TransactionBalance, ReceiptStorage, Location,
│                          # PlaceNameResolver, SmartNotification, Theme, Language, AI
├── utils/                 # Finance precision arithmetic, time utils, currency/category helpers
└── widgets/               # Reusable UI components (LocationPickerSheet, MiniLocationMap,
                           # DayGroupedTransactionList, VoiceInputBottomSheet, etc.)

test/
├── features/group_expense/  # Group expense & split calculation tests
├── finance/                 # Precision arithmetic, double-entry transfer, atomic & goal tests
├── regression/              # Phase 1–4 security, precision, sync, and logging regression suites
├── sync/                    # Daily backup scheduling & multi-device sync convergence tests
├── balance_deduction_and_backup_test.dart
├── location_transaction_test.dart
├── phase3_reliable_sync_test.dart
├── plan_fixes_test.dart
└── wallet_default_and_day_group_test.dart
```

---

## Getting Started

### Prerequisites
- Flutter SDK (`>= 3.10.7`)
- Android Studio or VS Code with Flutter & Dart extensions
- Android/iOS emulator or physical device with debugging enabled

### Installation & Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/GiabBaoo/App-Money-Tracker.git
   cd money_tracker_app
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Configure API Keys & Optional Place Search Providers**:
   - Copy the example file to create your local `api_keys.dart` (ignored by Git):
     ```bash
     cp lib/core/constants/api_keys.example.dart lib/core/constants/api_keys.dart
     ```
   - Obtain a Gemini API key from [Google AI Studio](https://aistudio.google.com/) and fill in `defaultGeminiApiKey`.
   - *(Optional)* Copy `.env.example` to `.env` to configure `GOOGLE_PLACES_API_KEY` or `GOONG_API_KEY` for enhanced location autocomplete (defaults to the built-in free multi-source engine when omitted).

4. **Firebase Configuration**:
   - Ensure your Firebase project configuration (`google-services.json` for Android / `GoogleService-Info.plist` for iOS) is properly configured.
   - Email verification and password reset are handled natively by Firebase Auth SDK (no external SMTP credentials required).

5. **Run Static Analysis & Tests**:
   ```bash
   flutter analyze
   flutter test
   ```

6. **Run the Application**:
   ```bash
   flutter run
   ```

---

## Security & Contributing Guidelines
- **Confidentiality**: Never commit secrets such as `.env`, `lib/core/constants/api_keys.dart`, or private keystore/service-account credentials.
- **Code Quality**: Run `flutter analyze` and `flutter test` before opening a Pull Request.
- **Contributions**: Create a dedicated feature branch and submit a Pull Request for review.
