import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_jules/services/settings_provider.dart';
import 'package:flutter_jules/services/dev_mode_provider.dart';
import 'package:flutter_jules/services/auth_provider.dart';
import 'package:flutter_jules/services/github_provider.dart';
import 'package:flutter_jules/ui/screens/settings_screen.dart';

// Create a mock class for SettingsProvider
class MockSettingsProvider extends Mock implements SettingsProvider {
  @override
  List<RefreshSchedule> get schedules => [];

  @override
  SessionRefreshPolicy get refreshOnOpen => SessionRefreshPolicy.shallow;
  @override
  SessionRefreshPolicy get refreshOnMessage => SessionRefreshPolicy.shallow;
  @override
  ListRefreshPolicy get refreshOnReturn => ListRefreshPolicy.dirty;
  @override
  ListRefreshPolicy get refreshOnCreate => ListRefreshPolicy.quick;
  @override
  int get sessionPageSize => 100;
  @override
  bool get notifyOnAttention => true;
  @override
  bool get notifyOnCompletion => true;
  @override
  bool get notifyOnWatch => true;
  @override
  bool get notifyOnFailure => true;
  @override
  bool get trayEnabled => false;
  @override
  FabVisibility get fabVisibility => FabVisibility.floating;
  @override
  bool get hideArchivedAndReadOnly => true;
  @override
  List<GithubExclusion> get githubExclusions => [];
  @override
  bool get useCorpJulesUrl => false;

  // Keybindings
  @override
  MessageSubmitAction get enterKeyAction => MessageSubmitAction.addNewLine;
  @override
  MessageSubmitAction get shiftEnterKeyAction => MessageSubmitAction.addNewLine;
  @override
  MessageSubmitAction get ctrlEnterKeyAction => MessageSubmitAction.submitsMessage;
  @override
  MessageSubmitAction get ctrlShiftEnterKeyAction => MessageSubmitAction.submitsMessageAndGoesBack;
  @override
  EscKeyAction get escKeyAction => EscKeyAction.doesNothing;

  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  void notifyListeners() {}

  @override
  Future<void> addSchedule(RefreshSchedule schedule) async {}
  @override
  Future<void> updateSchedule(RefreshSchedule schedule) async {}
}

class MockDevModeProvider extends Mock implements DevModeProvider {
  @override
  bool get isDevMode => false;
  @override
  bool get enableApiLogging => false;

  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

class MockAuthProvider extends Mock implements AuthProvider {
  @override
  TokenType get tokenType => TokenType.accessToken;
  @override
  String? get token => "test-token";

  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

class MockGithubProvider extends Mock implements GithubProvider {
  @override
  bool get hasBadCredentials => false;
  @override
  String? get apiKey => "test-key";

  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

void main() {
  testWidgets('SettingsScreen dialog has frequency dropdown', (WidgetTester tester) async {
    final settingsProvider = MockSettingsProvider();
    final devModeProvider = MockDevModeProvider();
    final authProvider = MockAuthProvider();
    final githubProvider = MockGithubProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SettingsProvider>.value(value: settingsProvider),
          Provider<DevModeProvider>.value(value: devModeProvider),
          Provider<AuthProvider>.value(value: authProvider),
          Provider<GithubProvider>.value(value: githubProvider),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    // Find and tap the add schedule button
    final addIcon = find.byIcon(Icons.add);
    expect(addIcon, findsOneWidget);
    await tester.tap(addIcon);
    await tester.pumpAndSettle();

    // Verify dialog title
    expect(find.text('Add Schedule'), findsOneWidget);

    // Verify Frequency dropdown is present
    expect(find.text('Frequency'), findsOneWidget);

    // Initially "Hourly" is default, so "Interval (minutes)" TextField should NOT be visible
    expect(find.text('Hourly'), findsOneWidget);
    expect(find.text('Interval (minutes)'), findsNothing);

    // Open dropdown
    await tester.tap(find.text('Hourly'));
    await tester.pumpAndSettle();

    // Select "Custom"
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();

    // Now "Interval (minutes)" TextField SHOULD be visible
    expect(find.text('Interval (minutes)'), findsOneWidget);

    // Select "Never"
    // Open dropdown
    await tester.tap(find.text('Custom').first); // The one in the field
    await tester.pumpAndSettle();

    await tester.tap(find.text('Never').last);
    await tester.pumpAndSettle();

    // Now "Interval (minutes)" should NOT be visible
    expect(find.text('Interval (minutes)'), findsNothing);
  });
}
