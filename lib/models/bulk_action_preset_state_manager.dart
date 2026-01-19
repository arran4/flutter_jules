import 'bulk_action_preset.dart';
import 'filter_element.dart';

class BulkActionPresetStateManager {
  BulkActionPreset? _lastLoadedPreset;

  BulkActionPreset? get lastLoadedPreset => _lastLoadedPreset;

  void setLastLoadedPreset(BulkActionPreset preset) {
    _lastLoadedPreset = preset;
  }

  void clearLastLoadedPreset() {
    _lastLoadedPreset = null;
  }

  /// Updates the state based on changes to the filter or actions.
  /// If the filter is cleared, we clear the loaded preset association.
  void onStateChanged(FilterElement? filterTree) {
    if (_lastLoadedPreset != null) {
      // If the filter is effectively empty, we assume the user has "cleared" the context
      // and thus we should forget the preset.
      if (filterTree?.toExpression().isEmpty ?? true) {
        clearLastLoadedPreset();
      }
    }
  }

  /// Determines if the save dialog should be pre-filled with the last loaded preset's info.
  bool shouldPreFill(bool isSystemPreset) {
    if (_lastLoadedPreset == null) {
      return false;
    }
    if (isSystemPreset) {
      return false;
    }
    return true;
  }
}
