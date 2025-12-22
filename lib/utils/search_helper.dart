import 'dart:math';

/// Calculates the length of the longest common substring between two strings.
int longestCommonSubstring(String s1, String s2) {
  if (s1.isEmpty || s2.isEmpty) {
    return 0;
  }

  final m = s1.length;
  final n = s2.length;
  // Create a table to store lengths of longest common suffixes of substrings.
  // Note: List.generate is safer than creating a large fixed-size list.
  final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

  int maxLength = 0;

  for (int i = 1; i <= m; i++) {
    for (int j = 1; j <= n; j++) {
      if (s1[i - 1] == s2[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
        if (dp[i][j] > maxLength) {
          maxLength = dp[i][j];
        }
      } else {
        dp[i][j] = 0;
      }
    }
  }

  return maxLength;
}

/// Helper class to store match results for sorting.
class _MatchResult {
  final int originalIndex;
  final int score; // Length of the longest continuous match
  final int fieldIndex; // Index of the field where the best match was found
  final bool matches; // Whether it matches the filter criteria

  _MatchResult({
    required this.originalIndex,
    required this.score,
    required this.fieldIndex,
    required this.matches,
  });
}

/// Filters and sorts a list of items based on a query and a list of field accessors.
///
/// [items] The list of items to filter and sort.
/// [query] The search query.
/// [accessors] A list of functions that retrieve string fields from an item.
///             The order of accessors determines priority (earlier is higher priority).
///
/// Returns a new list containing items that match the query, sorted by:
/// 1. Length of longest continuous match (descending)
/// 2. Field priority (ascending index)
/// 3. Original order (ascending index) - for stability
List<T> filterAndSort<T>({
  required List<T> items,
  required String query,
  required List<String? Function(T)> accessors,
}) {
  if (query.isEmpty) {
    return List.of(items);
  }

  final normalizedQuery = query.toLowerCase();

  // Map items to match results
  final results = items.asMap().entries.map((entry) {
    final index = entry.key;
    final item = entry.value;

    int maxScore = 0;
    int bestFieldIndex = accessors.length;
    bool anyMatch = false;

    for (int i = 0; i < accessors.length; i++) {
      final fieldValue = accessors[i](item);
      if (fieldValue == null) continue;

      final normalizedField = fieldValue.toLowerCase();

      // Check if the field actually contains the query
      if (normalizedField.contains(normalizedQuery)) {
        // Since we verify strict containment, the longest common substring
        // (which must be a subset of the field and the query)
        // is guaranteed to be equal to the query length itself.
        final score = normalizedQuery.length;

        anyMatch = true;
        if (score > maxScore) {
          maxScore = score;
          bestFieldIndex = i;
        } else if (score == maxScore) {
          if (i < bestFieldIndex) {
            bestFieldIndex = i;
          }
        }
      }
    }

    return _MatchResult(
      originalIndex: index,
      score: maxScore,
      fieldIndex: bestFieldIndex,
      matches: anyMatch,
    );
  }).toList();

  // Filter out non-matching items
  final filteredIndices = results.where((r) => r.matches).toList();

  // Sort
  filteredIndices.sort((a, b) {
    // 1. Score (descending)
    if (a.score != b.score) {
      return b.score.compareTo(a.score);
    }
    // 2. Field priority (ascending)
    if (a.fieldIndex != b.fieldIndex) {
      return a.fieldIndex.compareTo(b.fieldIndex);
    }
    // 3. Original index (ascending) - Stable sort
    return a.originalIndex.compareTo(b.originalIndex);
  });

  // Map back to items
  return filteredIndices.map((r) => items[r.originalIndex]).toList();
}
