// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart' hide ShortcutRegistry;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/shortcut_registry.dart';
import '../../utils/platform_utils.dart';
import '../../services/auth_provider.dart';
import '../../services/github_provider.dart';
import '../../services/source_provider.dart';
import '../../services/session_provider.dart';

import '../../services/settings_provider.dart';
import '../../services/message_queue_provider.dart';
import '../../services/prompt_template_provider.dart';
import '../../models.dart';
import 'bulk_source_selector_dialog.dart';
import 'prompt_template_selector_dialog.dart';
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
  List<SourceGroup> _filteredGroups = [];
  int _highlightedSourceIndex = 0;
  // Size of the text field to match overlay
  double? _dropdownWidth;

  // Focus Nodes
  late final FocusNode _promptFocusNode;
  late final FocusNode _branchFocusNode;

  // Shortcuts
  StreamSubscription<AppShortcutAction>? _actionSubscription;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController();
    _promptFocusNode = FocusNode();
    _branchFocusNode = FocusNode();

    if (widget.mode == SessionDialogMode.edit &&
        widget.initialSession != null) {
      _promptController.text = widget.initialSession!.prompt;
    }

    if (widget.initialSession != null) {
      // Initialize other fields based on initialSession logic
      final mode =
          widget.initialSession!.automationMode ??
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

    // Defer data fetching and async initialization to after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
      _fetchSources();
      _registerShortcuts();
    });
  }

  @override
  void dispose() {
    _unregisterShortcuts();
    _removeSourceOverlay();
    _sourceController.dispose();
    _sourceFocusNode.dispose();
    _promptController.dispose();
    _promptFocusNode.dispose();
    _branchFocusNode.dispose();
    super.dispose();
  }

  List<Shortcut> _activeShortcuts = [];

  void _registerShortcuts() {
    if (!mounted) return;
    final shortcutRegistry = Provider.of<ShortcutRegistry>(
      context,
      listen: false,
    );
    final isMacOS = PlatformUtils.isMacOS;

    _activeShortcuts = [
      Shortcut(
        SingleActivator(
          LogicalKeyboardKey.keyL,
          control: !isMacOS,
          meta: isMacOS,
        ),
        AppShortcutAction.focusContext,
        'Focus Context',
      ),
      Shortcut(
        SingleActivator(
          LogicalKeyboardKey.keyB,
          control: !isMacOS,
          meta: isMacOS,
        ),
        AppShortcutAction.focusBranch,
        'Focus Branch',
      ),
      Shortcut(
        SingleActivator(
          LogicalKeyboardKey.keyK,
          control: !isMacOS,
          meta: isMacOS,
        ),
        AppShortcutAction.focusPrompt,
        'Focus Prompt',
      ),
      Shortcut(
        SingleActivator(
          LogicalKeyboardKey.keyP,
          control: !isMacOS,
          meta: isMacOS,
        ),
        AppShortcutAction.focusPrompt,
        'Focus Prompt',
      ),
      Shortcut(
        const SingleActivator(LogicalKeyboardKey.keyQ, alt: true),
        AppShortcutAction.modeQuestion,
        'Switch to Question Mode',
      ),
      Shortcut(
        const SingleActivator(LogicalKeyboardKey.keyP, alt: true),
        AppShortcutAction.modePlan,
        'Switch to Plan Mode',
      ),
      Shortcut(
        const SingleActivator(LogicalKeyboardKey.keyC, alt: true),
        AppShortcutAction.modeStart,
        'Switch to Start Coding Mode',
      ),
      Shortcut(
        const SingleActivator(LogicalKeyboardKey.keyA, alt: true),
        AppShortcutAction.toggleAutoPr,
        'Toggle Auto PR',
      ),
    ];

    for (final s in _activeShortcuts) {
      shortcutRegistry.register(s);
    }

    _actionSubscription = shortcutRegistry.onAction.listen(
      _handleShortcutAction,
    );
  }

  void _unregisterShortcuts() {
    _actionSubscription?.cancel();
    try {
      final shortcutRegistry = Provider.of<ShortcutRegistry>(
        context,
        listen: false,
      );
      for (final s in _activeShortcuts) {
        shortcutRegistry.unregister(s);
      }
    } catch (_) {
      // Ignore if provider not found
    }
  }

  void _handleShortcutAction(AppShortcutAction action) {
    if (!mounted) return;
    switch (action) {
      case AppShortcutAction.focusContext:
        _sourceFocusNode.requestFocus();
        break;
      case AppShortcutAction.focusBranch:
        _branchFocusNode.requestFocus();
        break;
      case AppShortcutAction.focusPrompt:
        _promptFocusNode.requestFocus();
        break;
      case AppShortcutAction.modeQuestion:
        _handleModeSelection(0);
        break;
      case AppShortcutAction.modePlan:
        _handleModeSelection(1);
        break;
      case AppShortcutAction.modeStart:
        _handleModeSelection(2);
        break;
      case AppShortcutAction.toggleAutoPr:
        if (_selectedModeIndex == 2) {
          _handleAutoCreatePrChanged(!_autoCreatePr);
        }
        break;
      default:
        break;
    }
  }

  KeyEventResult _handleSourceFocusKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final totalCount = _filteredGroups.length + _filteredSources.length;
    if (!_shouldHandleSourceOverlay(totalCount)) {
      return KeyEventResult.ignored;
    }

    if (_isArrowKey(event.logicalKey)) {
      return _handleArrowKey(event.logicalKey, totalCount);
    }

    if (_isSubmitKey(event.logicalKey)) {
      return _handleSubmitKey();
    }
    return KeyEventResult.ignored;
  }

  Future<void> _initialize() async {
    // First, load the last-used preferences to set a baseline default.
    await _loadPreferences();

    // Then, if we are creating a new session from an existing one,
    // check if we can infer a more specific mode.
    _restoreModeFromSession();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _selectedModeIndex = prefs.getInt('new_session_last_mode') ?? 0;
      _autoCreatePr = prefs.getBool('new_session_last_auto_pr') ?? true;
    });
  }

  Future<void> _fetchSources({bool force = false}) async {
    if (_isRefreshing) return;

    final deps = _sourceFetchDependencies();

    // Only show loading state on explicit user action
    if (force) {
      _startRefresh();
    }

    try {
      await _fetchSourcesFromProvider(deps, force: force);
      if (mounted) {
        _applyLoadedSources(deps.sourceProvider, force: force);
      }
    } catch (e) {
      _handleSourceFetchError(e);
    } finally {
      await _finalizeRefreshState(deps.sourceProvider, force: force);
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
              .initialSession!
              .sourceContext!
              .githubRepoContext!
              .startingBranch;
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
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    List<Source> allSources = sourceProvider.items.map((i) => i.data).toList();
    if (settingsProvider.hideArchivedAndReadOnly) {
      allSources = allSources
          .where((s) => !s.isArchived && !s.isReadOnly)
          .toList();
    }
    _sortSources(allSources);

    setState(() {
      _filteredSources = allSources.where((s) {
        return _getSourceFilterLabel(s).contains(query);
      }).toList();

      if (query.isNotEmpty) {
        _filteredGroups = settingsProvider.sourceGroups.where((g) {
          return g.name.toLowerCase().contains(query);
        }).toList();
      } else {
        _filteredGroups = [];
      }

      _highlightedSourceIndex = 0;
    });

    if (_filteredSources.isNotEmpty || _filteredGroups.isNotEmpty) {
      _showSourceOverlay();
    } else {
      _removeSourceOverlay();
    }
  }

  bool _shouldHandleSourceOverlay(int totalCount) {
    return _sourceOverlayEntry != null && totalCount > 0;
  }

  bool _isArrowKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp;
  }

  bool _isSubmitKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.tab;
  }

  KeyEventResult _handleArrowKey(LogicalKeyboardKey key, int totalCount) {
    setState(() {
      if (key == LogicalKeyboardKey.arrowDown) {
        _highlightedSourceIndex = (_highlightedSourceIndex + 1) % totalCount;
      } else {
        _highlightedSourceIndex =
            (_highlightedSourceIndex - 1 + totalCount) % totalCount;
      }
      _showSourceOverlay();
    });
    return KeyEventResult.handled;
  }

  KeyEventResult _handleSubmitKey() {
    if (_highlightedSourceIndex < _filteredGroups.length) {
      _selectGroup(_filteredGroups[_highlightedSourceIndex]);
    } else {
      final sourceIndex = _highlightedSourceIndex - _filteredGroups.length;
      if (sourceIndex < _filteredSources.length) {
        _selectSource(_filteredSources[sourceIndex]);
      }
    }
    return KeyEventResult.handled;
  }

  _SourceFetchDependencies _sourceFetchDependencies() {
    return _SourceFetchDependencies(
      auth: Provider.of<AuthProvider>(context, listen: false),
      sourceProvider: Provider.of<SourceProvider>(context, listen: false),
      sessionProvider: Provider.of<SessionProvider>(context, listen: false),
      githubProvider: Provider.of<GithubProvider>(context, listen: false),
    );
  }

  void _startRefresh() {
    setState(() {
      _isRefreshing = true;
      _refreshStatus = 'Refreshing...';
    });
  }

  Future<void> _fetchSourcesFromProvider(
    _SourceFetchDependencies deps, {
    required bool force,
  }) async {
    if (!force && deps.sourceProvider.items.isNotEmpty) {
      return;
    }

    await deps.sourceProvider.fetchSources(
      deps.auth.client,
      authToken: deps.auth.token,
      force: force,
      githubProvider: deps.githubProvider,
      sessionProvider: deps.sessionProvider,
      onProgress: (count, message) {
        if (mounted) {
          setState(() {
            _refreshStatus = message;
          });
        }
      },
    );
  }

  void _applyLoadedSources(
    SourceProvider sourceProvider, {
    required bool force,
  }) {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    var sources = sourceProvider.items.map((i) => i.data).toList();
    if (settingsProvider.hideArchivedAndReadOnly) {
      sources = sources.where((s) => !s.isArchived && !s.isReadOnly).toList();
    }
    _initializeSelection(sources);
    if (force) {
      setState(() {
        _refreshStatus = 'Updated just now';
      });
    }
  }

  void _handleSourceFetchError(Object error) {
    if (!mounted) return;
    setState(() {
      _refreshStatus = 'Error: ${error.toString().substring(0, 30)}...';
    });
  }

  Future<void> _finalizeRefreshState(
    SourceProvider sourceProvider, {
    required bool force,
  }) async {
    if (!mounted) return;
    if (force) {
      setState(() {
        _isRefreshing = false;
      });
      await _resetRefreshStatusAfterDelay(sourceProvider);
    } else {
      _updateRefreshStatusFromLastFetch(sourceProvider);
    }
  }

  Future<void> _resetRefreshStatusAfterDelay(
    SourceProvider sourceProvider,
  ) async {
    // Reset status after a few seconds
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted || _isRefreshing) return;
    _updateRefreshStatusFromLastFetch(sourceProvider);
  }

  void _updateRefreshStatusFromLastFetch(SourceProvider sourceProvider) {
    final lastFetchTime = sourceProvider.lastFetchTime;
    setState(() {
      _refreshStatus = lastFetchTime != null
          ? 'Last updated: ${DateFormat.Hms().format(lastFetchTime)}'
          : '';
    });
  }

  void _restoreModeFromSession() {
    if (widget.initialSession == null) return;
    _promptController.text = widget.initialSession!.prompt;
    final mode =
        widget.initialSession!.automationMode ??
        AutomationMode.AUTOMATION_MODE_UNSPECIFIED;
    final requireApproval = widget.initialSession!.requirePlanApproval ?? false;

    // This logic will now correctly override the preference-loaded value.
    if (mode == AutomationMode.AUTO_CREATE_PR) {
      setState(() {
        _selectedModeIndex = 2; // Start
        _autoCreatePr = true;
      });
    } else if (requireApproval) {
      setState(() {
        _selectedModeIndex = 1; // Plan
      });
    }
  }

  void _handleModeSelection(int index) {
    setState(() {
      _selectedModeIndex = index;
    });
  }

  void _handleAutoCreatePrChanged(bool value) {
    setState(() {
      _autoCreatePr = value;
    });
  }

  void _handleBulkBranchChanged(int index, String branch) {
    setState(() {
      _bulkSelections[index].branch = branch;
    });
  }

  void _handleBulkRemove(int index) {
    setState(() {
      _bulkSelections.removeAt(index);
      if (_bulkSelections.length <= 1) {
        if (_bulkSelections.isNotEmpty) {
          _selectSource(_bulkSelections.first.source);
        } else {
          _selectedSource = null;
          _sourceController.clear();
        }
        _bulkSelections = [];
      }
    });
  }

  void _handleClearSourceField() {
    _sourceController.clear();
    _sourceFocusNode.requestFocus();
    _onSourceTextChanged('');
  }

  void _updateDropdownWidth(double width) {
    _dropdownWidth = width;
  }

  void _handleBranchSelection(String? branch) {
    setState(() {
      _selectedBranch = branch;
    });
  }

  // Overlay management helpers.
  void _showSourceOverlay() {
    if (_sourceOverlayEntry != null) {
      _sourceOverlayEntry!.markNeedsBuild();
      return;
    }

    _sourceOverlayEntry = OverlayEntry(builder: _buildSourceOverlay);

    // Insert into overlay
    Overlay.of(context).insert(_sourceOverlayEntry!);
  }

  void _removeSourceOverlay() {
    _sourceOverlayEntry?.remove();
    _sourceOverlayEntry = null;
  }

  Widget _buildSourceOverlay(BuildContext context) {
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
              itemCount: _filteredGroups.length + _filteredSources.length,
              itemBuilder: (context, index) =>
                  _buildSourceOverlayItem(context, index),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOverlayItem(BuildContext context, int index) {
    final isHighlighted = index == _highlightedSourceIndex;
    if (index < _filteredGroups.length) {
      final group = _filteredGroups[index];
      return _buildSourceGroupTile(context, group, isHighlighted);
    }
    final source = _filteredSources[index - _filteredGroups.length];
    return _buildSourceTile(context, source, isHighlighted);
  }

  Widget _buildSourceGroupTile(
    BuildContext context,
    SourceGroup group,
    bool isHighlighted,
  ) {
    return Container(
      color: isHighlighted ? Theme.of(context).highlightColor : null,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.group, size: 16),
        title: Text(group.name),
        subtitle: Text('${group.sourceNames.length} repositories'),
        onTap: () => _selectGroup(group),
      ),
    );
  }

  Widget _buildSourceTile(
    BuildContext context,
    Source source,
    bool isHighlighted,
  ) {
    final isPrivate = source.githubRepo?.isPrivate ?? false;
    return Container(
      color: isHighlighted ? Theme.of(context).highlightColor : null,
      child: ListTile(
        dense: true,
        leading: isPrivate ? const Icon(Icons.lock, size: 16) : null,
        title: Text(_getSourceDisplayLabel(source)),
        onTap: () => _selectSource(source),
      ),
    );
  }

  void _selectSource(Source source) {
    setState(() {
      _selectedSource = source;
      _sourceController.text = _getSourceDisplayLabel(source);
      _updateBranchFromSource();
    });
    _removeSourceOverlay();
    _sourceFocusNode.requestFocus();
  }

  void _selectGroup(SourceGroup group) {
    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);
    final allSources = sourceProvider.items.map((i) => i.data).toList();

    // Map group members to Source objects
    final sources = allSources
        .where((s) => group.sourceNames.contains(s.name))
        .toList();

    setState(() {
      _bulkSelections = sources
          .map(
            (s) =>
                BulkSelection(source: s, branch: _getBranchLabelForSource(s)),
          )
          .toList();

      _selectedSource = null;
      _sourceController.clear();
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
    List<Source> initialSelection = _bulkSelections
        .map((bs) => bs.source)
        .toList();
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
    // Save prompt to recent
    if (_promptController.text.isNotEmpty) {
      Provider.of<PromptTemplateProvider>(
        context,
        listen: false,
      ).addRecentPrompt(_promptController.text);
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
              githubRepoContext: GitHubRepoContext(
                startingBranch: selection.branch,
              ),
            ),
            requirePlanApproval: requirePlanApproval,
            automationMode: automationMode,
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
        ),
      );
    }

    if (mounted) {
      Navigator.pop(
        context,
        NewSessionResult.multiple(
          sessionsToCreate,
          isDraft: false,
          openNewDialog: openNewDialog,
        ),
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
              githubRepoContext: GitHubRepoContext(
                startingBranch: selection.branch,
              ),
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

  String _getSourceFilterLabel(Source s) {
    return _getSourceDisplayLabel(s).toLowerCase();
  }

  bool _isSourcesNamespace(Source s) {
    final label = _getSourceDisplayLabel(s);
    return label.startsWith('sources/') || s.name.startsWith('sources/');
  }

  int _compareSources(Source a, Source b) {
    final labelA = _getSourceDisplayLabel(a);
    final labelB = _getSourceDisplayLabel(b);
    final isSourceA = _isSourcesNamespace(a);
    final isSourceB = _isSourcesNamespace(b);
    if (isSourceA != isSourceB) return isSourceA ? 1 : -1;
    return labelA.compareTo(labelB);
  }

  void _sortSources(List<Source> sources) {
    sources.sort(_compareSources);
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

  void _handleSend() {
    if (_promptController.text.isNotEmpty &&
        (_selectedSource != null || _bulkSelections.length > 1)) {
      _create(openNewDialog: false);
    } else if (_promptController.text.isNotEmpty) {
      _saveDraft();
    }
  }

  void _handleSendAndNew() {
    if (_promptController.text.isNotEmpty &&
        (_selectedSource != null || _bulkSelections.length > 1)) {
      _create(openNewDialog: true);
    } else if (_promptController.text.isNotEmpty) {
      _saveDraft();
    }
  }

  Future<void> _openTemplateSelector() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const PromptTemplateSelectorDialog(),
    );

    if (!mounted) return;

    if (result != null && result.isNotEmpty) {
      setState(() {
        if (_promptController.text.isNotEmpty) {
          _promptController.text += '\n\n$result';
        } else {
          _promptController.text = result;
        }
        // Move cursor to end
        _promptController.selection = TextSelection.fromPosition(
          TextPosition(offset: _promptController.text.length),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SourceProvider, SettingsProvider>(
      builder: (context, sourceProvider, settingsProvider, _) {
        // Derive status display from provider state if not actively in the main fetch loop
        String displayStatus = _refreshStatus;
        if (!_isRefreshing && sourceProvider.pendingGithubRefreshes > 0) {
          displayStatus =
              'Updating GitHub details (${sourceProvider.pendingGithubRefreshes} remaining)...';
        }

        var sources = sourceProvider.items.map((i) => i.data).toList();
        if (settingsProvider.hideArchivedAndReadOnly) {
          sources = sources
              .where((s) => !s.isArchived && !s.isReadOnly)
              .toList();
        }

        // Sort sources
        _sortSources(sources);

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

        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            width: double.infinity,
            height: double.infinity,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Text(
                        widget.mode == SessionDialogMode.edit
                            ? "Pending Session"
                            : "New Session",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),

                // Body
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (widget.initialSession != null &&
                                  widget.initialSession!.state ==
                                      SessionState.FAILED &&
                                  widget.initialSession!.currentAction != null)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            color: Colors.red,
                                          ),
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
                                      Consumer<MessageQueueProvider>(
                                        builder: (context, queueProvider, _) {
                                          try {
                                            final errorMsg = queueProvider.queue
                                                .firstWhere(
                                                  (m) =>
                                                      m.type ==
                                                          QueuedMessageType
                                                              .sessionCreation &&
                                                      m.content ==
                                                          widget
                                                              .initialSession!
                                                              .prompt &&
                                                      m
                                                          .processingErrors
                                                          .isNotEmpty,
                                                );

                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8.0,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: errorMsg
                                                    .processingErrors
                                                    .map<Widget>(
                                                      (e) => Text(
                                                        "• $e",
                                                        style: TextStyle(
                                                          color: Colors
                                                              .red
                                                              .shade900,
                                                          fontSize: 11,
                                                          fontFamily:
                                                              'monospace',
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                            );
                                          } catch (_) {
                                            return const SizedBox.shrink();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                              // Mode Selection
                              _ModeSelectorSection(
                                selectedModeIndex: _selectedModeIndex,
                                autoCreatePr: _autoCreatePr,
                                onModeSelected: _handleModeSelection,
                                onAutoCreatePrChanged:
                                    _handleAutoCreatePrChanged,
                              ),

                              // Context (Source & Branch)
                              _SourceSelectorSection(
                                isRefreshing: _isRefreshing,
                                refreshStatus: displayStatus,
                                bulkSelections: _bulkSelections,
                                selectedSource: _selectedSource,
                                selectedBranch: _selectedBranch,
                                branches: branches,
                                sourceController: _sourceController,
                                sourceFocusNode: _sourceFocusNode,
                                branchFocusNode: _branchFocusNode,
                                sourceLayerLink: _sourceLayerLink,
                                onOpenBulkDialog: () =>
                                    _showBulkDialog(sources),
                                onRefresh: () => _fetchSources(force: true),
                                onBulkBranchChanged: _handleBulkBranchChanged,
                                onBulkRemove: _handleBulkRemove,
                                onSourceTextChanged: _onSourceTextChanged,
                                onClearSource: _handleClearSourceField,
                                onDropdownWidthChange: _updateDropdownWidth,
                                onBranchChanged: _handleBranchSelection,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Prompt
                              Expanded(
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 200,
                                  ),
                                  child: CallbackShortcuts(
                                    bindings: {
                                      const SingleActivator(
                                        LogicalKeyboardKey.enter,
                                        control: true,
                                      ): _handleSend,
                                      const SingleActivator(
                                        LogicalKeyboardKey.enter,
                                        meta: true,
                                      ): _handleSend,
                                      const SingleActivator(
                                        LogicalKeyboardKey.enter,
                                        control: true,
                                        shift: true,
                                      ): _handleSendAndNew,
                                      const SingleActivator(
                                        LogicalKeyboardKey.enter,
                                        meta: true,
                                        shift: true,
                                      ): _handleSendAndNew,
                                    },
                                    child: TextField(
                                      controller: _promptController,
                                      focusNode: _promptFocusNode,
                                      autofocus: true,
                                      expands: true,
                                      maxLines: null,
                                      minLines: null,
                                      textAlignVertical: TextAlignVertical.top,
                                      decoration: InputDecoration(
                                        labelText: 'Prompt',
                                        hintText:
                                            'Describe what you want to do...',
                                        border: const OutlineInputBorder(),
                                        alignLabelWithHint: true,
                                        suffixIcon:
                                            (widget.mode ==
                                                    SessionDialogMode.edit ||
                                                widget.mode ==
                                                    SessionDialogMode
                                                        .createWithContext)
                                            ? IconButton(
                                                icon: const Icon(
                                                  Icons.content_paste_go,
                                                ),
                                                tooltip:
                                                    'Import Prompt from Original Session',
                                                onPressed: () {
                                                  if (widget.initialSession ==
                                                      null) {
                                                    return;
                                                  }
                                                  final originalPrompt = widget
                                                      .initialSession!
                                                      .prompt;
                                                  final currentText =
                                                      _promptController.text;

                                                  if (currentText
                                                      .trim()
                                                      .isNotEmpty) {
                                                    const separator =
                                                        '\n\n--- Imported Prompt ---\n';
                                                    _promptController.text =
                                                        '$currentText$separator$originalPrompt';
                                                  } else {
                                                    _promptController.text =
                                                        originalPrompt;
                                                  }
                                                  _promptController.selection =
                                                      TextSelection.fromPosition(
                                                        TextPosition(
                                                          offset:
                                                              _promptController
                                                                  .text
                                                                  .length,
                                                        ),
                                                      );
                                                },
                                              )
                                            : null,
                                      ),
                                      onChanged: (val) => setState(() {}),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
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

                      IconButton(
                        onPressed: _openTemplateSelector,
                        icon: const Icon(Icons.description_outlined),
                        tooltip: 'Templates',
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SourceFetchDependencies {
  final AuthProvider auth;
  final SourceProvider sourceProvider;
  final SessionProvider sessionProvider;
  final GithubProvider githubProvider;

  const _SourceFetchDependencies({
    required this.auth,
    required this.sourceProvider,
    required this.sessionProvider,
    required this.githubProvider,
  });
}

class _ModeSelectorSection extends StatelessWidget {
  final int selectedModeIndex;
  final bool autoCreatePr;
  final ValueChanged<int> onModeSelected;
  final ValueChanged<bool> onAutoCreatePrChanged;

  const _ModeSelectorSection({
    required this.selectedModeIndex,
    required this.autoCreatePr,
    required this.onModeSelected,
    required this.onAutoCreatePrChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'I want to...',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _ModeChoice(
              index: 0,
              label: 'Ask a Question',
              isSelected: selectedModeIndex == 0,
              onSelected: onModeSelected,
            ),
            const SizedBox(width: 8),
            _ModeChoice(
              index: 1,
              label: 'Create a Plan',
              isSelected: selectedModeIndex == 1,
              onSelected: onModeSelected,
            ),
            const SizedBox(width: 8),
            _ModeChoice(
              index: 2,
              label: 'Start Coding',
              isSelected: selectedModeIndex == 2,
              onSelected: onModeSelected,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (selectedModeIndex == 2) ...[
          CheckboxListTile(
            title: const Text('Auto-create Pull Request'),
            subtitle: const Text(
              'Automatically create a PR when a final patch is generated',
            ),
            value: autoCreatePr,
            onChanged: (val) => onAutoCreatePrChanged(val ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ModeChoice extends StatelessWidget {
  final int index;
  final String label;
  final bool isSelected;
  final ValueChanged<int> onSelected;

  const _ModeChoice({
    required this.index,
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () => onSelected(index),
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

class _SourceSelectorSection extends StatelessWidget {
  final bool isRefreshing;
  final String refreshStatus;
  final List<BulkSelection> bulkSelections;
  final Source? selectedSource;
  final String? selectedBranch;
  final List<String> branches;
  final TextEditingController sourceController;
  final FocusNode sourceFocusNode;
  final FocusNode branchFocusNode;
  final LayerLink sourceLayerLink;
  final VoidCallback onOpenBulkDialog;
  final VoidCallback onRefresh;
  final void Function(int index, String branch) onBulkBranchChanged;
  final void Function(int index) onBulkRemove;
  final ValueChanged<String> onSourceTextChanged;
  final VoidCallback onClearSource;
  final ValueChanged<double> onDropdownWidthChange;
  final ValueChanged<String?> onBranchChanged;

  const _SourceSelectorSection({
    required this.isRefreshing,
    required this.refreshStatus,
    required this.bulkSelections,
    required this.selectedSource,
    required this.selectedBranch,
    required this.branches,
    required this.sourceController,
    required this.sourceFocusNode,
    required this.branchFocusNode,
    required this.sourceLayerLink,
    required this.onOpenBulkDialog,
    required this.onRefresh,
    required this.onBulkBranchChanged,
    required this.onBulkRemove,
    required this.onSourceTextChanged,
    required this.onClearSource,
    required this.onDropdownWidthChange,
    required this.onBranchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                IconButton(
                  icon: const Icon(Icons.library_add),
                  tooltip: 'Select Multiple Repositories',
                  onPressed: onOpenBulkDialog,
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    textStyle: const TextStyle(fontSize: 12),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: isRefreshing ? null : onRefresh,
                  icon: isRefreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 20),
                  label: Text(refreshStatus),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (bulkSelections.length > 1) ...[
          _BulkSelectionPanel(
            selections: bulkSelections,
            onBranchChanged: onBulkBranchChanged,
            onRemove: onBulkRemove,
          ),
        ] else ...[
          _SingleSourceSelector(
            sourceController: sourceController,
            sourceFocusNode: sourceFocusNode,
            branchFocusNode: branchFocusNode,
            sourceLayerLink: sourceLayerLink,
            selectedSource: selectedSource,
            selectedBranch: selectedBranch,
            branches: branches,
            onSourceTextChanged: onSourceTextChanged,
            onClearSource: onClearSource,
            onDropdownWidthChange: onDropdownWidthChange,
            onBranchChanged: onBranchChanged,
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _BulkSelectionPanel extends StatelessWidget {
  final List<BulkSelection> selections;
  final void Function(int index, String branch) onBranchChanged;
  final void Function(int index) onRemove;

  const _BulkSelectionPanel({
    required this.selections,
    required this.onBranchChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.builder(
        itemCount: selections.length,
        itemBuilder: (context, index) {
          final selection = selections[index];
          final source = selection.source;
          final repo = source.githubRepo;
          List<String> branches =
              repo?.branches?.map((b) => b.displayName).toList() ?? [];
          if (!branches.contains(selection.branch)) {
            branches.add(selection.branch);
          }
          if (branches.isEmpty) {
            branches.add('main');
          }

          return ListTile(
            dense: true,
            leading: (repo?.isPrivate == true)
                ? const Icon(Icons.lock, size: 16)
                : null,
            title: Text(
              source.githubRepo != null
                  ? '${source.githubRepo!.owner}/${source.githubRepo!.repo}'
                  : source.name,
            ),
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
                            child: Text(b, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        onBranchChanged(index, val);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => onRemove(index),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SingleSourceSelector extends StatelessWidget {
  final TextEditingController sourceController;
  final FocusNode sourceFocusNode;
  final FocusNode branchFocusNode;
  final LayerLink sourceLayerLink;
  final Source? selectedSource;
  final String? selectedBranch;
  final List<String> branches;
  final ValueChanged<String> onSourceTextChanged;
  final VoidCallback onClearSource;
  final ValueChanged<double> onDropdownWidthChange;
  final ValueChanged<String?> onBranchChanged;

  const _SingleSourceSelector({
    required this.sourceController,
    required this.sourceFocusNode,
    required this.branchFocusNode,
    required this.sourceLayerLink,
    required this.selectedSource,
    required this.selectedBranch,
    required this.branches,
    required this.onSourceTextChanged,
    required this.onClearSource,
    required this.onDropdownWidthChange,
    required this.onBranchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: LayoutBuilder(
            builder: (context, constraints) {
              onDropdownWidthChange(constraints.maxWidth);
              return CompositedTransformTarget(
                link: sourceLayerLink,
                child: TextField(
                  controller: sourceController,
                  focusNode: sourceFocusNode,
                  decoration: InputDecoration(
                    labelText: 'Repository',
                    border: const OutlineInputBorder(),
                    prefixIcon: (selectedSource?.githubRepo?.isPrivate == true)
                        ? const Icon(Icons.lock, size: 16)
                        : const Icon(Icons.source, size: 16),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: onClearSource,
                    ),
                  ),
                  onChanged: onSourceTextChanged,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 1,
          child: DropdownButtonFormField<String>(
            focusNode: branchFocusNode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Branch',
              border: OutlineInputBorder(),
            ),
            value: selectedBranch,
            items: branches
                .map(
                  (b) => DropdownMenuItem(
                    value: b,
                    child: Text(b, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: onBranchChanged,
          ),
        ),
      ],
    );
  }
}
