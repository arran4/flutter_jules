import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jules_client/main.dart' as app;
import 'package:jules_client/models.dart';
import 'package:jules_client/models/api_exchange.dart';
import 'package:jules_client/services/auth_provider.dart';
import 'package:jules_client/services/dev_mode_provider.dart';
import 'package:jules_client/services/jules_client.dart';
import 'package:jules_client/services/session_provider.dart';
import 'package:jules_client/services/settings_provider.dart';
import 'package:jules_client/services/source_provider.dart';
import 'package:jules_client/services/cache_service.dart';
import 'package:provider/provider.dart';
import '../test/mock_data.dart';

// Mock Client
class MockJulesClient extends Fake implements JulesClient {
  @override
  Future<ListSessionsResponse> listSessions({int? pageSize, String? pageToken, void Function(ApiExchange)? onDebug}) async {
    return ListSessionsResponse(sessions: MockData.mockSessions, nextPageToken: null);
  }

  @override
  Future<List<Activity>> listActivities(String sessionId, {void Function(ApiExchange)? onDebug}) async {
    return MockData.mockActivities;
  }

  @override
  Future<ListSourcesResponse> listSources({int? pageSize, String? pageToken, void Function(ApiExchange)? onDebug}) async {
    return ListSourcesResponse(sources: MockData.mockSources, nextPageToken: null);
  }

  @override
  Future<Session> getSession(String sessionId, {void Function(ApiExchange)? onDebug}) async {
    return MockData.mockSession;
  }
}

// Mock Auth Provider
class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool get isAuthenticated => true;
  @override
  bool get isLoading => false;
  @override
  String? get token => 'mock_token';
  @override
  JulesClient get client => MockJulesClient();

  @override
  Future<void> logout() async {}

  @override
  Future<void> setToken(String token, TokenType type) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  TokenType get tokenType => TokenType.apiKey;
}

// Mock Cache Service (to prevent disk access)
class MockCacheService extends Fake implements CacheService {
  @override
  Future<List<CachedItem<Session>>> loadSessions(String key) async {
    return [];
  }
  @override
  Future<void> saveSessions(String key, List<Session> sessions) async {}
  @override
  Future<void> markSessionAsRead(String key, String sessionId) async {}
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('Generate Screenshots', (WidgetTester tester) async {
    // Override providers to use mocks
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => MockAuthProvider()),
          ChangeNotifierProvider(create: (_) => DevModeProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          Provider<CacheService>(create: (_) => MockCacheService()),
          ChangeNotifierProxyProvider<CacheService, SessionProvider>(
            create: (_) => SessionProvider(),
            update: (_, cache, session) => session!..setCacheService(cache),
          ),
          ChangeNotifierProxyProvider<CacheService, SourceProvider>(
            create: (_) => SourceProvider(),
            update: (_, cache, source) => source!..setCacheService(cache),
          ),
        ],
        child: const app.MyApp(),
      ),
    );

    // 1. Session List Screen
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('01_session_list');

    // 2. Session Detail Screen
    // Find the first session and tap it
    final firstSessionFinder = find.text(MockData.mockSession.title!);
    expect(firstSessionFinder, findsOneWidget);
    await tester.tap(firstSessionFinder);
    await tester.pumpAndSettle();

    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('02_session_detail');

    // Go back
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 3. Source List Screen
    // Open menu
    // AppBar actions are: Refresh, Filter, PopupMenu
    // The PopupMenu is the 3 dots.
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    // Tap "Repositories"
    await tester.tap(find.text('Repositories'));
    await tester.pumpAndSettle();

    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('03_source_list');

    // Go back
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 4. Settings Screen
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('04_settings');

  });
}
