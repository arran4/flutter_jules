# Jules Client

A comprehensive Flutter-based client application for interacting with the Google Jules API. This application provides a robust, cross-platform interface for managing sessions, browsing sources, and collaborating with the Jules agent.

## Features

### 🔐 Authentication & Security
- **Flexible Auth:** Supports both **API Key** (`X-Goog-Api-Key`) and **OAuth2 Bearer Token** authentication.
- **Secure Storage:** Credentials are encrypted and stored safely using `flutter_secure_storage`.
- **Privacy Masking:** Source titles are automatically masked (e.g., `*****`) for private sources to ensure confidentiality.

### 💬 Session Management & Chat
- **Rich Chat Interface:** Interactive message history with support for text and rich media.
- **Image Attachments:** Attach images to your prompts via URL. The client handles fetching and embedding them as base64 data.
- **Smart Creation:** Specialized dialog for creating sessions with specific modes:
    - **Question:** Standard Q&A.
    - **Plan:** Enforces a plan approval step (`requirePlanApproval`).
    - **Start:** Automation mode triggering `AUTO_CREATE_PR`.
- **Plan Approval:** Built-in UI to review and approve execution plans directly within the chat stream.
- **Progress Tracking:** Real-time updates on long-running tasks, showing step-by-step progress.
- **Pagination:** Infinite scrolling implementation to seamlessly load session history.

### 📚 Source Exploration
- **Source Browser:** View and filter available resources the agent can access.
- **Context Integration:** Start new sessions directly from a source context.
- **Search:** Client-side filtering with strict substring matching.

### 🛠️ Developer Tools (Dev Mode)
Enabled via the Settings screen, **Dev Mode** unlocks powerful inspection tools:
- **API Viewer:** Real-time inspection of HTTP requests and responses (headers, bodies, status codes) with sensitive token redaction.

- **Model Viewer:** Inspect the raw JSON data underlying any Session or Activity object.
- **Deep Linking:** Long-press on chat items for advanced context actions.

## Screenshots

### Main Dashboard
The session list provides a comprehensive overview of your active tasks, including real-time status updates.
![Main Dashboard](docs/Screenshot_20260110_200843.png)

### Session Details & Chat
Engage with the agent using a rich chat interface that supports markdown and media.
![Session Chat](docs/Screenshot_20260110_200716.png)

### Activity Log
View detailed activity logs and steps taken by the agent during a session.
![Activity View](docs/Screenshot_20260110_200722.png)

### Context Management
Manage and view the source context associated with your sessions.
![Context View](docs/Screenshot_20260110_200728.png)

### App Settings
Configure your preferences, API keys, and enable Developer Mode.
![Settings](docs/Screenshot_20260110_200739.png)

### User Interactions
Rich dialogs handle user input, approvals, and confirmations securely.
![Interactions](docs/Screenshot_20260110_200822.png)

### PR Status Tracking
Monitor your Pull Requests (Open, Merged, Draft) effortlessly from the session list.
![PR Integration](docs/Screenshot_20260110_200847.png)

### Advanced Filtering
Create and save filter presets to organize your workspace efficiently.
![Filter Presets](docs/Screenshot_20260110_200853.png)

### Session Creation
Start new tasks with specific modes (Plan, Question, Automate) using the creation wizard.
![New Session](docs/Screenshot_20260110_201004.png)

## Architecture

The application is built with **Flutter** and follows a scalable, maintainable architecture:

- **State Management:** **Provider** pattern.
    - `SessionProvider`: Manages session state, pagination, and implements a **2-minute cache** to optimize network usage.
    - `AuthProvider`: Handles credential persistence and validation.
    - `DevModeProvider`: Toggles developer tooling visibility.
- **Networking:** Custom `JulesClient` service wrapping the `http` package, handling:
    - Automatic pagination (following `nextPageToken`).
    - Error handling with detailed logging.
    - JSON serialization/deserialization.
- **Data Safety:** Uses `dartobjectutils` for robust, type-safe JSON parsing, preventing runtime crashes due to unexpected API schema changes.

## Project Structure

```text
lib/
├── main.dart                 # Application entry point & Provider setup
├── models.dart               # Export file for all models
├── services/
│   ├── jules_client.dart     # Core API client
│   ├── auth_provider.dart    # Auth state management
│   └── session_provider.dart # Session business logic & caching
├── models/                   # Data models (Session, Source, Activity, Media)
├── ui/
│   ├── screens/              # Full-screen widgets (SessionList, Detail, Login)
│   └── widgets/              # Reusable components (ApiViewer, NewSessionDialog)
└── utils/
    └── search_helper.dart    # Generic search & filtering logic
```

## Setup & Development

### Prerequisites

- **Flutter SDK:** Latest Stable channel.
- **Dart SDK:** Included with Flutter.

#### Linux Requirements
If building on Linux, ensure the following system dependencies are installed:
```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev
```
*Note: The app requires `uses-material-design: true` in `pubspec.yaml` for correct icon rendering.*

### Installation

1.  Clone the repository.
2.  Install dependencies:
    ```bash
    flutter pub get
    ```

### Running the App

**Desktop & Mobile:**
```bash
flutter run
```

**Web (Headless/Verification):**
To run in a headless web environment (e.g., for automated verification):
```bash
flutter run -d web-server --web-port=8080
```

### Building for Release

Release artifacts are generated in specific output directories. The CI pipeline automatically renames these for distribution.

| Platform | Build Command | Output Location |
|----------|---------------|-----------------|
| **Windows** | `flutter build windows` | `build/windows/x64/runner/Release` |
| **Linux** | `flutter build linux` | `build/linux/x64/release/bundle` |
| **macOS** | `flutter build macos` | `build/macos/Build/Products/Release/jules_client.app` |

### Code Quality & Testing

The project enforces strict code quality standards via CI:

- **Formatting:** Ensure code is formatted correctly.
    ```bash
    dart format .
    ```
- **Linting:** Analyze code for potential errors.
    ```bash
    flutter analyze
    ```
- **Testing:** Run unit and widget tests.
    ```bash
    flutter test
    ```

## Configuration

On first launch, the app routes to the Login screen. Credentials (API Key, Bearer Token) are stored securely on the device.
- To reset credentials, use the **Logout** button in the Settings screen.
- **Dev Mode** can be toggled in Settings to enable advanced debugging features.
