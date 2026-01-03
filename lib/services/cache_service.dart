import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/session.dart';
import '../models/source.dart';
import '../models/cache_metadata.dart';

class CachedItem<T> {
  final T data;
  final CacheMetadata metadata;

  CachedItem(this.data, this.metadata);
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
          baseDir = Directory(path.join(xdgCacheHome, 'jules_client'));
        } else {
          final home = Platform.environment['HOME'];
          if (home != null) {
            baseDir = Directory(path.join(home, '.cache', 'jules_client'));
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

  Future<void> saveSessions(String token, List<Session> newSessions) async {
    final cacheDir = await _getCacheDirectory(token);
    final sessionsDir = Directory(path.join(cacheDir.path, 'sessions'));
    if (!await sessionsDir.exists()) {
      await sessionsDir.create(recursive: true);
    }

    final now = DateTime.now();

    for (final session in newSessions) {
      final file = File(path.join(sessionsDir.path, '${session.id}.json'));
      CacheMetadata metadata;

      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final json = jsonDecode(content);
          final oldSession = Session.fromJson(json['data']);
          final oldMetadata = CacheMetadata.fromJson(json['metadata']);

          DateTime? lastUpdated = oldMetadata.lastUpdated;
          bool hasChanged = session.updateTime != oldSession.updateTime || session.state != oldSession.state;
          
          if (hasChanged) {
            lastUpdated = now;
          }

          metadata = oldMetadata.copyWith(
            lastRetrieved: now,
            lastUpdated: lastUpdated,
            // Labels preserved by default copyWith behavior if we pass null,
            // but we didn't implement 'replace' logic, just update logic.
          );

        } catch (e) {
           metadata = CacheMetadata(
            firstSeen: now,
            lastRetrieved: now,
            // lastOpened is null -> isNew
          );
        }
      } else {
        metadata = CacheMetadata(
          firstSeen: now,
          lastRetrieved: now,
          // lastOpened is null -> isNew
        );
      }

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
        } catch (e) {
          print('Error loading cached session: $e');
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
      final file = File(path.join(sourcesDir.path, '${source.id}.json'));
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
           metadata = CacheMetadata(
            firstSeen: now,
            lastRetrieved: now,
          );
        }
      } else {
        metadata = CacheMetadata(
          firstSeen: now,
          lastRetrieved: now,
        );
      }

      final dataToSave = {
        'data': newJson,
        'metadata': metadata.toJson(),
      };

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
        } catch (e) {
          print('Error loading cached source: $e');
        }
      }
    }
    return results;
  }
  
  Future<void> markSessionAsRead(String token, String sessionId) async {
    final cacheDir = await _getCacheDirectory(token);
    final file = File(path.join(cacheDir.path, 'sessions', '$sessionId.json'));
    if (await file.exists()) {
      final content = await file.readAsString();
      final json = jsonDecode(content);
      final metadata = CacheMetadata.fromJson(json['metadata']);
      
      final newMetadata = metadata.copyWith(
        lastOpened: DateTime.now(),
      );
      
      json['metadata'] = newMetadata.toJson();
      await file.writeAsString(jsonEncode(json));
    }
  }
}
