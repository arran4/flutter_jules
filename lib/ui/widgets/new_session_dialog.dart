// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_provider.dart';
import '../../services/github_provider.dart';
import '../../services/session_provider.dart';
import '../../services/source_provider.dart';

import '../../services/settings_provider.dart';
import '../../services/message_queue_provider.dart';
import '../../models.dart';
import 'bulk_source_selector_dialog.dart';
// import '../../models/cache_metadata.dart'; // Not strictly needed here if we extract data

enum SessionDialogMode { create, createWithContext, edit }

class BulkSelection {
  final Source source;
  String branch;

  BulkSelection({required this.source, required this.branch});
}

class NewSessionDialog extends StatefulWidget {
  final String? sourceFilter;
  final Session? initialSession;
  final SessionDialogMode mode;

  const NewSessionDialog({
    super.key,
    this.sourceFilter,
    this.initialSession,
    this.mode = SessionDialogMode.create,
  });

  @override
  State<NewSessionDialog> createState() => _NewSessionDialogState();
}

// A result class for the NewSessionDialog.
class NewSessionResult {
  final List<Session> sessions;
  final bool isDraft;
  final bool isDelete;
  final bool openNewDialog;

  // Constructor for backward compatibility logic (single session)
  NewSessionResult(
    Session session, {
    this.isDraft = false,
    this.isDelete = false,
    this.openNewDialog = false,
  }) : sessions = [session];

  // Constructor for multiple sessions
  NewSessionResult.multiple(
    this.sessions, {
    this.isDraft = false,
    this.isDelete = false,
    this.openNewDialog = false,
  });

  // Helper to get the first session for backward compatibility
  Session get session => sessions.first;
}

class _NewSessionDialogState extends State<NewSessionDialog> {
  // Form State
  late final TextEditingController _promptController;
  Source? _selectedSource;
  String? _selectedBranch;
  late final TextEditingController _imageUrlController;

  // Bulk Selection State
  List<BulkSelection> _bulkSelections = [];

  // Task Mode
  // Options: Question (No Plan), Plan (Verify Plan), Start (Auto)
  int _selectedModeIndex = 0; // 0: Question, 1: Plan, 2: Start

  // Automation Option
  bool _autoCreatePr = true;

  // Refresh State
  bool _isRefreshing = false;
  String _refreshStatus = '';

  // Custom Dropdown State
  final TextEditingController _sourceController = TextEditingController();
  late final FocusNode _sourceFocusNode;
  final LayerLink _sourceLayerLink = LayerLink();
  OverlayEntry? _sourceOverlayEntry;
  List<Source> _filteredSources = [];
  int _highlightedSourceIndex = 0;
  // Size of the text field to match overlay
  double? _dropdownWidth;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController();
    _imageUrlController = TextEditingController();

    if (widget.mode == SessionDialogMode.edit &&
        widget.initialSession != null) {
      _promptController.text = widget.initialSession!.prompt;
    }

    if (widget.initialSession != null) {
      // Initialize other fields based on initialSession logic
      final mode = widget.initialSession!.automationMode ??
          AutomationMode.AUTOMATION_MODE_UNSPECIFIED;
      final requireApproval =
          widget.initialSession!.requirePlanApproval ?? false;

      if (mode == AutomationMode.AUTO_CREATE_PR) {
        _selectedModeIndex = 2; // Start
        _autoCreatePr = true;
      } else if (requireApproval) {
        _selectedModeIndex = 1; // Plan
      } else {
        _selectedModeIndex = 0; // Question (default)
      }
    }
    _sourceFocusNode = FocusNode(onKeyEvent: _handleSourceFocusKey);
    _sourceFocusNode.addListener(() {
      if (!_sourceFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_sourceFocusNode.hasFocus) {
            _removeSourceOverlay();
            // Reset text to selected source if valid
            if (_selectedSource != null) {
              _sourceController.text = _getSourceDisplayLabel(_selectedSource!);
            } else {
              _sourceController.clear();
            }
          }
        });
      }
    });
    // _sourceController.addListener(_onSourceTextChanged); // We'll call explicit filter update from onChanged to avoid loops

    _loadPreferences();
    // Defer data fetching to after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSources();
    });
  }

  @override
  void dispose() {
    _removeSourceOverlay();
    _sourceController.dispose();
    _sourceFocusNode.dispose();
    _promptController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  KeyEventResult _handleSourceFocusKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (_sourceOverlayEntry != null && _filteredSources.isNotEmpty) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _highlightedSourceIndex =
              (_highlightedSourceIndex + 1) % _filteredSources.length;
          _showSourceOverlay();
        });
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _highlightedSourceIndex =
              (_highlightedSourceIndex - 1 + _filteredSources.length) %
                  _filteredSources.length;
          _showSourceOverlay();
        });
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.tab) {
        if (_filteredSources.isNotEmpty) {
          _selectSource(_filteredSources[_highlightedSourceIndex]);
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _loadPreferences() async {
    if (widget.initialSession != null) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _selectedModeIndex = prefs.getInt('new_session_last_mode') ?? 0;
      _autoCreatePr = prefs.getBool('new_session_last_auto_pr') ?? true;
      // Sources and branches are handled in _initializeSelection after sources are loaded
    });
  }

  Future<void> _fetchSources({bool force = false}) async {
    if (_isRefreshing) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);
    final sessionProvider = Provider.of<SessionProvider>(
      context,
      listen: false,
    );
    final githubProvider = Provider.of<GithubProvider>(context, listen: false);

    // Only show loading state on explicit user action
    if (force) {
      setState(() {
        _isRefreshing = true;
        _refreshStatus = 'Refreshing...';
      });
    }

    try {
      if (force || sourceProvider.items.isEmpty) {
        await sourceProvider.fetchSources(
          auth.client,
          authToken: auth.token,
          force: force,
          githubProvider: githubProvider,
          sessionProvider: sessionProvider,
          onProgress: (page) {
            if (mounted) {
              setState(() {
                _refreshStatus = 'Loading page $page...';
              });
            }
          },
        );
      }

      if (mounted) {
        final settingsProvider =
            Provider.of<SettingsProvider>(context, listen: false);
        var sources = sourceProvider.items.map((i) => i.data).toList();
        if (settingsProvider.hideArchivedAndReadOnly) {
          sources =
              sources.where((s) => !s.isArchived && !s.isReadOnly).toList();
        }
        _initializeSelection(sources);
        if (force) {
          setState(() {
            _refreshStatus = 'Updated just now';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _refreshStatus = 'Error: ${e.toString().substring(0, 30)}...';
        });
      }
    } finally {
      if (mounted && force) {
        setState(() {
          _isRefreshing = false;
        });
        // Reset status after a few seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && !_isRefreshing) {
            final lastFetchTime = sourceProvider.lastFetchTime;
            setState(() {
              _refreshStatus = lastFetchTime != null
                  ? 'Last updated: ${DateFormat.Hms().format(lastFetchTime)}'
                  : '';
            });
          }
        });
      } else if (mounted) {
        final lastFetchTime = sourceProvider.lastFetchTime;
        setState(() {
          _refreshStatus = lastFetchTime != null
              ? 'Last updated: ${DateFormat.Hms().format(lastFetchTime)}'
              : '';
        });
      }
    }
  }

  Future<void> _initializeSelection(List<Source> sources) async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      // Priority 1: Filter provided by widget (e.g. from context)
      if (widget.sourceFilter != null) {
        try {
          _selectedSource = sources.firstWhere(
            (s) => s.name == widget.sourceFilter,
          );
        } catch (e) {
          // print('Source filter ${widget.sourceFilter} not found in list');
        }
      }

      // Priority 1.5: Draft value
      if (_selectedSource == null &&
          widget.initialSession?.sourceContext != null) {
        try {
          _selectedSource = sources.firstWhere(
            (s) => s.name == widget.initialSession!.sourceContext!.source,
          );
        } catch (_) {}
      }

      // Priority 2: Already selected source (if re-fetching)
      if (_selectedSource != null) {
        try {
          _selectedSource = sources.firstWhere(
            (s) => s.name == _selectedSource!.name,
          );
        } catch (_) {
          _selectedSource = null;
        }
      }

      // Priority 3: Last used source from prefs
      if (_selectedSource == null) {
        final lastSource = prefs.getString('new_session_last_source');
        if (lastSource != null) {
          try {
            _selectedSource = sources.firstWhere((s) => s.name == lastSource);
          } catch (_) {}
        }
      }

      // Priority 4: 'sources/default' or first available
      if (_selectedSource == null && sources.isNotEmpty) {
        try {
          _selectedSource = sources.firstWhere(
            (s) => s.name == 'sources/default',
          );
        } catch (_) {
          _selectedSource = sources.first;
        }
      }

      // Update Controller
      if (_selectedSource != null) {
        _sourceController.text = _getSourceDisplayLabel(_selectedSource!);
      }

      // Validated selection
      if (_selectedSource != null &&
          widget.initialSession?.sourceContext != null) {
        // Try to match branch from draft
        if (widget.initialSession!.sourceContext!.githubRepoContext != null) {
          _selectedBranch = widget
              .initialSession!.sourceContext!.githubRepoContext!.startingBranch;
        }
      } else {
        // Set default branch
        _updateBranchFromSource(prefs: prefs);
      }
    });
  }

  void _onSourceTextChanged(String val) {
    // if (!_sourceFocusNode.hasFocus) return; // Allow even if not strict focus for now?

    final query = val.toLowerCase();
    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);

    List<Source> allSources = sourceProvider.items.map((i) => i.data).toList();
    if (settingsProvider.hideArchivedAndReadOnly) {
      allSources =
          allSources.where((s) => !s.isArchived && !s.isReadOnly).toList();
    }
    allSources.sort((a, b) {
      final labelA = _getSourceDisplayLabel(a);
      final labelB = _getSourceDisplayLabel(b);
      final isSourceA =
          labelA.startsWith('sources/') || a.name.startsWith('sources/');
      final isSourceB =
          labelB.startsWith('sources/') || b.name.startsWith('sources/');
      if (isSourceA != isSourceB) return isSourceA ? 1 : -1;
      return labelA.compareTo(labelB);
    });

    setState(() {
      _filteredSources = allSources.where((s) {
        final label = _getSourceDisplayLabel(s).toLowerCase();
        return label.contains(query);
      }).toList();
      _highlightedSourceIndex = 0;
    });

    if (_filteredSources.isNotEmpty) {
      _showSourceOverlay();
    } else {
      _removeSourceOverlay();
    }
  }

  void _showSourceOverlay() {
    if (_sourceOverlayEntry != null) {
      _sourceOverlayEntry!.markNeedsBuild();
      return;
    }

    _sourceOverlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: _dropdownWidth ?? 300,
          child: CompositedTransformFollower(
            link: _sourceLayerLink,
            showWhenUnlinked: false,
            offset: const Offset(0.0, 60.0), // Approximate height
            child: Material(
              elevation: 4.0,
              color: Theme.of(context).cardColor,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _filteredSources.length,
                  itemBuilder: (context, index) {
                    final source = _filteredSources[index];
                    final isHighlighted = index == _highlightedSourceIndex;
                    final isPrivate = source.githubRepo?.isPrivate ?? false;

                    return Container(
                      color: isHighlighted
                          ? Theme.of(context).highlightColor
                          : null,
                      child: ListTile(
                        dense: true,
                        leading:
                            isPrivate ? const Icon(Icons.lock, size: 16) : null,
                        title: Text(_getSourceDisplayLabel(source)),
                        onTap: () => _selectSource(source),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    // Insert into overlay
    Overlay.of(context).insert(_sourceOverlayEntry!);
  }

  void _removeSourceOverlay() {
    _sourceOverlayEntry?.remove();
    _sourceOverlayEntry = null;
  }

  void _selectSource(Source source) {
    setState(() {
      _selectedSource = source;
      _sourceController.text = _getSourceDisplayLabel(source);
      _updateBranchFromSource();
    });
    _removeSourceOverlay();
    _sourceFocusNode.unfocus();
  }

  void _updateBranchFromSource({SharedPreferences? prefs}) {
    // If selected source is null, clear branch
    if (_selectedSource == null) {
      _selectedBranch = 'main';
      return;
    }

    final repo = _selectedSource!.githubRepo;
    if (repo == null) {
      _selectedBranch = 'main';
      return;
    }

    List<String> branches = [];
    if (repo.branches != null) {
      branches = repo.branches!.map((b) => b.displayName).toList();
    }

    // Try to restore last used branch for this source if available
    String? restoredBranch;
    if (prefs != null) {
      // We can store per-source branch or just global last branch.
      // Storing global last branch might be confusing if switching sources.
      // Let's store global for now as user typically works on one context.
      final lastBranch = prefs.getString('new_session_last_branch');
      if (lastBranch != null && branches.contains(lastBranch)) {
        restoredBranch = lastBranch;
      }
    }

    if (restoredBranch != null) {
      _selectedBranch = restoredBranch;
    } else if (repo.defaultBranch != null) {
      _selectedBranch = repo.defaultBranch!.displayName;
    } else if (branches.isNotEmpty) {
      _selectedBranch = branches.first;
    } else {
      _selectedBranch = 'main';
    }
  }

  Future<void> _showBulkDialog(List<Source> allSources) async {
    // Convert existing BulkSelection to simple Source list for the dialog
    List<Source> initialSelection =
        _bulkSelections.map((bs) => bs.source).toList();
    if (initialSelection.isEmpty && _selectedSource != null) {
      initialSelection.add(_selectedSource!);
    }

    final List<Source>? result = await showDialog<List<Source>>(
      context: context,
      builder: (context) => BulkSourceSelectorDialog(
        availableSources: allSources,
        initialSelectedSources: initialSelection,
      ),
    );

    if (result != null) {
      setState(() {
        if (result.length > 1) {
          // Bulk Mode
          final newSelections = result.map((source) {
            // Try to preserve existing branch selection if source was already in the list
            final existing = _bulkSelections.firstWhere(
              (bs) => bs.source.name == source.name,
              orElse: () => BulkSelection(
                source: source,
                branch: _getBranchLabelForSource(source),
              ),
            );
            return existing;
          }).toList();
          _bulkSelections = newSelections;
          _selectedSource = null;
          _sourceController.clear();
        } else if (result.length == 1) {
          // Single Mode
          _bulkSelections = [];
          _selectSource(result.first);
        } else {
          // Cleared
          _bulkSelections = [];
        }
      });
    }
  }

  Future<void> _create({bool openNewDialog = false}) async {
    // Handle Image
    final imageUrl = _imageUrlController.text.trim();
    List<Media>? images;
    if (imageUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          final base64Image = base64Encode(bytes);
          final mimeType = response.headers['content-type'] ?? 'image/png';

          images = [Media(data: base64Image, mimeType: mimeType)];
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load image: ${response.statusCode}'),
              ),
            );
            return;
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to load image: $e')));
          return;
        }
      }
    }

    // Map Mode to API fields
    bool requirePlanApproval = false;
    AutomationMode automationMode = AutomationMode.AUTOMATION_MODE_UNSPECIFIED;

    switch (_selectedModeIndex) {
      case 0: // Question
        requirePlanApproval = false;
        automationMode = AutomationMode.AUTOMATION_MODE_UNSPECIFIED;
        break;
      case 1: // Plan
        requirePlanApproval = true;
        automationMode = AutomationMode.AUTOMATION_MODE_UNSPECIFIED;
        break;
      case 2: // Start
        requirePlanApproval = false;
        automationMode = _autoCreatePr
            ? AutomationMode.AUTO_CREATE_PR
            : AutomationMode.AUTOMATION_MODE_UNSPECIFIED;
        break;
    }

    List<Session> sessionsToCreate = [];

    if (_bulkSelections.length > 1) {
      // Create session for each bulk selection
      for (final selection in _bulkSelections) {
        sessionsToCreate.add(
          Session(
            name: '',
            id: '',
            prompt: _promptController.text,
            sourceContext: SourceContext(
              source: selection.source.name,
              githubRepoContext:
                  GitHubRepoContext(startingBranch: selection.branch),
            ),
            requirePlanApproval: requirePlanApproval,
            automationMode: automationMode,
            images: images,
          ),
        );
      }

      // Only save preferences if this is not a "new session from" another
      if (widget.initialSession == null) {
        // Save prefs based on first or generic?
        // Maybe just save mode.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('new_session_last_mode', _selectedModeIndex);
        await prefs.setBool('new_session_last_auto_pr', _autoCreatePr);
      }
    } else {
      // Single Mode
      // Save preferences only if this is a fresh session
      if (widget.initialSession == null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('new_session_last_mode', _selectedModeIndex);
        if (_selectedSource != null) {
          await prefs.setString(
            'new_session_last_source',
            _selectedSource!.name,
          );
          if (_selectedBranch != null) {
            prefs.setString('new_session_last_branch', _selectedBranch!);
          }
        } else {
          await prefs.remove('new_session_last_source');
          await prefs.remove('new_session_last_branch');
        }
        await prefs.setBool('new_session_last_auto_pr', _autoCreatePr);
      }

      sessionsToCreate.add(
        Session(
          name: '', // Server assigns
          id: '', // Server assigns
          prompt: _promptController.text,
          sourceContext: _selectedSource == null
              ? null
              : SourceContext(
                  source: _selectedSource!.name,
                  githubRepoContext: GitHubRepoContext(
                    startingBranch: _selectedBranch ?? 'main',
                  ),
                ),
          requirePlanApproval: requirePlanApproval,
          automationMode: automationMode,
          images: images,
        ),
      );
    }

    if (mounted) {
      Navigator.pop(
        context,
        NewSessionResult.multiple(sessionsToCreate,
            isDraft: false, openNewDialog: openNewDialog),
      );
    }
  }

  Future<void> _saveDraft() async {
    if (_promptController.text.isEmpty) return;

    // Drafts are usually single. Bulk draft creation?
    // If in bulk mode, maybe create multiple drafts?
    // For now, let's assume drafts are single or just handle first?
    // User didn't specify bulk drafts. But consistency suggests bulk drafts.

    // Map Mode to API fields
    bool requirePlanApproval = false;
    AutomationMode automationMode = AutomationMode.AUTOMATION_MODE_UNSPECIFIED;

    switch (_selectedModeIndex) {
      case 1: // Plan
        requirePlanApproval = true;
        break;
      case 2: // Start
        automationMode = _autoCreatePr
            ? AutomationMode.AUTO_CREATE_PR
            : AutomationMode.AUTOMATION_MODE_UNSPECIFIED;
        break;
    }

    List<Session> sessionsToCreate = [];

    if (_bulkSelections.length > 1) {
      for (final selection in _bulkSelections) {
        sessionsToCreate.add(
          Session(
            name: '',
            id: '',
            prompt: _promptController.text,
            sourceContext: SourceContext(
              source: selection.source.name,
              githubRepoContext:
                  GitHubRepoContext(startingBranch: selection.branch),
            ),
            requirePlanApproval: requirePlanApproval,
            automationMode: automationMode,
          ),
        );
      }
    } else {
      sessionsToCreate.add(
        Session(
          name: widget.initialSession?.name ?? '',
          id: widget.initialSession?.id ?? '',
          prompt: _promptController.text,
          sourceContext: _selectedSource == null
              ? null
              : SourceContext(
                  source: _selectedSource!.name,
                  githubRepoContext: GitHubRepoContext(
                    startingBranch: _selectedBranch ?? 'main',
                  ),
                ),
          requirePlanApproval: requirePlanApproval,
          automationMode: automationMode,
        ),
      );
    }

    if (mounted) {
      Navigator.pop(
        context,
        NewSessionResult.multiple(sessionsToCreate, isDraft: true),
      );
    }
  }

  void _deleteDraft() {
    // Return dummy session but mark delete
    final dummy = Session(name: '', id: '', prompt: '', sourceContext: null);
    Navigator.pop(context, NewSessionResult(dummy, isDelete: true));
  }

  String _getSourceDisplayLabel(Source s) {
    if (s.githubRepo != null) {
      return '${s.githubRepo!.owner}/${s.githubRepo!.repo}';
    }
    return s.name;
  }

  String _getBranchLabelForSource(Source s) {
    if (s.githubRepo?.defaultBranch != null) {
      return s.githubRepo!.defaultBranch!.displayName;
    } else if (s.githubRepo?.branches != null &&
        s.githubRepo!.branches!.isNotEmpty) {
      return s.githubRepo!.branches!.first.displayName;
    }
    return 'main';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SourceProvider, SettingsProvider>(
      builder: (context, sourceProvider, settingsProvider, _) {
        var sources = sourceProvider.items.map((i) => i.data).toList();
        if (settingsProvider.hideArchivedAndReadOnly) {
          sources =
              sources.where((s) => !s.isArchived && !s.isReadOnly).toList();
        }

        // Sort sources
        sources.sort((a, b) {
          final labelA = _getSourceDisplayLabel(a);
          final labelB = _getSourceDisplayLabel(b);

          final isSourceA =
              labelA.startsWith('sources/') || a.name.startsWith('sources/');
          final isSourceB =
              labelB.startsWith('sources/') || b.name.startsWith('sources/');

          if (isSourceA != isSourceB) {
            // If one is source and the other is not, the one that IS 'source' goes last (return 1)
            return isSourceA ? 1 : -1;
          }

          return labelA.compareTo(labelB);
        });

        if (sourceProvider.isLoading && sources.isEmpty) {
          // Initial load
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Loading available sources..."),
              ],
            ),
          );
        }

        if (sourceProvider.error != null && sources.isEmpty) {
          return AlertDialog(
            title: const Text('Error'),
            content: SelectableText(sourceProvider.error!),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        }

        // Determine available branches for the selected source
        List<String> branches = [];
        if (_selectedSource != null &&
            _selectedSource!.githubRepo != null &&
            _selectedSource!.githubRepo!.branches != null) {
          branches = _selectedSource!.githubRepo!.branches!
              .map((b) => b.displayName)
              .toList();
        }
        if (_selectedBranch != null && !branches.contains(_selectedBranch)) {
          branches.add(_selectedBranch!);
        }
        if (branches.isEmpty) branches.add('main');

        return AlertDialog(
          title: Text(
            widget.mode == SessionDialogMode.edit
                ? "Pending Session"
                : "New Session",
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.initialSession != null &&
                    widget.initialSession!.state == SessionState.FAILED &&
                    widget.initialSession!.currentAction != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Last Send Failed: ${widget.initialSession!.currentAction}",
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Attempt to extract processingErrors from stashed metadata if available.
                        // Since 'images' field is List<Media>, we can't easily stow List<String> there.
                        // However, Session has a 'currentAction' which we already displayed.
                        // If we want detailed logs, they would need to be passed explicitly or
                        // retrieved from the queue now.
                        Consumer<MessageQueueProvider>(
                          builder: (context, queueProvider, _) {
                            // Find the queued message that corresponds to this session creation attempt
                            // This is heuristic: match by content/prompt if ID is empty/new_session
                            // OR rely on how the session was passed to us.
                            //
                            // Better: We look for ANY pending item in the queue that matches this content/prompt
                            // and has errors.
                            try {
                              final errorMsg = queueProvider.queue.firstWhere(
                                (m) =>
                                    m.type ==
                                        QueuedMessageType.sessionCreation &&
                                    m.content == widget.initialSession!.prompt &&
                                    m.processingErrors.isNotEmpty,
                              );

                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: errorMsg.processingErrors
                                      .map<Widget>(
                                        (e) => Text(
                                          "• $e",
                                          style: TextStyle(
                                            color: Colors.red.shade900,
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              );
                            } catch (_) {
                              // No matching detailed logs found in queue
                              return const SizedBox.shrink();
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                Text(
                  widget.mode == SessionDialogMode.edit
                      ? "Pending Session"
                      : "New Session",
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Mode Selection
                const Text(
                  'I want to...',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildModeChoice(0, 'Ask a Question'),
                    const SizedBox(width: 8),
                    _buildModeChoice(1, 'Create a Plan'),
                    const SizedBox(width: 8),
                    _buildModeChoice(2, 'Start Coding'),
                  ],
                ),
                const SizedBox(height: 16),

                if (_selectedModeIndex == 2) ...[
                  CheckboxListTile(
                    title: const Text('Auto-create Pull Request'),
                    subtitle: const Text(
                      'Automatically create a PR when a final patch is generated',
                    ),
                    value: _autoCreatePr,
                    onChanged: (val) {
                      setState(() {
                        _autoCreatePr = val ?? false;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 8),
                ],

                // Prompt
                CallbackShortcuts(
                  bindings: {
                    const SingleActivator(
                      LogicalKeyboardKey.enter,
                      control: true,
                    ): () {
                      if (_promptController.text.isNotEmpty &&
                          (_selectedSource != null ||
                              _bulkSelections.length > 1)) {
                        _create();
                      } else if (_promptController.text.isNotEmpty) {
                        _saveDraft();
                      }
                    },
                  },
                  child: TextField(
                    controller: _promptController,
                    autofocus: true,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: 'Prompt',
                      hintText: 'Describe what you want to do...',
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                      suffixIcon: (widget.mode == SessionDialogMode.edit ||
                              widget.mode ==
                                  SessionDialogMode.createWithContext)
                          ? IconButton(
                              icon: const Icon(Icons.content_paste_go),
                              tooltip: 'Import Prompt from Original Session',
                              onPressed: () {
                                if (widget.initialSession == null) return;
                                final originalPrompt =
                                    widget.initialSession!.prompt;
                                final currentText = _promptController.text;

                                if (currentText.trim().isNotEmpty) {
                                  const separator =
                                      '\n\n--- Imported Prompt ---\n';
                                  _promptController.text =
                                      '$currentText$separator$originalPrompt';
                                } else {
                                  _promptController.text = originalPrompt;
                                }
                                _promptController.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(
                                    offset: _promptController.text.length,
                                  ),
                                );
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 16),

                // Image Attachment (URL for now)
                TextField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL (Optional)',
                    hintText: 'https://example.com/image.png',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.image),
                  ),
                  onChanged: (val) => setState(() {}),
                ),
                const SizedBox(height: 16),

                // Context (Source & Branch)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Context',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        // Multi Button
                        IconButton(
                          icon: const Icon(Icons.library_add),
                          tooltip: 'Select Multiple Repositories',
                          onPressed: () => _showBulkDialog(sources),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            textStyle: const TextStyle(fontSize: 12),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _isRefreshing
                              ? null
                              : () => _fetchSources(force: true),
                          icon: _isRefreshing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh, size: 20),
                          label: Text(_refreshStatus),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_bulkSelections.length > 1) ...[
                  SizedBox(
                    height: 150, // Constrain height
                    child: ListView.builder(
                      itemCount: _bulkSelections.length,
                      itemBuilder: (context, index) {
                        final selection = _bulkSelections[index];
                        final source = selection.source;
                        final repo = source.githubRepo;
                        List<String> branches = repo?.branches
                                ?.map((b) => b.displayName)
                                .toList() ??
                            [];
                        if (!branches.contains(selection.branch)) {
                          branches.add(selection.branch);
                        }
                        if (branches.isEmpty) branches.add('main');

                        return ListTile(
                          dense: true,
                          leading: (repo?.isPrivate == true)
                              ? const Icon(Icons.lock, size: 16)
                              : null,
                          title: Text(_getSourceDisplayLabel(source)),
                          subtitle: Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Branch',
                                    border: OutlineInputBorder(),
                                  ),
                                  value: selection.branch,
                                  items: branches
                                      .map(
                                        (b) => DropdownMenuItem(
                                          value: b,
                                          child: Text(
                                            b,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        selection.branch = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () {
                                  setState(() {
                                    _bulkSelections.removeAt(index);
                                    if (_bulkSelections.length <= 1) {
                                      if (_bulkSelections.isNotEmpty) {
                                        _selectSource(
                                            _bulkSelections.first.source);
                                      } else {
                                        _selectedSource = null;
                                        _sourceController.clear();
                                      }
                                      _bulkSelections = [];
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ] else ...[
                  // Standard Single Selection
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Correctly capture width for overlay
                            _dropdownWidth = constraints.maxWidth;
                            return CompositedTransformTarget(
                              link: _sourceLayerLink,
                              child: TextField(
                                controller: _sourceController,
                                focusNode: _sourceFocusNode,
                                decoration: InputDecoration(
                                  labelText: 'Repository',
                                  border: const OutlineInputBorder(),
                                  prefixIcon:
                                      (_selectedSource?.githubRepo?.isPrivate ==
                                              true)
                                          ? const Icon(Icons.lock, size: 16)
                                          : const Icon(Icons.source, size: 16),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () {
                                      _sourceController.clear();
                                      _sourceFocusNode.requestFocus();
                                      _onSourceTextChanged('');
                                    },
                                  ),
                                ),
                                onChanged: _onSourceTextChanged,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Branch',
                            border: OutlineInputBorder(),
                          ),
                          value: _selectedBranch,
                          items: branches
                              .map(
                                (b) => DropdownMenuItem(
                                  value: b,
                                  child: Text(
                                    b,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedBranch = val;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.initialSession != null)
                      TextButton(
                        onPressed: _deleteDraft,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Delete'),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: (_promptController.text.isNotEmpty)
                          ? _saveDraft
                          : null,
                      child: const Text('Save as Draft'),
                    ),
                    const SizedBox(width: 8),
                    // Cancel acts as close without saving changes if not explicitly saving draft
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: (_promptController.text.isNotEmpty)
                          ? () => _create(openNewDialog: true)
                          : null,
                      child: const Text('Send & New'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: (_promptController.text.isNotEmpty)
                          ? () => _create(openNewDialog: false)
                          : null,
                      child: const Text('Send Now'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeChoice(int index, String label) {
    final isSelected = _selectedModeIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedModeIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
