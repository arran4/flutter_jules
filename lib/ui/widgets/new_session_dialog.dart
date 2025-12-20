import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
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
  String _image = '';

  // Task Mode
  // Options: Question (No Plan), Plan (Verify Plan), Start (Auto)
  int _selectedModeIndex = 0; // 0: Question, 1: Plan, 2: Start

  // Data Loading
  List<Source> _sources = [];
  bool _isLoadingSources = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSources();
  }

  Future<void> _fetchSources() async {
    try {
      final client = Provider.of<AuthProvider>(context, listen: false).client;
      final sources = await client.listSources();

      if (mounted) {
        setState(() {
          _sources = sources;
          _isLoadingSources = false;

          // Pre-select source if filter exists
          if (widget.sourceFilter != null) {
            try {
              _selectedSource = _sources.firstWhere(
                (s) => s.name == widget.sourceFilter,
              );
            } catch (e) {
              // Source from filter not found in list, handle gracefully
              print('Source filter ${widget.sourceFilter} not found in list');
            }
          }

          // Default to first source if none selected
          if (_selectedSource == null && _sources.isNotEmpty) {
             // If no filter, maybe default to 'sources/default' if it exists, or just the first one?
             // Let's try to find 'sources/default' first
             try {
                _selectedSource = _sources.firstWhere((s) => s.name == 'sources/default');
             } catch (_) {
                _selectedSource = _sources.first;
             }
          }

          // Set default branch for the selected source
          _updateBranchFromSource();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load sources: $e';
          _isLoadingSources = false;
        });
      }
    }
  }

  void _updateBranchFromSource() {
    if (_selectedSource != null && _selectedSource!.githubRepo != null) {
      final repo = _selectedSource!.githubRepo!;
      // Prefer default branch, then main/master, then first branch
      if (repo.defaultBranch != null) {
        _selectedBranch = repo.defaultBranch!.displayName;
      } else if (repo.branches != null && repo.branches!.isNotEmpty) {
        _selectedBranch = repo.branches!.first.displayName;
      } else {
        _selectedBranch = 'main'; // Fallback
      }
    } else {
      _selectedBranch = 'main';
    }
  }

  void _create() async {
     if (_selectedSource == null) return; // Should not happen if sources loaded

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
         requirePlanApproval = false; // Or true? Assume auto-start implies doing it.
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
        image: _image.isNotEmpty ? _image : null,
     );

     Navigator.pop(context, newSession);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSources) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return AlertDialog(
        title: const Text('Error'),
        content: Text(_error!),
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
    if (_selectedSource != null && _selectedSource!.githubRepo != null && _selectedSource!.githubRepo!.branches != null) {
      branches = _selectedSource!.githubRepo!.branches!.map((b) => b.displayName).toList();
    }
    // If branches are empty, we still want to allow user to specify one, or show 'main'
    // But for now let's assume if list is empty we just show a text field or single item?
    // Let's use a Dropdown if we have branches, otherwise a text field?
    // To keep it simple and consistent, we can add the current _selectedBranch to the list if not present.
    if (_selectedBranch != null && !branches.contains(_selectedBranch)) {
      branches.add(_selectedBranch!);
    }
    if (branches.isEmpty) branches.add('main');

    return AlertDialog(
      title: const Text('New Session', style: TextStyle(fontWeight: FontWeight.bold)),
      scrollable: true,
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8, // Make it wider
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode Selection
            const Text('I want to...', style: TextStyle(fontWeight: FontWeight.bold)),
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
              maxLines: 6, // Bigger
              decoration: const InputDecoration(
                labelText: 'Prompt',
                hintText: 'Describe what you want to do...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              onChanged: (val) => _prompt = val,
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
              onChanged: (val) => _image = val,
            ),
            const SizedBox(height: 16),

            // Context (Source & Branch)
            const Text('Context', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    items: _sources.map((s) {
                      // Use repo name if available, else source ID
                      final label = s.githubRepo != null
                          ? '${s.githubRepo!.owner}/${s.githubRepo!.repo}'
                          : s.name;
                      return DropdownMenuItem(
                        value: s,
                        child: Text(label, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (widget.sourceFilter != null)
                        ? null // Disable if source filter is active
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
                    items: branches.map((b) => DropdownMenuItem(
                      value: b,
                      child: Text(b, overflow: TextOverflow.ellipsis),
                    )).toList(),
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
            color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurface,
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
