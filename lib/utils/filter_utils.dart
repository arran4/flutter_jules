import '../models/session.dart';
import '../models/search_filter.dart';
import '../models/cache_metadata.dart';
import '../services/message_queue_provider.dart';
import '../models/filter_element.dart';
import '../models/enums.dart';

class FilterUtils {
  static bool matches(
    Session session,
    CacheMetadata metadata,
    List<FilterToken> activeFilters,
    MessageQueueProvider queueProvider, {
    String searchText = '',
  }) {
    if (searchText.isNotEmpty) {
      final query = searchText.toLowerCase();
      final matches = (session.title?.toLowerCase().contains(query) ?? false) ||
          (session.name.toLowerCase().contains(query)) ||
          (session.id.toLowerCase().contains(query)) ||
          (session.state.toString().toLowerCase().contains(query));
      if (!matches) return false;
    }

    if (activeFilters.isEmpty) return true;

    // Filter Tokens Logic
    // Group by Type
    final statusFilters =
        activeFilters.where((f) => f.type == FilterType.status).toList();
    final sourceFilters =
        activeFilters.where((f) => f.type == FilterType.source).toList();
    final flagFilters =
        activeFilters.where((f) => f.type == FilterType.flag).toList();
    final textFilters =
        activeFilters.where((f) => f.type == FilterType.text).toList();
    final ciStatusFilters =
        activeFilters.where((f) => f.type == FilterType.ciStatus).toList();

    // 1. Status: OR logic for Include, AND logic for Exclude
    if (statusFilters.isNotEmpty) {
      final includes = statusFilters.where((f) => f.mode == FilterMode.include);
      final excludes = statusFilters.where((f) => f.mode == FilterMode.exclude);

      if (includes.isNotEmpty) {
        final matchesAny = includes.any((f) => session.state == f.value);
        if (!matchesAny) return false;
      }

      if (excludes.isNotEmpty) {
        final matchesAny = excludes.any((f) => session.state == f.value);
        if (matchesAny) return false;
      }
    }

    // 2. Source: OR logic for Include, AND logic for Exclude
    if (sourceFilters.isNotEmpty) {
      final includes = sourceFilters.where((f) => f.mode == FilterMode.include);
      final excludes = sourceFilters.where((f) => f.mode == FilterMode.exclude);

      if (includes.isNotEmpty) {
        final matchesAny = includes.any(
          (f) => session.sourceContext.source == f.value,
        );
        if (!matchesAny) return false;
      }

      if (excludes.isNotEmpty) {
        final matchesAny = excludes.any(
          (f) => session.sourceContext.source == f.value,
        );
        if (matchesAny) return false;
      }
    }

    // 3. Flags: OR logic for Includes (matches any flag), AND for Excludes
    if (flagFilters.isNotEmpty) {
      final includes = flagFilters.where((f) => f.mode == FilterMode.include);
      final excludes = flagFilters.where((f) => f.mode == FilterMode.exclude);

      if (includes.isNotEmpty) {
        bool matchesAny = false;
        for (final f in includes) {
          if (f.value == 'new' && metadata.isNew) matchesAny = true;
          if (f.value == 'updated' && metadata.isUpdated && !metadata.isNew) {
            matchesAny = true;
          }
          if (f.value == 'unread' && metadata.isUnread) matchesAny = true;
          if (f.value == 'has_pr' &&
              (session.outputs?.any((o) => o.pullRequest != null) ?? false)) {
            matchesAny = true;
          }
          if (f.value == 'watched' && metadata.isWatched) {
            matchesAny = true;
          }
          if (f.value == 'hidden' && metadata.isHidden) {
            matchesAny = true;
          }
          if (f.value == 'draft') {
            if (queueProvider.getDrafts(session.id).isNotEmpty) {
              matchesAny = true;
            }
            if (session.id.startsWith('DRAFT_CREATION_')) {
              matchesAny = true;
            }
          }
        }
        if (!matchesAny) return false;
      }

      if (excludes.isNotEmpty) {
        bool matchesAny = false;
        for (final f in excludes) {
          if (f.value == 'new' && metadata.isNew) matchesAny = true;
          if (f.value == 'updated' && metadata.isUpdated && !metadata.isNew) {
            matchesAny = true;
          }
          if (f.value == 'unread' && metadata.isUnread) matchesAny = true;
          if (f.value == 'has_pr' &&
              (session.outputs?.any((o) => o.pullRequest != null) ?? false)) {
            matchesAny = true;
          }
          if (f.value == 'watched' && metadata.isWatched) {
            matchesAny = true;
          }
          if (f.value == 'hidden' && metadata.isHidden) {
            matchesAny = true;
          }
          if (f.value == 'draft') {
            if (queueProvider.getDrafts(session.id).isNotEmpty) {
              matchesAny = true;
            }
            if (session.id.startsWith('DRAFT_CREATION_')) {
              matchesAny = true;
            }
          }
        }
        if (matchesAny) return false;
      }
    }

    // 4. Text Filters (Labels/Tag matching)
    if (textFilters.isNotEmpty) {
      final includes = textFilters.where((f) => f.mode == FilterMode.include);
      if (includes.isNotEmpty) {
        final matchesAny = includes.any((f) {
          final val = f.value.toString().toLowerCase();
          // Check labels
          if (metadata.labels.any((l) => l.toLowerCase() == val)) {
            return true;
          }
          // Check title/name
          if (session.title?.toLowerCase().contains(val) ?? false) {
            return true;
          }
          if (session.name.toLowerCase().contains(val)) return true;
          return false;
        });
        if (!matchesAny) return false;
      }

      final excludes = textFilters.where((f) => f.mode == FilterMode.exclude);
      if (excludes.isNotEmpty) {
        final matchesAny = excludes.any((f) {
          final val = f.value.toString().toLowerCase();
          if (metadata.labels.any((l) => l.toLowerCase() == val)) {
            return true;
          }
          if (session.title?.toLowerCase().contains(val) ?? false) {
            return true;
          }
          if (session.name.toLowerCase().contains(val)) return true;
          return false;
        });
        if (matchesAny) return false;
      }
    }

    // 5. CI Status: OR logic for Include, AND logic for Exclude
    if (ciStatusFilters.isNotEmpty) {
      final includes = ciStatusFilters.where(
        (f) => f.mode == FilterMode.include,
      );
      final excludes = ciStatusFilters.where(
        (f) => f.mode == FilterMode.exclude,
      );

      if (includes.isNotEmpty) {
        final matchesAny = includes.any(
          (f) =>
              session.ciStatus?.toLowerCase() ==
              f.value.toString().toLowerCase(),
        );
        if (!matchesAny) return false;
      }

      if (excludes.isNotEmpty) {
        final matchesAny = excludes.any(
          (f) =>
              session.ciStatus?.toLowerCase() ==
              f.value.toString().toLowerCase(),
        );
        if (matchesAny) return false;
      }
    }

    return true;
  }

  static List<FilterElement> getAlternatives(FilterElement element) {
    if (element is PrStatusElement) {
      return [
        PrStatusElement('Draft', 'draft'),
        PrStatusElement('Open', 'open'),
        PrStatusElement('Merged', 'merged'),
        PrStatusElement('Closed', 'closed'),
      ].where((e) => e.value != element.value).toList();
    } else if (element is StatusElement) {
      return SessionState.values
          .where((s) => s != SessionState.STATE_UNSPECIFIED)
          .map((s) => StatusElement(s.displayName, s.name))
          .where((e) => e.value != element.value)
          .toList();
    } else if (element is LabelElement) {
      final stdLabels = [
        LabelElement('New', 'new'),
        LabelElement('Updated', 'updated'),
        LabelElement('Unread', 'unread'),
        LabelElement('Hidden', 'hidden'),
        LabelElement('Watching', 'watched'),
        LabelElement('Pending', 'pending'),
      ];
      return stdLabels.where((e) => e.value != element.value).toList();
    } else if (element is CiStatusElement) {
      return [
        CiStatusElement('Success', 'success'),
        CiStatusElement('Failure', 'failure'),
        CiStatusElement('Pending', 'pending'),
        CiStatusElement('No Checks', 'no checks'),
      ].where((e) => e.value != element.value).toList();
    }
    return [];
  }
}
