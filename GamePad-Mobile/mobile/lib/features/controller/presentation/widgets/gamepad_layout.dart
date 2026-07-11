import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/model/button_layout_item.dart';
import '../../../../core/protocol/enums.dart' show ButtonId, StickId, TriggerId;
import '../../providers/layout_provider.dart';
import 'game_button.dart';
import 'joystick.dart';
import 'trigger_button.dart';

/// Data-driven gamepad layout using Stack + Positioned for free-form placement.
/// Supports edit mode for moving/resizing/opacity/shape.
class GamepadLayout extends ConsumerStatefulWidget {
  final VoidCallback? onBackTap;
  final VoidCallback? onEditToggle;

  const GamepadLayout({super.key, this.onBackTap, this.onEditToggle});

  @override
  ConsumerState<GamepadLayout> createState() => _GamepadLayoutState();
}

class _GamepadLayoutState extends ConsumerState<GamepadLayout> {
  VoidCallback? get _onBackTap => widget.onBackTap;
  VoidCallback? get _onEditToggle => widget.onEditToggle;

  @override
  Widget build(BuildContext context) {
    final layout = ref.watch(layoutProvider);
    final editMode = layout.editMode;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          children: [
            if (editMode) _gridOverlay(w, h),
            for (final item in layout.profile.items)
              _buildControl(item, layout, w, h),
          ],
        );
      },
    );
  }

  Widget _gridOverlay(double w, double h) {
    return CustomPaint(size: Size(w, h), painter: _GridPainter());
  }

  Widget _buildControl(ButtonLayoutItem item, LayoutEditorState layout, double w, double h) {
    final editMode = layout.editMode;
    final isSelected = layout.selectedControl == item.controlId;
    final baseSize = _baseSize(item.controlId);
    final size = baseSize * item.scale;
    final posX = item.x * w - size / 2;
    final posY = item.y * h - size / 2;

    final isUtility = item.controlId.type == ControlType.back || item.controlId.type == ControlType.edit;

    return Positioned(
      left: posX,
      top: posY,
      child: GestureDetector(
        onTap: isUtility && !editMode
            ? () {
                if (item.controlId.type == ControlType.back) {
                  _onBackTap?.call();
                } else if (item.controlId.type == ControlType.edit) {
                  _onEditToggle?.call();
                }
              }
            : editMode
                ? () {
                    if (isSelected) {
                      ref.read(layoutProvider.notifier).deselectControl();
                    } else {
                      ref.read(layoutProvider.notifier).selectControl(item.controlId);
                    }
                  }
                : null,
        onPanUpdate: editMode
            ? (details) {
                final newX = ((posX + size / 2 + details.delta.dx) / w).clamp(0.0, 1.0);
                final newY = ((posY + size / 2 + details.delta.dy) / h).clamp(0.0, 1.0);
                ref.read(layoutProvider.notifier).moveControl(item.controlId, newX, newY);
              }
            : null,
        child: _controlWidget(item, size, editMode, isSelected),
      ),
    );
  }

  Widget _controlWidget(ButtonLayoutItem item, double size, bool editMode, bool isSelected) {
    final id = item.controlId;
    switch (id.type) {
      case ControlType.button:
        return _buttonFromId(id.name, size, item.opacity, editMode, isSelected, item.shape);
      case ControlType.trigger:
        return TriggerButton(
          label: id.name.toUpperCase(),
          triggerId: TriggerId.values.firstWhere((t) => t.name == id.name),
          width: size * 1.2,
          height: size * 1.6,
          color: Colors.orange.shade400,
          editMode: editMode,
          isSelected: isSelected,
          opacity: item.opacity,
        );
      case ControlType.joystick:
        return Joystick(
          stickId: StickId.values.firstWhere((s) => s.name == id.name),
          size: size,
          editMode: editMode,
          isSelected: isSelected,
          opacity: item.opacity,
        );
      case ControlType.back:
        return _utilityIcon(
          icon: Icons.arrow_back,
          label: 'Back',
          size: size,
          opacity: item.opacity,
          editMode: editMode,
          isSelected: isSelected,
          color: Colors.white54,
        );
      case ControlType.edit:
        return _utilityIcon(
          icon: Icons.tune,
          label: 'Edit',
          size: size,
          opacity: item.opacity,
          editMode: editMode,
          isSelected: isSelected,
          color: Colors.cyanAccent,
        );
    }
  }

  Widget _utilityIcon({
    required IconData icon,
    required String label,
    required double size,
    required double opacity,
    required bool editMode,
    required bool isSelected,
    required Color color,
  }) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isSelected ? Colors.cyanAccent.withValues(alpha: 0.15) : Colors.white12,
          borderRadius: BorderRadius.circular(12),
          border: editMode
              ? Border.all(
                  color: isSelected ? Colors.cyanAccent : Colors.white24,
                  width: isSelected ? 2 : 1,
                )
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: color, size: size * 0.5),
            if (editMode)
              Positioned(
                top: 2,
                right: 2,
                child: const Icon(Icons.drag_indicator, size: 10, color: Colors.white38),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buttonFromId(String name, double size, double opacity, bool editMode, bool isSelected, ButtonShape shape) {
    final id = ButtonId.values.firstWhere((b) => b.name == name);
    final (label, color) = _buttonProps(id);

    final isRect = shape == ButtonShape.rectangle;
    final w = isRect ? size * 1.4 : size;
    final h = isRect ? size * 0.9 : size;

    return GameButton(
      label: label,
      buttonId: id,
      size: size,
      width: w,
      height: h,
      color: color,
      editMode: editMode,
      isSelected: isSelected,
      opacity: opacity,
      shape: shape,
    );
  }

  (String, Color) _buttonProps(ButtonId id) => switch (id) {
        ButtonId.a => ('A', Colors.green),
        ButtonId.b => ('B', Colors.red),
        ButtonId.x => ('X', Colors.blue),
        ButtonId.y => ('Y', Colors.amber),
        ButtonId.lb => ('L1', Colors.orange.shade700),
        ButtonId.rb => ('R1', Colors.orange.shade700),
        ButtonId.start => ('STA', Colors.grey.shade600),
        ButtonId.select => ('SEL', Colors.grey.shade600),
        ButtonId.guide => ('◉', Colors.grey.shade400),
        ButtonId.dPadUp => ('▲', Colors.blueGrey),
        ButtonId.dPadDown => ('▼', Colors.blueGrey),
        ButtonId.dPadLeft => ('◀', Colors.blueGrey),
        ButtonId.dPadRight => ('▶', Colors.blueGrey),
        _ => ('?', Colors.grey),
      };

  double _baseSize(ControlId id) {
    if (id.type == ControlType.joystick) return 90;
    if (id.type == ControlType.trigger) return 40;
    if (id.type == ControlType.back || id.type == ControlType.edit) return 44;
    if (id.name == 'guide') return 50;
    if (id.name == 'start' || id.name == 'select') return 50;
    return 48;
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 0.5;

    const step = 0.1;
    for (double f = step; f < 1.0; f += step) {
      final x = size.width * f;
      final y = size.height * f;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
