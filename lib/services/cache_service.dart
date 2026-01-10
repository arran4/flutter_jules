import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/session.dart';
import '../models/source.dart';
import '../models/activity.dart';
import '../models/cache_metadata.dart';
import '../models/queued_message.dart';

class CachedItem<T> {
  final T data;
  final CacheMetadata metadata;

  CachedItem(this.data, this.metadata);
}

class CachedSessionDetails {
  final Session session;
  final List<Activity> activities;
  final String? sessionUpdateTimeSnapshot;

  CachedSessionDetails({
    required this.session,
    required this.activities,
    this.sessionUpdateTimeSnapshot,
  });
}

class CacheService {
  final bool isDevMode;

  CacheService({this.isDevMode = false});

  Future<Directory> _getCacheDirectory(String token) async {
    final bytes = utf8.encode(token);
    final digest = sha256.convert(bytes);
    final tokenHash = digest.toString();

    Directory baseDir;
    if (isDevMode) {
      baseDir = Directory(path.join(Directory.current.path, '.data'));
    } else {
      if (Platform.isLinux) {
        final xdgCacheHome = Platform.environment['XDG_CACHE_HOME'];
        if (xdgCacheHome != null && xdgCacheHome.isNotEmpty) {
          baseDir = Directory(path.join(xdgCacheHome, 'flutter_jules_agent'));
        } else {
          final home = Platform.environment['HOME'];
          if (home != null) {
            baseDir = Directory(
              path.join(home, '.cache', 'flutter_jules_agent'),
            );
          } else {
            baseDir = await getApplicationCacheDirectory();
          }
        }
      } else {
        baseDir = await getApplicationCacheDirectory();
      }
    }

    final cachePath = path.join(baseDir.path, tokenHash);
    final directory = Directory(cachePath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> getMessageQueueFileForToken(String token) async {
    final dir = await _getCacheDirectory(token);
    return File(path.join(dir.path, 'message_queue.json'));
  }

  Future<void> saveSessions(
    String token,
    List<CachedItem<Session>> items,
  ) async {
    final cacheDir = await _getCacheDirectory(token);
    final sessionsDir = Directory(path.join(cacheDir.path, 'sessions'));
    if (!await sessionsDir.exists()) {
      await sessionsDir.create(recursive: true);
    }

    for (final item in items) {
      final session = item.data;
      final metadata = item.metadata;

      final fileName = '${Uri.encodeComponent(session.id)}.json';
      final file = File(path.join(sessionsDir.path, fileName));

      final dataToSave = {
        'data': session.toJson(),
        'metadata': metadata.toJson(),
      };

      await file.writeAsString(jsonEncode(dataToSave));
    }
  }

  Future<List<CachedItem<Session>>> loadSessions(String token) async {
    final cacheDir = await _getCacheDirectory(token);
    final sessionsDir = Directory(path.join(cacheDir.path, 'sessions'));
    if (!await sessionsDir.exists()) {
      return [];
    }

    final List<CachedItem<Session>> results = [];
    await for (final entity in sessionsDir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final json = jsonDecode(content);
          final session = Session.fromJson(json['data']);
          final metadata = CacheMetadata.fromJson(json['metadata']);
          results.add(CachedItem(session, metadata));
        } catch (_) {
          // Ignore cache load errors
        }
      }
    }
    return results;
  }

  Future<void> saveSources(String token, List<Source> newSources) async {
    final cacheDir = await _getCacheDirectory(token);
    final sourcesDir = Directory(path.join(cacheDir.path, 'sources'));
    if (!await sourcesDir.exists()) {
      await sourcesDir.create(recursive: true);
    }

    final now = DateTime.now();

    for (final source in newSources) {
      final fileName = '${Uri.encodeComponent(source.id)}.json';
      final file = File(path.join(sourcesDir.path, fileName));
      CacheMetadata metadata;

      final newJson = source.toJson();

      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final json = jsonDecode(content);
          final oldSourceData = json['data'];
          final oldMetadata = CacheMetadata.fromJson(json['metadata']);

          bool changed = jsonEncode(newJson) != jsonEncode(oldSourceData);
          DateTime? lastUpdated = oldMetadata.lastUpdated;

          if (changed) {
            lastUpdated = now;
          }

          metadata = oldMetadata.copyWith(
            lastRetrieved: now,
            lastUpdated: lastUpdated,
          );
        } catch (e) {
          metadata = CacheMetadata(firstSeen: now, lastRetrieved: now);
        }
      } else {
        metadata = CacheMetadata(firstSeen: now, lastRetrieved: now);
      }

      final dataToSave = {'data': newJson, 'metadata': metadata.toJson()};

      await file.writeAsString(jsonEncode(dataToSave));
    }
  }

  Future<List<CachedItem<Source>>> loadSources(String token) async {
    final cacheDir = await _getCacheDirectory(token);
    final sourcesDir = Directory(path.join(cacheDir.path, 'sources'));
    if (!await sourcesDir.exists()) {
      return [];
    }

    final List<CachedItem<Source>> results = [];
    await for (final entity in sourcesDir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final json = jsonDecode(content);
          final source = Source.fromJson(json['data']);
          final metadata = CacheMetadata.fromJson(json['metadata']);
          results.add(CachedItem(source, metadata));
        } catch (_) {
          // Ignore cache load error
        }
      }
    }
    return results;
  }

  Future<void> markSessionAsRead(String token, String sessionId) async {
    final cacheDir = await _getCacheDirectory(token);
    // Might be in sessions or cached_details, but we track metadata in sessions list usually
    final fileName = '${Uri.encodeComponent(sessionId)}.json';
    final file = File(path.join(cacheDir.path, 'sessions', fileName));
    if (await file.exists()) {
      final content = await file.readAsString();
      final json = jsonDecode(content);
      final metadata = CacheMetadata.fromJson(json['metadata']);

      final newMetadata = metadata.copyWith(lastOpened: DateTime.now());

      json['metadata'] = newMetadata.toJson();
      await file.writeAsString(jsonEncode(json));
    }
  }

  Future<void> markSessionAsUnread(String token, String sessionId) async {
    final cacheDir = await _getCacheDirectory(token);
    final fileName = '${Uri.encodeComponent(sessionId)}.json';
    final file = File(path.join(cacheDir.path, 'sessions', fileName));
    if (await file.exists()) {
      final content = await file.readAsString();
      final json = jsonDecode(content);
      final metadata = CacheMetadata.fromJson(json['metadata']);

      final newMetadata = CacheMetadata(
        firstSeen: metadata.firstSeen,
        lastRetrieved: metadata.lastRetrieved,
        lastOpened: null, // Explicitly set to null for unread
        lastUpdated: metadata.lastUpdated,
        labels: metadata.labels,
      );

      json['metadata'] = newMetadata.toJson();
      await file.writeAsString(jsonEncode(json));
    }
  }

  Future<void> markPrAsOpened(String token, String sessionId) async {
    await markSessionAsRead(token, sessionId);
    final cacheDir = await _getCacheDirectory(token);
    final fileName = '${Uri.encodeComponent(sessionId)}.json';
    final file = File(path.join(cacheDir.path, 'sessions', fileName));
    if (await file.exists()) {
      final content = await file.readAsString();
      final json = jsonDecode(content);
      final metadata = CacheMetadata.fromJson(json['metadata']);

      final newMetadata = metadata.copyWith(lastPrOpened: DateTime.now());

      json['metadata'] = newMetadata.toJson();
      await file.writeAsString(jsonEncode(json));
    }
  }

  Future<void> updateSession(String token, Session session) async {
    final cacheDir = await _getCacheDirectory(token);
    final fileName = '${Uri.encodeComponent(session.id)}.json';
    final file = File(path.join(cacheDir.path, 'sessions', fileName));
    
    if (await file.exists()) {
      final content = await file.readAsString();
      final json = jsonDecode(content);
      
      // Update session data but preserve metadata
      json['data'] = session.toJson();
      
      await file.writeAsString(jsonEncode(json));
    }
  }

  // New methods for session details (activities) cache
  Future<void> saveSessionDetails(
    String token,
    Session session,
    List<Activity> activities,
  ) async {
    final cacheDir = await _getCacheDirectory(token);
    final detailsDir = Directory(path.join(cacheDir.path, 'session_details'));
    if (!await detailsDir.exists()) {
      await detailsDir.create(recursive: true);
    }

    final fileName = '${Uri.encodeComponent(session.id)}.json';
    final file = File(path.join(detailsDir.path, fileName));

    final dataToSave = {
      'session': session.toJson(), // Store full session as well
      'activities': activities.map((a) => a.toJson()).toList(),
      'sessionUpdateTimeSnapshot': session.updateTime, // The key linkage
      'savedAt': DateTime.now().toIso8601String(),
    };

    await file.writeAsString(jsonEncode(dataToSave));
  }

  Future<CachedSessionDetails?> loadSessionDetails(
    String token,
    String sessionId,
  ) async {
    final cacheDir = await _getCacheDirectory(token);
    final fileName = '${Uri.encodeComponent(sessionId)}.json';
    final file = File(path.join(cacheDir.path, 'session_details', fileName));

    if (!await file.exists()) {
      return null;
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content);

      final session = Session.fromJson(json['session']);
      final activities = (json['activities'] as List<dynamic>?)
              ?.map((e) => Activity.fromJson(e))
              .toList() ??
          [];

      return CachedSessionDetails(
        session: session,
        activities: activities,
        sessionUpdateTimeSnapshot: json['sessionUpdateTimeSnapshot'],
      );
    } catch (e) {
      // Ignore cache load error
      return null;
    }
  }

  // Message Queue
  Future<void> saveMessageQueue(String token, List<QueuedMessage> queue) async {
    final cacheDir = await _getCacheDirectory(token);
    final file = File(path.join(cacheDir.path, 'message_queue.json'));
    final json = queue.map((m) => m.toJson()).toList();
    await file.writeAsString(jsonEncode(json));
  }

  Future<List<QueuedMessage>> loadMessageQueue(String token) async {
    final cacheDir = await _getCacheDirectory(token);
    final file = File(path.join(cacheDir.path, 'message_queue.json'));
    if (!await file.exists()) {
      return [];
    }
    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as List;
      return json.map((e) => QueuedMessage.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }
}
