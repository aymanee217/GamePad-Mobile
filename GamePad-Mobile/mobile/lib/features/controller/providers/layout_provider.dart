import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/model/button_layout_item.dart';
import '../../../core/service/layout_manager.dart';

/// State for the layout editor.
class LayoutEditorState {
  final LayoutProfile profile;
  final bool editMode;
  final ControlId? selectedControl;

  const LayoutEditorState({
    required this.profile,
    this.editMode = false,
    this.selectedControl,
  });

  LayoutEditorState copyWith({
    LayoutProfile? profile,
    bool? editMode,
    ControlId? selectedControl,
    bool clearSelection = false,
  }) {
    return LayoutEditorState(
      profile: profile ?? this.profile,
      editMode: editMode ?? this.editMode,
      selectedControl: clearSelection ? null : (selectedControl ?? this.selectedControl),
    );
  }

  ButtonLayoutItem? find(ControlId id) {
    try {
      return profile.items.firstWhere((i) => i.controlId == id);
    } catch (_) {
      return null;
    }
  }

  void updateItem(ControlId id, {double? x, double? y, double? scale, double? opacity, ButtonShape? shape}) {
    for (final item in profile.items) {
      if (item.controlId == id) {
        if (x != null) item.x = x;
        if (y != null) item.y = y;
        if (scale != null) item.scale = scale;
        if (opacity != null) item.opacity = opacity;
        if (shape != null) item.shape = shape;
        break;
      }
    }
  }
}

class LayoutNotifier extends StateNotifier<LayoutEditorState> {
  LayoutNotifier() : super(LayoutEditorState(profile: LayoutProfile(items: [])));

  Future<void> load() async {
    final profile = await LayoutManager.loadActive();
    state = LayoutEditorState(profile: profile);
  }

  void setProfile(LayoutProfile profile) {
    state = LayoutEditorState(profile: profile);
  }

  void toggleEditMode() {
    state = state.copyWith(
      editMode: !state.editMode,
      clearSelection: state.editMode,
    );
  }

  void selectControl(ControlId id) {
    state = state.copyWith(selectedControl: id);
  }

  void deselectControl() {
    state = state.copyWith(clearSelection: true);
  }

  void moveControl(ControlId id, double x, double y) {
    state.updateItem(id, x: x, y: y);
    _notify();
  }

  void resizeControl(ControlId id, double scale) {
    state.updateItem(id, scale: scale.clamp(0.5, 2.0));
    _notify();
  }

  void changeOpacity(ControlId id, double opacity) {
    state.updateItem(id, opacity: opacity.clamp(0.2, 1.0));
    _notify();
  }

  void changeShape(ControlId id, ButtonShape shape) {
    state.updateItem(id, shape: shape);
    _notify();
  }

  void _notify() {
    state = state.copyWith(
      profile: LayoutProfile(name: state.profile.name, items: state.profile.items),
    );
  }

  Future<void> save() async {
    await LayoutManager.saveActiveProfile(state.profile);
  }

  Future<void> reset() async {
    final profile = await LayoutManager.resetActive();
    state = LayoutEditorState(profile: profile);
  }
}

final layoutProvider = StateNotifierProvider<LayoutNotifier, LayoutEditorState>((ref) {
  return LayoutNotifier();
});
