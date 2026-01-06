import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_provider.dart';
import 'services/dev_mode_provider.dart';
import 'services/session_provider.dart';
import 'services/source_provider.dart';
import 'services/message_queue_provider.dart';
import 'services/settings_provider.dart';
import 'services/cache_service.dart';
import 'ui/screens/session_list_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/source_list_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DevModeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
        ProxyProvider<DevModeProvider, CacheService>(
          update: (_, devMode, __) =>
              CacheService(isDevMode: devMode.isDevMode),
        ),
        ChangeNotifierProxyProvider<CacheService, SessionProvider>(
          create: (_) => SessionProvider(),
          update: (_, cache, session) => session!..setCacheService(cache),
        ),
        ChangeNotifierProxyProvider<CacheService, SourceProvider>(
          create: (_) => SourceProvider(),
          update: (_, cache, source) => source!..setCacheService(cache),
        ),
        ChangeNotifierProxyProvider2<CacheService, AuthProvider,
            MessageQueueProvider>(
          create: (_) => MessageQueueProvider(),
          update: (_, cache, auth, queue) =>
              queue!..setCacheService(cache, auth.token),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jules API Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      routes: {
        '/settings': (context) => const SettingsScreen(),
        '/sources_raw': (context) => const SourceListScreen(),
      },
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!auth.isAuthenticated) {
            return const LoginScreen();
          }
          return const SessionListScreen();
        },
      ),
    );
  }
}
