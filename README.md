<p align="center">
  <img src="assets/icon/app_icon.png" width="256" alt="App Icon">
</p>

# Arran's Flutter based jules client

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

### ⚡ Bulk Operations
- **Powerful Automation:** Perform complex sequences of actions across hundreds of sessions simultaneously.
- **Advanced Targeting:** Use the full power of the search and filter system to select target sessions.
- **Flexible Execution:**
    - **Parallelism:** Configure multiple concurrent queries to speed up processing.
    - **Dynamic Delays:** Adjust inter-job wait times (ms, s, min) in real-time.
    - **Execution Control:** Set limits, skip offsets, randomize orders, and toggle 'stop-on-error' behavior.
- **Real-time Monitoring:** Activity logs, progress bars, and estimated time remaining calculations keep you informed.
- **Action Sequencing:** Chain multiple operations (e.g., *Refresh -> Quick Reply -> Mark as Read*) for each session.

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

### Complex Query Visualization
Visualize and construct intricate logical queries (AND/OR/NOT groups) to pinpoint exact sessions.
![Complex Queries](docs/complex_query_builder.png)

### Session Creation
Start new tasks with specific modes (Plan, Question, Automate) using the creation wizard.
![New Session](docs/Screenshot_20260110_201004.png)

### Bulk Actions Configuration
Configure complex automation workflows with advanced targeting and execution controls.
![Bulk Actions Config](docs/Screenshot_20260110_234928.png)

### Bulk Execution Progress
Monitor real-time progress, logs, and estimated time for long-running bulk operations.
![Bulk Progress](docs/Screenshot_20260110_235057.png)

### Action Library
Choose from a wide variety of supported actions to build your automation sequence.
![Action Library](docs/Screenshot_20260110_235146.png)

## Setup & Development

### Prerequisites

- **Flutter SDK:** Latest Stable channel.
- **Dart SDK:** Included with Flutter.

#### Linux Requirements
If building on Linux, ensure the following system dependencies are installed:
```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev
```

### Running the App

**Desktop & Mobile:**
```bash
flutter run
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
