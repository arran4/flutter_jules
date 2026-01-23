import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'package:dartobjectutils/dartobjectutils.dart';

import 'auth_service.dart';
import 'cache_service.dart';
import 'settings_provider.dart';
import '../models/github_exclusion.dart';

class GithubApiException implements Exception {
  final int statusCode;
  final String message;

  GithubApiException(this.statusCode, this.message);

  @override
  String toString() => 'GithubApiException: $statusCode $message';
}

enum AccessCheckResult { userOk, orgOk, repoOk, prOk, badCredentials }

class GithubProvider extends ChangeNotifier {
  final SettingsProvider _settingsProvider;
  final CacheService _cacheService;
  final AuthService _authService = AuthService();

  String? _githubToken;
  String? get apiKey => _githubToken;

  // Rate Limiting
  int? _rateLimitLimit;
  int? _rateLimitRemaining;
  DateTime? _rateLimitReset;

  // Stats
  int _errorCount = 0;
  int _warningCount = 0;
  Duration _totalThrottledDuration = Duration.zero;

  // Auth Status
  bool _hasBadCredentials = false;
  String? _authError;

  // Queue
  final List<GithubJob> _queue = [];
  bool _isProcessingQueue = false;

  int? get rateLimitLimit => _rateLimitLimit;
  int? get rateLimitRemaining => _rateLimitRemaining;
  DateTime? get rateLimitReset => _rateLimitReset;
  int get errorCount => _errorCount;
  int get warningCount => _warningCount;
  Duration get totalThrottledDuration => _totalThrottledDuration;
  List<GithubJob> get queue => List.unmodifiable(_queue);
  bool get hasBadCredentials => _hasBadCredentials;
  String? get authError => _authError;

  GithubProvider(this._settingsProvider, this._cacheService) {
    _loadToken();
  }

  Future<void> _loadToken() async {
    _githubToken = await _authService.getGithubToken();
    notifyListeners();
  }

  Future<String?> getToken() async => apiKey;

  Future<void> setApiKey(String key) async {
    await _authService.saveGithubToken(key);
    _githubToken = key;
    // Reset bad credentials state when key is updated
    _hasBadCredentials = false;
    _authError = null;
    notifyListeners();
    // Retry processing queue if it was stuck
    _processQueue();
  }

  Future<bool> _checkUserAccess() async {
    final token = apiKey;
    if (token == null) return false;
    final response = await http.get(
      Uri.parse('https://api.github.com/user'),
      headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
      },
    );
    return response.statusCode == 200;
  }

  Future<bool> _checkOrgAccess(String org) async {
    final token = apiKey;
    if (token == null) return false;
    // Cheap call to check org membership or existence
    // If user is not member of private org, this might fail with 404 or 403
    final response = await http.get(
      Uri.parse('https://api.github.com/orgs/$org'),
      headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
      },
    );

    if (response.statusCode == 200) return true;

    // Also check membership specifically if possible
    final membershipResponse = await http.get(
      Uri.parse('https://api.github.com/user/memberships/orgs/$org'),
      headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
      },
    );
    return membershipResponse.statusCode == 200;
  }

  Future<bool> _checkRepoAccess(String owner, String repo) async {
    final token = apiKey;
    if (token == null) return false;
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/$owner/$repo'),
      headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
      },
    );
    return response.statusCode == 200;
  }

  Future<void> _logFailure(String jobId, String message) async {
    try {
      final file = await _cacheService.getGithubFailuresLogFile(apiKey ?? '');
      final entry = '${DateTime.now().toIso8601String()} [$jobId] $message\n';
      await file.writeAsString(entry, mode: FileMode.append);
    } catch (e) {
      debugPrint('Failed to log failure: $e');
    }
  }

  Future<void> _analyzeFailure(
    String? owner,
    String? repo,
    String? prNumber,
    String? jobId,
  ) async {
    if (_hasBadCredentials) return;

    final userOk = await _checkUserAccess();
    if (!userOk) {
      await _handleUserFailure(owner);
      return;
    }

    if (owner == null) {
      return;
    }

    final orgOk = await _checkOrgAccess(owner);
    if (!orgOk) {
      await _handleOrgFailure(owner);
      return;
    }

    if (repo == null) {
      return;
    }

    final repoOk = await _checkRepoAccess(owner, repo);
    if (!repoOk) {
      await _handleRepoFailure(owner, repo);
      return;
    }

    if (prNumber == null) {
      return;
    }

    await _handlePrFailure(owner, repo, prNumber, jobId);
  }

  Future<AccessCheckResult> _handleUserFailure(String? owner) async {
    if (owner == null) {
      _markBadCredentials('Access check failed for User.');
      return AccessCheckResult.badCredentials;
    }

    final orgOk = await _checkOrgAccess(owner);
    if (!orgOk) {
      _markBadCredentials('Access check failed for User and Org ($owner).');
      return AccessCheckResult.badCredentials;
    }

    _markBadCredentials('Access check failed for User.');
    return AccessCheckResult.badCredentials;
  }

  Future<AccessCheckResult> _handleOrgFailure(String owner) async {
    await _settingsProvider.addGithubExclusion(GithubExclusion(
      type: GithubExclusionType.org,
      value: owner,
      reason: 'PAT access request failed for Org.',
      date: DateTime.now(),
    ));
    return AccessCheckResult.userOk;
  }

  Future<AccessCheckResult> _handleRepoFailure(String owner, String repo) async {
    await _settingsProvider.addGithubExclusion(GithubExclusion(
      type: GithubExclusionType.repo,
      value: '$owner/$repo',
      reason: 'PAT access request failed for Repo.',
      date: DateTime.now(),
    ));
    return AccessCheckResult.orgOk;
  }

  Future<AccessCheckResult> _handlePrFailure(
    String owner,
    String repo,
    String prNumber,
    String? jobId,
  ) async {
    await _settingsProvider.addGithubExclusion(GithubExclusion(
      type: GithubExclusionType.pullRequest,
      value: '$owner/$repo/$prNumber',
      reason: 'PAT access request failed for PR.',
      date: DateTime.now(),
    ));

    if (jobId != null) {
      await _logFailure(
        jobId,
        'GitHub Unauthorized/Error: 404 for PR $owner/$repo/$prNumber',
      );
    }

    return AccessCheckResult.repoOk;
  }

  void _markBadCredentials(String reason) {
    if (_hasBadCredentials) return;
    _hasBadCredentials = true;
    _authError = reason;
    _cancelAllPendingJobs();
    notifyListeners();
  }

  Future<Map<String, dynamic>?> validateToken(String token) async {
    final response = await http.get(
      Uri.parse('https://api.github.com/user'),
      headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<void> _handleUnauthorized(
    String body, {
    String? owner,
    String? repo,
    String? prNumber,
    String? jobId,
  }) async {
    // Start analysis to determine granularity of failure
    await _analyzeFailure(owner, repo, prNumber, jobId);
  }

  void _cancelAllPendingJobs() {
    // Iterate backwards or on a copy to modify safely if needed,
    // though we are clearing.
    for (final job in _queue) {
      if (job.status == GithubJobStatus.pending) {
        job.status = GithubJobStatus.failed; // or canceled
        job.result = null; // Return null so waiters don't crash
        job.error = 'Bad credentials';
        if (!job.completer.isCompleted) {
          job.completer.complete();
        }
      }
    }
    _queue.removeWhere((job) => job.status == GithubJobStatus.failed);
  }

  Future<GitHubPrResponse?> getPrStatus(
    String owner,
    String repo,
    String prNumber,
  ) async {
    if (apiKey == null) {
      return null;
    }
    if (_hasBadCredentials) {
      return null;
    }
    if (_settingsProvider.isExcluded('$owner/$repo')) return null;

    final job = GithubJob(
      id: 'pr_status_${owner}_${repo}_$prNumber',
      description: 'Check PR Status: $owner/$repo #$prNumber',
      action: () async {
        if (_hasBadCredentials) return null;

        final url = Uri.parse(
          'https://api.github.com/repos/$owner/$repo/pulls/$prNumber',
        );
        final response = await http.get(
          url,
          headers: {
            'Authorization': 'token $apiKey',
            'Accept': 'application/vnd.github.v3+json',
          },
        );

        _updateRateLimits(response.headers);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return GitHubPrResponse(data);
        } else if (response.statusCode == 401 ||
            response.statusCode == 403 ||
            response.statusCode == 404) {
          _warningCount++;
          // 404 on private repo acts like auth failure often
          await _handleUnauthorized(
            response.body,
            owner: owner,
            repo: repo,
            prNumber: prNumber,
            jobId: job.id,
          );
          debugPrint(
              'GitHub Unauthorized/Error: ${response.statusCode} ${response.body}');
          return null;
        } else {
          _warningCount++;
          debugPrint(
            'Failed to get PR status for $owner/$repo #$prNumber: ${response.statusCode} ${response.body}',
          );
          return null;
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
    if (apiKey == null || _hasBadCredentials) return null;
    final url = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/pulls/$prNumber',
    );
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'token $apiKey',
        'Accept': 'application/vnd.github.v3.diff',
      },
    );
    _updateRateLimits(response.headers);
    if (response.statusCode == 200) {
      return response.body;
    } else if (response.statusCode == 401 ||
        response.statusCode == 403 ||
        response.statusCode == 404) {
      _warningCount++;
      await _handleUnauthorized(
        response.body,
        owner: owner,
        repo: repo,
        prNumber: prNumber,
        jobId: 'diff_${owner}_${repo}_$prNumber',
      );
    } else {
      _warningCount++;
    }
    return null;
  }

  Future<String?> getPatch(String owner, String repo, String prNumber) async {
    if (apiKey == null || _hasBadCredentials) return null;
    final url = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/pulls/$prNumber',
    );
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'token $apiKey',
        'Accept': 'application/vnd.github.v3.patch',
      },
    );
    _updateRateLimits(response.headers);
    if (response.statusCode == 200) {
      return response.body;
    } else if (response.statusCode == 401 ||
        response.statusCode == 403 ||
        response.statusCode == 404) {
      _warningCount++;
      await _handleUnauthorized(
        response.body,
        owner: owner,
        repo: repo,
        prNumber: prNumber,
        jobId: 'patch_${owner}_${repo}_$prNumber',
      );
    } else {
      _warningCount++;
    }
    return null;
  }

  Future<String?> getCIStatus(
    String owner,
    String repo,
    String prNumber,
  ) async {
    if (apiKey == null) return null;
    if (_hasBadCredentials) return 'Unknown';

    final job = GithubJob(
      id: 'ci_status_${owner}_${repo}_$prNumber',
      description: 'Check CI Status: $owner/$repo #$prNumber',
      action: () async {
        if (_settingsProvider.isExcluded('$owner/$repo')) return 'Unknown';
        if (_hasBadCredentials) return 'Unknown';

        // 1. Get the PR's head SHA
        final prUrl = Uri.parse(
          'https://api.github.com/repos/$owner/$repo/pulls/$prNumber',
        );
        final prResponse = await http.get(
          prUrl,
          headers: {
            'Authorization': 'token $apiKey',
            'Accept': 'application/vnd.github.v3+json',
          },
        );
        _updateRateLimits(prResponse.headers);

        if (prResponse.statusCode == 401 ||
            prResponse.statusCode == 403 ||
            prResponse.statusCode == 404) {
          _warningCount++;
          await _handleUnauthorized(
            prResponse.body,
            owner: owner,
            repo: repo,
            prNumber: prNumber,
            jobId: job.id,
          );
          return 'Unknown';
        }

        if (prResponse.statusCode != 200) {
          throw GithubApiException(prResponse.statusCode, prResponse.body);
        }

        final prData = jsonDecode(prResponse.body);
        final headSha = prData['head']['sha'];

        if (headSha == null) {
          _warningCount++;
          return 'Unknown';
        }

        // 2. Get the check runs for that SHA
        final checksUrl = Uri.parse(
          'https://api.github.com/repos/$owner/$repo/commits/$headSha/check-runs',
        );
        final checksResponse = await http.get(
          checksUrl,
          headers: {
            'Authorization': 'token $apiKey',
            'Accept': 'application/vnd.github.v3+json',
          },
        );
        _updateRateLimits(checksResponse.headers);

        if (checksResponse.statusCode == 401 ||
            checksResponse.statusCode == 403 ||
            checksResponse.statusCode == 404) {
          _warningCount++;
          await _handleUnauthorized(
            checksResponse.body,
            owner: owner,
            repo: repo,
            prNumber: prNumber,
            jobId: job.id,
          );
          return 'Unknown';
        }

        if (checksResponse.statusCode != 200) {
          _warningCount++;
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
    if (apiKey == null) {
      return null;
    }
    if (_hasBadCredentials) return null;

    final job = createRepoDetailsJob(owner, repo);
    if (_settingsProvider.isExcluded('$owner/$repo')) return null;

    enqueue(job);
    await job.completer.future;
    return job.result as Map<String, dynamic>?;
  }

  GithubJob createRepoDetailsJob(String owner, String repo) {
    return GithubJob(
      id: 'repo_details_${owner}_$repo',
      description: 'Get Repo Details: $owner/$repo',
      action: () async {
        if (_hasBadCredentials) throw Exception('Bad credentials');

        final url = Uri.parse('https://api.github.com/repos/$owner/$repo');
        final response = await http.get(
          url,
          headers: {
            'Authorization': 'token $apiKey',
            'Accept': 'application/vnd.github.v3+json',
          },
        );

        _updateRateLimits(response.headers);

        if (response.statusCode == 401 ||
            response.statusCode == 403 ||
            response.statusCode == 404) {
          await _handleUnauthorized(response.body, owner: owner, repo: repo);
          throw GithubApiException(response.statusCode, response.body);
        }

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
            'html_url': data['html_url'],
          };
        } else {
          throw GithubApiException(response.statusCode, response.body);
        }
      },
    );
  }

  void enqueue(GithubJob job) {
    if (_hasBadCredentials) return; // Don't enqueue if auth is bad

    // Avoid adding duplicate jobs
    if (_queue.any((j) => j.id == job.id)) {
      return;
    }
    _queue.add(job);
    _processQueue();
    notifyListeners();
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
    if (_hasBadCredentials) return; // Stop processing

    _isProcessingQueue = true;

    while (_queue.isNotEmpty) {
      // Check auth again in case it changed while processing
      if (_hasBadCredentials) {
        break;
      }

      // Check Rate Limits
      if (_rateLimitRemaining != null && _rateLimitRemaining! <= 0) {
        if (_rateLimitReset != null &&
            _rateLimitReset!.isAfter(DateTime.now())) {
          final wait = _rateLimitReset!.difference(DateTime.now());
          // Notify listeners so UI updates status to "Waiting"
          _totalThrottledDuration += wait;
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
        _errorCount++;
        // If the job action threw an exception because of 401, we want to capture that
        if (e.toString().contains('Bad credentials') || _hasBadCredentials) {
          job.status = GithubJobStatus.failed;
          job.error = 'Bad credentials';
          job.completer.completeError(e);
          break; // Stop queue processing
        }

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
  final Map<String, dynamic> _links;

  GitHubPrResponse(this._data)
      : _links = _data['_links'] as Map<String, dynamic>? ?? {};

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
  String? get htmlUrl =>
      (_links['html'] as Map<String, dynamic>?)?['href'] as String?;
  String? get statusesUrl =>
      (_links['statuses'] as Map<String, dynamic>?)?['href'] as String?;
  String? get commentsUrl =>
      (_links['comments'] as Map<String, dynamic>?)?['href'] as String?;
  String? get reviewCommentsUrl =>
      (_links['review_comments'] as Map<String, dynamic>?)?['href'] as String?;
  String? get headSha =>
      (_data['head'] as Map<String, dynamic>?)?['sha'] as String?;

  String get displayStatus {
    if (isMerged == true) return 'Merged';
    if (isDraft == true) return 'Draft';
    if (state == 'closed') return 'Closed';
    return 'Open';
  }
}
