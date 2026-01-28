import '../models/session.dart';
import '../models/search_filter.dart';
import '../models/cache_metadata.dart';
import '../services/message_queue_provider.dart';
import '../models/filter_element.dart';
import '../models/enums.dart';
import '../models/time_filter.dart';
import 'time_helper.dart';

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
      final matches =
          (session.title?.toLowerCase().contains(query) ?? false) ||
          (session.name.toLowerCase().contains(query)) ||
          (session.id.toLowerCase().contains(query)) ||
          (session.state.toString().toLowerCase().contains(query));
      if (!matches) return false;
    }

    if (activeFilters.isEmpty) return true;

    // Filter Tokens Logic
    // Group by Type
    final statusFilters = activeFilters
        .where((f) => f.type == FilterType.status)
        .toList();
    final sourceFilters = activeFilters
        .where((f) => f.type == FilterType.source)
        .toList();
    final flagFilters = activeFilters
        .where((f) => f.type == FilterType.flag)
        .toList();
    final textFilters = activeFilters
        .where((f) => f.type == FilterType.text)
        .toList();
    final ciStatusFilters = activeFilters
        .where((f) => f.type == FilterType.ciStatus)
        .toList();
    final timeFilters = activeFilters
        .where((f) => f.type == FilterType.time)
        .toList();

    if (!_matchesStatusFilters(session, statusFilters)) return false;

    if (!_matchesSourceFilters(session, sourceFilters)) return false;

    if (!_matchesFlagFilters(session, metadata, flagFilters, queueProvider)) {
      return false;
    }

    if (!_matchesTextFilters(session, metadata, textFilters)) return false;

    if (!_matchesTimeFilters(session, timeFilters)) return false;

    if (!_matchesCiStatusFilters(session, ciStatusFilters)) return false;

    return true;
  }

  static bool _matchesStatusFilters(
    Session session,
    List<FilterToken> statusFilters,
  ) {
    return _matchesIncludeExclude(
      statusFilters,
      (filter) => session.state == filter.value,
    );
  }

  static bool _matchesSourceFilters(
    Session session,
    List<FilterToken> sourceFilters,
  ) {
    return _matchesIncludeExclude(
      sourceFilters,
      (filter) => session.sourceContext?.source == filter.value,
    );
  }

  static bool _matchesFlagFilters(
    Session session,
    CacheMetadata metadata,
    List<FilterToken> flagFilters,
    MessageQueueProvider queueProvider,
  ) {
    return _matchesIncludeExclude(
      flagFilters,
      (filter) => _matchesFlagFilter(
        session,
        metadata,
        queueProvider,
        filter,
      ),
    );
  }

  static bool _matchesFlagFilter(
    Session session,
    CacheMetadata metadata,
    MessageQueueProvider queueProvider,
    FilterToken filter,
  ) {
    if (filter.value == 'new' && metadata.isNew) return true;
    if (filter.value == 'updated' && metadata.isUpdated && !metadata.isNew) {
      return true;
    }
    if (filter.value == 'unread' && metadata.isUnread) return true;
    if (filter.value == 'has_pr' &&
        (session.outputs?.any((o) => o.pullRequest != null) ?? false)) {
      return true;
    }
    if (filter.value == 'watched' && metadata.isWatched) return true;
    if (filter.value == 'hidden' && metadata.isHidden) return true;
    if (filter.value == 'draft') {
      if (queueProvider.getDrafts(session.id).isNotEmpty) {
        return true;
      }
      if (session.id.startsWith('DRAFT_CREATION_')) {
        return true;
      }
    }
    return false;
  }

  static bool _matchesTextFilters(
    Session session,
    CacheMetadata metadata,
    List<FilterToken> textFilters,
  ) {
    return _matchesIncludeExclude(
      textFilters,
      (filter) => _matchesTextFilter(session, metadata, filter),
    );
  }

  static bool _matchesTextFilter(
    Session session,
    CacheMetadata metadata,
    FilterToken filter,
  ) {
    final val = filter.value.toString().toLowerCase();
    if (metadata.labels.any((label) => label.toLowerCase() == val)) {
      return true;
    }
    if (session.title?.toLowerCase().contains(val) ?? false) {
      return true;
    }
    return session.name.toLowerCase().contains(val);
  }

  static bool _matchesTimeFilters(
    Session session,
    List<FilterToken> timeFilters,
  ) {
    for (final filter in timeFilters) {
      final timeFilter = filter.value as TimeFilter;
      final matches = matchesTimeFilter(session, timeFilter);

      if (filter.mode == FilterMode.include && !matches) return false;
      if (filter.mode == FilterMode.exclude && matches) return false;
    }
    return true;
  }

  static bool _matchesCiStatusFilters(
    Session session,
    List<FilterToken> ciStatusFilters,
  ) {
    return _matchesIncludeExclude(
      ciStatusFilters,
      (filter) =>
          session.ciStatus?.toLowerCase() ==
          filter.value.toString().toLowerCase(),
    );
  }

  static bool _matchesIncludeExclude(
    Iterable<FilterToken> filters,
    bool Function(FilterToken filter) matcher,
  ) {
    if (filters.isEmpty) return true;

    final includes = filters.where((filter) => filter.mode == FilterMode.include);
    final excludes = filters.where((filter) => filter.mode == FilterMode.exclude);

    if (includes.isNotEmpty && !includes.any(matcher)) return false;
    if (excludes.isNotEmpty && excludes.any(matcher)) return false;

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
