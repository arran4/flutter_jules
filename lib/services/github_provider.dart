import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:dartobjectutils/dartobjectutils.dart';

class GithubApiException implements Exception {
  final int statusCode;
  final String message;

  GithubApiException(this.statusCode, this.message);

  @override
  String toString() => 'GithubApiException: $statusCode $message';
}

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

  Future<String?> getToken() async => _apiKey;

  Future<GitHubPrResponse?> getPrStatus(
    String owner,
    String repo,
    String prNumber,
  ) async {
    if (_apiKey == null) {
      return null;
    }

    final job = GithubJob(
      id: 'pr_status_${owner}_${repo}_$prNumber',
      description: 'Check PR Status: $owner/$repo #$prNumber',
      action: () async {
        final url = Uri.parse(
          'https://api.github.com/repos/$owner/$repo/pulls/$prNumber',
        );
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
          return GitHubPrResponse(data);
        } else {
          throw GithubApiException(response.statusCode, response.body);
        }
      },
    );

    _queue.add(job);
    _processQueue();
    notifyListeners();

    // Wait for job to complete
    await job.completer.future;
    return job.result as GitHubPrResponse?;
  }

  Future<String?> getDiff(String owner, String repo, String prNumber) async {
    if (_apiKey == null) return null;
    final url = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/pulls/$prNumber',
    );
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'token $_apiKey',
        'Accept': 'application/vnd.github.v3.diff',
      },
    );
    _updateRateLimits(response.headers);
    if (response.statusCode == 200) {
      return response.body;
    }
    return null;
  }

  Future<String?> getPatch(String owner, String repo, String prNumber) async {
    if (_apiKey == null) return null;
    final url = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/pulls/$prNumber',
    );
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'token $_apiKey',
        'Accept': 'application/vnd.github.v3.patch',
      },
    );
    _updateRateLimits(response.headers);
    if (response.statusCode == 200) {
      return response.body;
    }
    return null;
  }

  Future<String?> getCIStatus(
    String owner,
    String repo,
    String prNumber,
  ) async {
    if (_apiKey == null) return null;

    final job = GithubJob(
      id: 'ci_status_${owner}_${repo}_$prNumber',
      description: 'Check CI Status: $owner/$repo #$prNumber',
      action: () async {
        // 1. Get the PR's head SHA
        final prUrl = Uri.parse(
          'https://api.github.com/repos/$owner/$repo/pulls/$prNumber',
        );
        final prResponse = await http.get(
          prUrl,
          headers: {
            'Authorization': 'token $_apiKey',
            'Accept': 'application/vnd.github.v3+json',
          },
        );
        _updateRateLimits(prResponse.headers);

        if (prResponse.statusCode != 200) {
          throw GithubApiException(prResponse.statusCode, prResponse.body);
        }

        final prData = jsonDecode(prResponse.body);
        final headSha = prData['head']['sha'];

        if (headSha == null) {
          return 'Unknown';
        }

        // 2. Get the check runs for that SHA
        final checksUrl = Uri.parse(
          'https://api.github.com/repos/$owner/$repo/commits/$headSha/check-runs',
        );
        final checksResponse = await http.get(
          checksUrl,
          headers: {
            'Authorization': 'token $_apiKey',
            'Accept': 'application/vnd.github.v3+json',
          },
        );
        _updateRateLimits(checksResponse.headers);

        if (checksResponse.statusCode != 200) {
          debugPrint(
            'Failed to get CI status for $owner/$repo #$prNumber, sha $headSha: ${checksResponse.statusCode} ${checksResponse.body}',
          );
          return 'Unknown';
        }

        final checksData = jsonDecode(checksResponse.body);
        final checkRuns = checksData['check_runs'] as List;

        if (checkRuns.isEmpty) {
          return 'No Checks';
        }

        // 3. Determine the overall status
        bool isPending = false;
        bool hasFailures = false;

        for (final run in checkRuns) {
          if (run['status'] != 'completed') {
            isPending = true;
            break; // If anything is pending, the whole thing is
          }
          if (run['conclusion'] == 'failure' ||
              run['conclusion'] == 'timed_out' ||
              run['conclusion'] == 'cancelled') {
            hasFailures = true;
          }
        }

        if (isPending) return 'Pending';
        if (hasFailures) return 'Failure';

        // If we get here, everything is completed and there are no failures
        return 'Success';
      },
    );

    _queue.add(job);
    _processQueue();
    notifyListeners();

    await job.completer.future;
    return job.result as String?;
  }

  Future<Map<String, dynamic>?> getRepoDetails(
    String owner,
    String repo,
  ) async {
    if (_apiKey == null) {
      return null;
    }

    final job = GithubJob(
      id: 'repo_details_${owner}_$repo',
      description: 'Get Repo Details: $owner/$repo',
      action: () async {
        final url = Uri.parse('https://api.github.com/repos/$owner/$repo');
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
          final license = data['license'];
          final parent = data['parent'];

          return {
            'repoName': data['name'],
            'repoId': data['id'],
            'isPrivateGithub': data['private'],
            'description': data['description'],
            'primaryLanguage': data['language'],
            'license': license != null ? license['name'] : null,
            'openIssuesCount': data['open_issues_count'],
            'isFork': data['fork'],
            'forkParent': parent != null ? parent['full_name'] : null,
          };
        } else {
          throw GithubApiException(response.statusCode, response.body);
        }
      },
    );

    _queue.add(job);
    _processQueue();
    notifyListeners();

    // Wait for job to complete
    await job.completer.future;
    return job.result as Map<String, dynamic>?;
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
        _rateLimitReset = DateTime.fromMillisecondsSinceEpoch(
          resetEpoch * 1000,
        );
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

      final job = _queue.firstWhere(
        (j) => j.status == GithubJobStatus.pending,
        orElse: () =>
            GithubJob(id: 'none', description: '', action: () async {})
              ..status = GithubJobStatus.completed,
      );

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

  GithubJob({
    required this.id,
    required this.description,
    required this.action,
  });
}

class GitHubPrResponse {
  final Map<String, dynamic> _data;

  GitHubPrResponse(this._data);

  bool get isMerged => getBooleanPropOrDefault(_data, 'merged', false);
  bool get isDraft => getBooleanPropOrDefault(_data, 'draft', false);
  String get state => getStringPropOrDefault(_data, 'state', '');
  String? get mergeableState =>
      getStringPropOrDefault(_data, 'mergeable_state', null);
  int? get additions =>
      getNumberPropOrDefault<num?>(_data, 'additions', null)?.toInt();
  int? get deletions =>
      getNumberPropOrDefault<num?>(_data, 'deletions', null)?.toInt();
  int? get changedFiles =>
      getNumberPropOrDefault<num?>(_data, 'changed_files', null)?.toInt();
  String? get diffUrl => getStringPropOrDefault(_data, 'diff_url', null);
  String? get patchUrl => getStringPropOrDefault(_data, 'patch_url', null);

  String get displayStatus {
    if (isMerged == true) return 'Merged';
    if (isDraft == true) return 'Draft';
    if (state == 'closed') return 'Closed';
    return 'Open';
  }
}
