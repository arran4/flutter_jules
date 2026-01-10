import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class GithubProvider extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _githubApiKey = 'github_api_key';

  String? _apiKey;
  String? get apiKey => _apiKey;
  // Rate Limiting
  int? _rateLimitLimit;
  int? _rateLimitRemaining;
  DateTime? _rateLimitReset;

  // Queue
  final List<GithubJob> _queue = [];
  bool _isProcessingQueue = false;

  int? get rateLimitLimit => _rateLimitLimit;
  int? get rateLimitRemaining => _rateLimitRemaining;
  DateTime? get rateLimitReset => _rateLimitReset;
  List<GithubJob> get queue => List.unmodifiable(_queue);

  GithubProvider() {
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    _apiKey = await _secureStorage.read(key: _githubApiKey);
    notifyListeners();
  }

  Future<void> setApiKey(String apiKey) async {
    await _secureStorage.write(key: _githubApiKey, value: apiKey);
    _apiKey = apiKey;
    notifyListeners();
  }

  Future<String?> getPrStatus(
      String owner, String repo, String prNumber) async {
    if (_apiKey == null) {
      return null;
    }

    final job = GithubJob(
      id: 'pr_status_${owner}_${repo}_$prNumber',
      description: 'Check PR Status: $owner/$repo #$prNumber',
      action: () async {
        final url = Uri.parse(
            'https://api.github.com/repos/$owner/$repo/pulls/$prNumber');
        final response = await http.get(
          url,
          headers: {
            'Authorization': 'token $_apiKey',
            'Accept': 'application/vnd.github.v3+json',
          },
        );

        _updateRateLimits(response.headers);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['draft'] == true) {
            return 'Draft';
          } else if (data['merged'] == true) {
            return 'Merged';
          } else if (data['state'] == 'closed') {
            return 'Closed';
          } else {
            return 'Open';
          }
        } else {
          return null;
        }
      },
    );

    _queue.add(job);
    _processQueue();
    notifyListeners();

    // Wait for job to complete
    await job.completer.future;
    return job.result as String?;
  }

  void _updateRateLimits(Map<String, String> headers) {
    if (headers.containsKey('x-ratelimit-limit')) {
      _rateLimitLimit = int.tryParse(headers['x-ratelimit-limit']!);
    }
    if (headers.containsKey('x-ratelimit-remaining')) {
      _rateLimitRemaining = int.tryParse(headers['x-ratelimit-remaining']!);
    }
    if (headers.containsKey('x-ratelimit-reset')) {
      final resetEpoch = int.tryParse(headers['x-ratelimit-reset']!);
      if (resetEpoch != null) {
        _rateLimitReset =
            DateTime.fromMillisecondsSinceEpoch(resetEpoch * 1000);
      }
    }
    notifyListeners();
  }

  Duration get waitTime {
    if (_rateLimitRemaining != null &&
        _rateLimitRemaining! <= 0 &&
        _rateLimitReset != null) {
      final diff = _rateLimitReset!.difference(DateTime.now());
      return diff.isNegative ? Duration.zero : diff;
    }
    return Duration.zero;
  }

  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    while (_queue.isNotEmpty) {
      // Check Rate Limits
      if (_rateLimitRemaining != null && _rateLimitRemaining! <= 0) {
        if (_rateLimitReset != null &&
            _rateLimitReset!.isAfter(DateTime.now())) {
          final wait = _rateLimitReset!.difference(DateTime.now());
          // Notify listeners so UI updates status to "Waiting"
          notifyListeners();
          // Force adherence
          await Future.delayed(wait);

          // After waiting, we assume quota is reset (or will be upon next request)
          // We can optimistically reset local counters or just proceed
          _rateLimitRemaining = null; // Let next request update it
        }
      }

      final job = _queue.firstWhere((j) => j.status == GithubJobStatus.pending,
          orElse: () =>
              GithubJob(id: 'none', description: '', action: () async {})
                ..status = GithubJobStatus.completed);

      if (job.id == 'none') {
        break;
      }

      job.status = GithubJobStatus.running;
      notifyListeners();

      try {
        job.result = await job.action();
        job.status = GithubJobStatus.completed;
        job.completer.complete();
      } catch (e) {
        job.status = GithubJobStatus.failed;
        job.error = e.toString();
        job.completer.completeError(e);
      } finally {
        _queue.remove(job);
      }
      notifyListeners();

      // Artificial delay for throttling safety (wait time between requests)
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _isProcessingQueue = false;
  }
}

enum GithubJobStatus { pending, running, completed, failed }

class GithubJob {
  final String id;
  final String description;
  final Future<dynamic> Function() action;
  final Completer<void> completer = Completer<void>();

  GithubJobStatus status = GithubJobStatus.pending;
  dynamic result;
  String? error;

  GithubJob(
      {required this.id, required this.description, required this.action});
}
