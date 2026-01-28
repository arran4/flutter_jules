import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models/filter_element.dart';
import 'package:flutter_jules/models/search_filter.dart';
import 'package:flutter_jules/ui/widgets/advanced_search_bar.dart';

void main() {
  group('AdvancedSearchBar selection', () {
    testWidgets('selecting a flag suggestion builds a HasPrElement', (
      WidgetTester tester,
    ) async {
      FilterElement? captured;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedSearchBar(
              filterTree: null,
              onFilterTreeChanged: (value) => captured = value,
              searchText: '',
              onSearchChanged: (_) {},
              availableSuggestions: const [
                FilterToken(
                  id: 'flag:has_pr',
                  type: FilterType.flag,
                  label: 'Has PR',
                  value: 'has_pr',
                ),
              ],
              activeSorts: const [],
              onSortsChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '@has');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Has PR'));
      await tester.pumpAndSettle();

      expect(captured, isA<HasPrElement>());
    });

    testWidgets('selecting a time suggestion builds a TimeFilterElement', (
      WidgetTester tester,
    ) async {
      FilterElement? captured;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedSearchBar(
              filterTree: null,
              onFilterTreeChanged: (value) => captured = value,
              searchText: '',
              onSearchChanged: (_) {},
              availableSuggestions: const [],
              activeSorts: const [],
              onSortsChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '@last 15');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Last 15 minutes'));
      await tester.pumpAndSettle();

      expect(captured, isA<TimeFilterElement>());
    });
  });
}
