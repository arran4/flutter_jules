import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

import 'session_provider.dart';

class TagsProvider with ChangeNotifier {
  final SessionProvider _sessionProvider;
  List<String> _allTags = [];

  TagsProvider(this._sessionProvider) {
    _sessionProvider.addListener(_updateTags);
    _updateTags();
  }

  @override
  void dispose() {
    _sessionProvider.removeListener(_updateTags);
    super.dispose();
  }

  List<String> get allTags => _allTags;

  void _updateTags() {
    final allSessions = _sessionProvider.items.map((e) => e.data);
    final tagSet = <String>{};
    for (final session in allSessions) {
      if (session.tags != null) {
        tagSet.addAll(session.tags!);
      }
    }
    final sortedTags = tagSet.toList()..sort(compareAsciiLowerCase);
    if (!const ListEquality().equals(_allTags, sortedTags)) {
      _allTags = sortedTags;
      notifyListeners();
    }
  }
}
