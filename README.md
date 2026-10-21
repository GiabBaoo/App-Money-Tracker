# Money Tracker App (Personal & Group Expense Manager)

A smart, modern personal and group financial management mobile application built on **Flutter**, featuring AI financial assistance, budget controls, split-expense calculations, and cross-device cloud synchronization.

---

## Key Features

### 1. Income/Expense & Multi-Wallet Management
- **Multiple Wallet Types**: Manage Cash, Bank Accounts, E-wallets (Momo, ZaloPay, etc.), Credit Cards, and Savings.
- **Fast Transaction Logging**: Record amount, category, date & time, receipt photos, location, and notes.
- **Inter-wallet Transfers**: Easily transfer funds between accounts with strict balance verification and audit history.
- **Recurring Transactions**: Automatically manage scheduled payments such as salary, rent, subscriptions, and utilities.

### 2. Budgets & Savings Goals
- **Category-based Budgets**: Set spending limits by category (Food & Dining, Shopping, Transport, etc.) on monthly or custom cycles.
- **Visual Progress & Proactive Alerts**: Track expenses in real time with automated alerts when reaching 80% and 100% of limits.
- **Savings Goals**: Set goals, log deposits, and monitor progress toward targets with estimated completion dates.

### 3. Group Expenses & Bill Splitting
- **Shared Group Finances**: Create expense groups for families, room-mates, trips, or events.
- **Flexible Bill Splitting**: Split equally or customize amounts and percentages per participant.
- **Debt Resolution & Settlement**: Real-time balance reports and optimized debt settlements to minimize transfer transactions.

### 4. Financial Reports & Analytics
- **Interactive Visualizations**: Clean charts (Pie charts, Bar charts, Trend lines) powered by `fl_chart`.
- **Multi-Period Filtering**: Filter transactions and spending patterns by week, month, quarter, year, or custom date ranges.
- **Data Exporting**: Export reports in **PDF**, **Excel (.xlsx)**, or **CSV** formats.

### 5. Smart Utilities & AI Integration
- **Smart Habit Autofill**: Learns spending frequency and habits to auto-suggest and autofill categories and notes when common amounts are entered.
- **Streamlined Status Notifications & Mono Brand Icon**:
  - Android-compliant monochrome **mono** icon on the status bar and taskbar with brand tinting.
  - Distraction-free background syncs while preserving high-priority financial notices (budget alerts, daily/monthly ceilings, recurring bill deadlines).
- **AI Financial Assistant (Google Gemini & Local LLM)**: Analyzes spending patterns, provides financial health tips, and answers budgeting questions.
- **Natural Voice Input**: Create transactions using natural speech (e.g., *"Lunch 45 thousand cash wallet"*).
- **Receipt OCR Scanner**: Automatically extracts amounts, dates, and merchant information from receipt snapshots.
- **Bank SMS Parser**: Automatically parses balance change SMS messages from popular Vietnamese banks (Vietcombank, Techcombank, MB, BIDV, VPBank, ACB, etc.).

### 6. Security & Offline-First Architecture
- **Biometric Security**: Protect sensitive financial information with Fingerprint / Face ID via `local_auth`.
- **Encrypted Local Storage**: Sensitive credentials and preferences stored using `flutter_secure_storage`.
- **Offline-First Sync**: Seamlessly works offline via local SQLite / Hive storage, automatically synchronizing to Firebase Cloud Firestore upon reconnecting.
- **Quiet Midnight Backup**: Safe scheduled background sync without user interruption.

---

## Tech Stack

- **Framework**: Flutter (Dart SDK ^3.10.7)
- **State Management**: Flutter Riverpod & Provider
- **Backend & Cloud**: Firebase Core, Firebase Auth, Cloud Firestore, Firebase Storage, Firebase Messaging (FCM)
- **Local Storage**: SQLite (`sqflite`), Hive
- **Charts & UI**: `fl_chart`, Custom Micro-animations, Dark/Light Theme modes
- **Security & Crypto**: `local_auth`, `flutter_secure_storage`, `crypto`
- **File Processing & Reporting**: `excel`, `pdf`, `csv`, `printing`, `share_plus`
- **AI & Integrations**: Google Gemini API, Local LLM Integration

---

## Project Structure

```text
lib/
├── core/                  # Core configurations, constants, theme, API key templates
├── data/
│   ├── local/             # SQLite local database & data tables
│   ├── models/            # Data transfer objects & entity converters
│   └── repositories/      # Repositories handling business logic & data access
├── features/
│   └── group_expense/     # Shared group expense feature
├── models/                # Domain models (Wallet, Transaction, Budget, Goal, etc.)
├── modules/               # Feature-based presentation modules & screens
│   ├── ai_assistant/      # AI assistant & financial conversations
│   ├── auth/              # Sign up, Sign in, Password recovery
│   ├── budget/            # Budget & savings management
│   ├── calendar/          # Calendar view for daily transactions
│   ├── home/              # Dashboard, wallets, summary & reports
│   ├── settings/          # User preferences, security, devices, themes
│   └── transaction/       # Create, edit, delete, view transaction details
├── services/              # Infrastructure services (AI, SMS, Sync, Notification, Voice)
├── utils/                 # Formatting utilities (currency, date-time, categories)
└── widgets/               # Reusable UI widgets and custom components
```

---

## Getting Started

### Prerequisites
- Flutter SDK (>= 3.10)
- Android Studio / VS Code with Dart & Flutter extensions
- Android/iOS emulator or a physical test device with USB debugging enabled

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

3. **Configure API Keys (Google Gemini AI)**:
   - Copy the template file `lib/core/constants/api_keys.example.dart` to `lib/core/constants/api_keys.dart`:
     ```bash
     cp lib/core/constants/api_keys.example.dart lib/core/constants/api_keys.dart
     ```
   - Obtain an API key from [Google AI Studio](https://aistudio.google.com/).
   - Populate `defaultGeminiApiKey` in `lib/core/constants/api_keys.dart`.

4. **Verify codebase**:
   ```bash
   flutter analyze
   flutter test
   ```

5. **Run the application**:
   ```bash
   flutter run
   ```

---

## Security & Contributing Guidelines
- **Confidentiality**: Never commit secrets such as `.env`, `api_keys.dart`, or personal `google-services.json` files.
- **Contributions**: Please create a separate feature branch and submit a Pull Request for review.
