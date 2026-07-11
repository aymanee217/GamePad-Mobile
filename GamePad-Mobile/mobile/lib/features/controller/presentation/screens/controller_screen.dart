import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/connection_provider.dart';
import '../../providers/layout_provider.dart';
import '../../../../core/model/button_layout_item.dart';
import '../widgets/gamepad_layout.dart';

/// Fullscreen controller with hidden edit mode.
/// Tap back arrow (top-left) to return to profiles.
/// Tap pencil icon (top-right) to toggle edit mode.
class ControllerScreen extends ConsumerStatefulWidget {
  final LayoutProfile profile;
  final int profileIndex;

  const ControllerScreen({
    super.key,
    required this.profile,
    required this.profileIndex,
  });

  @override
  ConsumerState<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends ConsumerState<ControllerScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = ref.watch(layoutProvider);
    final editMode = layout.editMode;

    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(connectionProvider.notifier).tryAutoReconnect();
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Gamepad
          Positioned.fill(
            child: GamepadLayout(
              onBackTap: () {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                Navigator.of(context).pop();
              },
              onEditToggle: () => ref.read(layoutProvider.notifier).toggleEditMode(),
            ),
          ),

          // Edit mode bottom panel
          if (editMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _EditorPanel(
                layout: layout,
                onToggleEdit: () => ref.read(layoutProvider.notifier).toggleEditMode(),
                onSelect: (id) => ref.read(layoutProvider.notifier).selectControl(id),
                onDeselect: () => ref.read(layoutProvider.notifier).deselectControl(),
                onResize: (id, v) => ref.read(layoutProvider.notifier).resizeControl(id, v),
                onOpacity: (id, v) => ref.read(layoutProvider.notifier).changeOpacity(id, v),
                onShape: (id, s) => ref.read(layoutProvider.notifier).changeShape(id, s),
                onSave: () {
                  ref.read(layoutProvider.notifier).save();
                  ref.read(layoutProvider.notifier).toggleEditMode();
                },
                onReset: () => ref.read(layoutProvider.notifier).reset(),
              ),
            ),

          // Top-right: connection dot only
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Builder(
                builder: (context) {
                  final connection = ref.watch(connectionProvider);
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 16, top: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: connection.phase == ConnectionPhase.connected
                          ? Colors.green
                          : connection.phase == ConnectionPhase.connecting
                              ? Colors.orange
                              : Colors.red,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom panel for editing controls.
class _EditorPanel extends StatelessWidget {
  final LayoutEditorState layout;
  final VoidCallback onToggleEdit;
  final ValueChanged<ControlId> onSelect;
  final VoidCallback onDeselect;
  final void Function(ControlId, double) onResize;
  final void Function(ControlId, double) onOpacity;
  final void Function(ControlId, ButtonShape) onShape;
  final VoidCallback onSave;
  final VoidCallback onReset;

  const _EditorPanel({
    required this.layout,
    required this.onToggleEdit,
    required this.onSelect,
    required this.onDeselect,
    required this.onResize,
    required this.onOpacity,
    required this.onShape,
    required this.onSave,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final selected = layout.selectedControl;
    final item = selected != null ? layout.find(selected) : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: item != null
            ? Colors.black.withValues(alpha: 0.92)
            : Colors.black.withValues(alpha: 0.65),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            selected != null ? _label(selected) : 'Tap a button to edit',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),

          if (item != null) ...[
            const SizedBox(height: 8),
            // Size slider
            _slider('Size', item.scale, 0.5, 2.0, (v) => onResize(selected!, v)),
            // Opacity slider
            _slider('Opacity', item.opacity, 0.2, 1.0, (v) => onOpacity(selected!, v)),
            // Shape toggle (only for buttons)
            if (item.controlId.type == ControlType.button) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Shape: ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  _shapeBtn('Circle', ButtonShape.circle, item.shape, () => onShape(selected!, ButtonShape.circle)),
                  const SizedBox(width: 8),
                  _shapeBtn('Rect', ButtonShape.rectangle, item.shape, () => onShape(selected!, ButtonShape.rectangle)),
                ],
              ),
            ],
          ],

          const SizedBox(height: 8),
          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _actionBtn(Icons.save, 'Save', onSave),
              const SizedBox(width: 12),
              _actionBtn(Icons.restore, 'Reset', onReset),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              thumbColor: Colors.cyanAccent,
              activeTrackColor: Colors.cyanAccent,
              inactiveTrackColor: Colors.white24,
            ),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(value.toStringAsFixed(2), style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ),
      ],
    );
  }

  Widget _shapeBtn(String label, ButtonShape shape, ButtonShape current, VoidCallback onTap) {
    final active = shape == current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.cyanAccent.withValues(alpha: 0.2) : Colors.white12,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? Colors.cyanAccent : Colors.white24,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.cyanAccent : Colors.white70,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  String _label(ControlId id) {
    if (id.type == ControlType.joystick) return 'Joystick ${id.name == 'left' ? 'L' : 'R'}';
    if (id.type == ControlType.trigger) return 'Trigger ${id.name.toUpperCase()}';
    if (id.type == ControlType.back) return 'Back Button';
    if (id.type == ControlType.edit) return 'Edit Button';
    return 'Button ${id.name.toUpperCase()}';
  }
}
