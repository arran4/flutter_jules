import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_provider.dart';
import '../../services/source_provider.dart';
import '../../models.dart';
// import '../../models/cache_metadata.dart'; // Not strictly needed here if we extract data

class NewSessionDialog extends StatefulWidget {
  final String? sourceFilter;

  const NewSessionDialog({super.key, this.sourceFilter});

  @override
  State<NewSessionDialog> createState() => _NewSessionDialogState();
}

class _NewSessionDialogState extends State<NewSessionDialog> {
  // Form State
  String _prompt = '';
  Source? _selectedSource;
  String? _selectedBranch;
  String _imageUrl = '';

  // Task Mode
  // Options: Question (No Plan), Plan (Verify Plan), Start (Auto)
  int _selectedModeIndex = 0; // 0: Question, 1: Plan, 2: Start

  // Automation Option
  bool _autoCreatePr = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    // Defer data fetching to after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSources();
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _selectedModeIndex = prefs.getInt('new_session_last_mode') ?? 0;
      _autoCreatePr = prefs.getBool('new_session_last_auto_pr') ?? false;
      // Sources and branches are handled in _initializeSelection after sources are loaded
    });
  }

  Future<void> _fetchSources({bool force = false}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);

    // If forcing or list is empty, fetch
    if (force || sourceProvider.items.isEmpty) {
       // Note: fetchSources acts as refresh if called again, or we might add force param to fetchSources
       // For now, calling it is enough.
       // Although I didn't add 'force' to fetchSources, it fetches if called fundamentally unless I added logic.
       // My implementation of fetchSources: skips if loading, but otherwise fetches.
       // And it loads from cache first.
       
       await sourceProvider.fetchSources(auth.client, authToken: auth.token);
    }
    
    // If we want to force network refresh, we might need a distinct method or param, 
    // but the user requirement was to load all on start. 
    // Usually cached data is fine for the dropdown unless the user explicitly refreshed in the main screen.
    // The previous code called `refresh`.
    
    // Since fetchSources currently respects cache if available and loaded, we might need to rely on the main screen refresh.
    // But for this dialog's "Refresh" button, we probably want to force a network hit.
    // My refactored fetchSources doesn't expose `force` logic cleanly (it checks cache).
    
    // Wait, my fetchSources executes:
    // 1. Load from cache (if token provided).
    // 2. Network call (do/while).
    // 3. Save to cache.
    // So it ALWAYS hits network! It's an eager fetch. Ideally it shouldn't be if data is fresh, but per instructions "pre download ... on first auth/login". 
    // But `SessionProvider` had logic to skip if fresh. `SourceProvider` refactor I wrote *always* fetches from network after loading cache.
    // Ideally I should have added a freshness check or `force` param.
    // But as written, it acts as a force refresh every time it's called unless `isLoading` is true.
    
    if (mounted) {
      final sources = sourceProvider.items.map((i) => i.data).toList();
      _initializeSelection(sources);
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

      // Priority 2: Already selected source (if re-fetching)
      if (_selectedSource != null) {
        try {
          _selectedSource =
              sources.firstWhere((s) => s.name == _selectedSource!.name);
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
          _selectedSource =
              sources.firstWhere((s) => s.name == 'sources/default');
        } catch (_) {
          _selectedSource = sources.first;
        }
      }

      // Set default branch
      _updateBranchFromSource(prefs: prefs);
    });
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

  Future<void> _create() async {
    if (_selectedSource == null) return;

    // Save preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('new_session_last_mode', _selectedModeIndex);
    await prefs.setString('new_session_last_source', _selectedSource!.name);
    if (_selectedBranch != null) {
      prefs.setString('new_session_last_branch', _selectedBranch!);
    }
    await prefs.setBool('new_session_last_auto_pr', _autoCreatePr);

    // Handle Image
    List<Media>? images;
    if (_imageUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(_imageUrl));
        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          final base64Image = base64Encode(bytes);
          final mimeType = response.headers['content-type'] ?? 'image/png';

          images = [Media(data: base64Image, mimeType: mimeType)];
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Failed to load image: ${response.statusCode}')));
            return;
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to load image: $e')));
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

    final newSession = Session(
      name: '', // Server assigns
      id: '', // Server assigns
      prompt: _prompt,
      sourceContext: SourceContext(
        source: _selectedSource!.name,
        githubRepoContext: GitHubRepoContext(
          startingBranch: _selectedBranch ?? 'main',
        ),
      ),
      requirePlanApproval: requirePlanApproval,
      automationMode: automationMode,
      images: images,
    );

    if (mounted) {
      Navigator.pop(context, newSession);
    }
  }

  String _getSourceDisplayLabel(Source s) {
    if (s.githubRepo != null) {
      return '${s.githubRepo!.owner}/${s.githubRepo!.repo}';
    }
    return s.name;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SourceProvider>(builder: (context, sourceProvider, _) {
      final sources = sourceProvider.items.map((i) => i.data).toList();
      
      // Sort sources
      sources.sort((a, b) {
        final labelA = _getSourceDisplayLabel(a);
        final labelB = _getSourceDisplayLabel(b);
        
        final isSourceA = labelA.startsWith('sources/') || a.name.startsWith('sources/');
        final isSourceB = labelB.startsWith('sources/') || b.name.startsWith('sources/');
        
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
            )
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text('New Session',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 16),
                  
                  // Mode Selection
                  const Text('I want to...',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
                        subtitle: const Text('Automatically create a PR when a final patch is generated'),
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
                  TextField(
                    autofocus: true,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Prompt',
                      hintText: 'Describe what you want to do...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _prompt = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
    
                  // Image Attachment (URL for now)
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Image URL (Optional)',
                      hintText: 'https://example.com/image.png',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.image),
                    ),
                    onChanged: (val) => _imageUrl = val,
                  ),
                  const SizedBox(height: 16),
    
                  // Context (Source & Branch)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Context',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      if (sourceProvider.isLoading)
                        const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 16),
                          tooltip: 'Refresh Sources',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _fetchSources(force: true),
                        )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return DropdownMenu<Source>(
                              width: constraints.maxWidth,
                              initialSelection: _selectedSource,
                              label: const Text('Repository'),
                              requestFocusOnTap: true,
                              enableFilter: true,
                              leadingIcon: (_selectedSource?.githubRepo?.isPrivate == true) 
                                  ? const Icon(Icons.lock, size: 16) 
                                  : null,
                              dropdownMenuEntries: sources.map((s) {
                                final isPrivate = s.githubRepo?.isPrivate ?? false;
                                return DropdownMenuEntry<Source>(
                                  value: s,
                                  label: _getSourceDisplayLabel(s),
                                  leadingIcon: isPrivate ? const Icon(Icons.lock, size: 16) : null,
                                );
                              }).toList(),
                              onSelected: (widget.sourceFilter != null)
                                  ? null
                                  : (Source? newValue) {
                                      setState(() {
                                        _selectedSource = newValue;
                                        _updateBranchFromSource();
                                      });
                                    },
                            );
                          }
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
                          value: _selectedBranch, // ignore: deprecated_member_use
                          items: branches
                              .map((b) => DropdownMenuItem(
                                    value: b,
                                    child: Text(b, overflow: TextOverflow.ellipsis),
                                  ))
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
                  
                  const SizedBox(height: 24),
                  
                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: (_prompt.isNotEmpty && _selectedSource != null)
                            ? _create
                            : null,
                        child: const Text('Create Session'),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      );
    });
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
