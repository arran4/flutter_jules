import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/source_provider.dart';
import '../../models.dart';

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

  @override
  void initState() {
    super.initState();
    // Defer data fetching to after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSources();
    });
  }

  Future<void> _fetchSources({bool force = false}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);

    if (force) {
      await sourceProvider.refresh(auth.client);
    } else {
      await sourceProvider.loadInitialPage(auth.client);
      // If we only loaded first page, maybe we want to search or load more?
      // For the dropdown, just the first page (usually contains recently used) might be enough,
      // or we might want to load more if the user scrolls (not easy in DropdownButton).
      // For now, loadInitialPage is sufficient as it likely covers 20-50 items.
    }

    if (mounted) {
      _initializeSelection(sourceProvider.sources);
    }
  }

  void _initializeSelection(List<Source> sources) {
    setState(() {
      // Pre-select source if filter exists
      if (widget.sourceFilter != null) {
        try {
          _selectedSource = sources.firstWhere(
            (s) => s.name == widget.sourceFilter,
          );
        } catch (e) {
          print('Source filter ${widget.sourceFilter} not found in list');
        }
      }

      // If already selected, verify it still exists in the list (important for re-fetches)
      if (_selectedSource != null) {
        try {
          _selectedSource =
              sources.firstWhere((s) => s.name == _selectedSource!.name);
        } catch (_) {
          // Selected source no longer exists
          _selectedSource = null;
        }
      }

      // Default to first source if none selected
      if (_selectedSource == null && sources.isNotEmpty) {
        try {
          _selectedSource =
              sources.firstWhere((s) => s.name == 'sources/default');
        } catch (_) {
          _selectedSource = sources.first;
        }
      }

      // Set default branch for the selected source if not already set or invalid
      _updateBranchFromSource();
    });
  }

  void _updateBranchFromSource() {
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

    // If current selected branch is valid for this source, keep it?
    // Usually when switching sources we want to reset to default.
    // So let's re-evaluate.
    // However, if we are just re-initializing (refresh), we might want to keep it if valid.
    // But simplified logic: always pick best default.

    if (repo.defaultBranch != null) {
      _selectedBranch = repo.defaultBranch!.displayName;
    } else if (branches.isNotEmpty) {
      _selectedBranch = branches.first;
    } else {
      _selectedBranch = 'main';
    }
  }

  Future<void> _create() async {
    if (_selectedSource == null) return;

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
        automationMode = AutomationMode.AUTO_CREATE_PR;
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

  @override
  Widget build(BuildContext context) {
    return Consumer<SourceProvider>(builder: (context, sourceProvider, _) {
      if (sourceProvider.isFetching && sourceProvider.sources.isEmpty) {
        // Initial load
        return const AlertDialog(
          content: SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }

      if (sourceProvider.error != null && sourceProvider.sources.isEmpty) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(sourceProvider.error!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            )
          ],
        );
      }

      final sources = sourceProvider.sources;

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
        title: const Text('New Session',
            style: TextStyle(fontWeight: FontWeight.bold)),
        scrollable: true,
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  if (sourceProvider.isFetching)
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
                    child: DropdownButtonFormField<Source>(
                      decoration: const InputDecoration(
                        labelText: 'Repository',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedSource,
                      items: sources.map((s) {
                        final label = s.githubRepo != null
                            ? '${s.githubRepo!.owner}/${s.githubRepo!.repo}'
                            : s.name;
                        return DropdownMenuItem(
                          value: s,
                          child: Text(label, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (widget.sourceFilter != null)
                          ? null
                          : (Source? newValue) {
                              setState(() {
                                _selectedSource = newValue;
                                _updateBranchFromSource();
                              });
                            },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Branch',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedBranch,
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: (_prompt.isNotEmpty && _selectedSource != null)
                ? _create
                : null,
            child: const Text('Create Session'),
          ),
        ],
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
