# Jules API Client

A Flutter-based client application for interacting with the Google Jules API. This application allows users to manage sessions, view sources, and communicate with the Jules agent through a modern, mobile-friendly interface.

## Features

### Authentication
- **Secure Login:** Supports authentication via API Key or OAuth2 Bearer Token.
- **Secure Storage:** Uses `flutter_secure_storage` to safely store user credentials.

### Session Management
- **List Sessions:** View a paginated list of all active and past sessions.
- **Filtering & Sorting:** Filter sessions by source and group them by status (e.g., Queued, Running, Completed).
- **Create Session:** specialized dialog to create new sessions with different modes:
    - **Question:** Standard query mode.
    - **Plan:** Requires plan approval.
    - **Start:** Automation mode (Auto Create PR).
- **Search:** Client-side search for sessions.

### Chat Interface
- **Interactive Chat:** Communicate with the agent in a chat-like interface.
- **Rich Media:** Support for attaching images to messages via URL.
- **Activity History:** View the full history of interactions and activities within a session.
- **Plan Approval:** Approve plans directly from the chat interface when required.

### Source Management
- **View Sources:** Browse available sources that the agent can access.
- **Privacy:** Visual indicators for private sources (masked titles).
- **Integration:** Filter sessions directly from the source list.

### Developer Tools (Dev Mode)
- **Toggleable Mode:** Enable "Dev Mode" in settings to access advanced debugging features.
- **API Viewer:** Inspect raw HTTP requests and responses for debugging API interactions.
- **Model Viewer:** View the raw JSON data of session and activity models.

## Architecture

The application follows a standard Flutter architecture using the Provider pattern for state management.

- **State Management:** `Provider` (`MultiProvider` at the root).
- **Navigation:** Bottom navigation bar switching between Sessions, Sources, and Settings.
- **Networking:** Custom `JulesClient` wrapper around `http` package.
- **JSON Parsing:** Robust parsing using `dartobjectutils` to handle API responses safely.

### Key Components

- **`lib/main.dart`:** Application entry point and provider setup.
- **`lib/services/`:**
    - `jules_client.dart`: Handles all API communication.
    - `auth_provider.dart`: Manages authentication state.
    - `session_provider.dart`: Manages session data and pagination.
- **`lib/ui/screens/`:**
    - `session_list_screen.dart`: Main dashboard.
    - `session_detail_screen.dart`: Chat interface.
    - `source_list_screen.dart`: Source browser.
- **`lib/models/`:** Data models mirroring the API resources (`Session`, `Source`, `Activity`).

## Setup & Running

### Prerequisites
- Flutter SDK (Latest Stable)
- Dart SDK

### Installation
1.  Clone the repository.
2.  Install dependencies:
    ```bash
    flutter pub get
    ```

### Running the App
Run the application on your preferred device or emulator:
```bash
flutter run
```
For web (headless/server mode):
```bash
flutter run -d web-server --web-port=8080
```

### Configuration
On first launch, you will be prompted to enter your credentials:
- **API Key:** Standard Google Cloud API Key.
- **Bearer Token:** OAuth2 token (if required).

## Dependencies

- `flutter`: UI Toolkit.
- `provider`: State management.
- `http`: Network requests.
- `flutter_secure_storage`: Secure credential storage.
- `shared_preferences`: Local settings storage.
- `intl`: Date and number formatting.
- `dartobjectutils`: Safe JSON parsing.
