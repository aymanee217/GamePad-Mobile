import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/model/button_layout_item.dart';
import '../../../../core/protocol/enums.dart' show ButtonId, StickId, TriggerId;
import '../../providers/layout_provider.dart';
import 'game_button.dart';
import 'joystick.dart';
import 'trigger_button.dart';

/// Data-driven gamepad layout using Stack + Positioned for free-form placement.
/// Supports edit mode for moving/resizing/opacity.
class GamepadLayout extends ConsumerStatefulWidget {
  const GamepadLayout({super.key});

  @override
  ConsumerState<GamepadLayout> createState() => _GamepadLayoutState();
}

class _GamepadLayoutState extends ConsumerState<GamepadLayout> {
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
            // Grid overlay in edit mode
            if (editMode) _gridOverlay(w, h),
            // Buttons
            for (final item in layout.profile.items)
              _buildControl(item, layout, w, h),
          ],
        );
      },
    );
  }

  Widget _gridOverlay(double w, double h) {
    return CustomPaint(
      size: Size(w, h),
      painter: _GridPainter(),
    );
  }

  Widget _buildControl(ButtonLayoutItem item, LayoutEditorState layout, double w, double h) {
    final editMode = layout.editMode;
    final isSelected = layout.selectedControl == item.controlId;
    final baseSize = _baseSize(item.controlId);
    final size = baseSize * item.scale;
    final posX = item.x * w - size / 2;
    final posY = item.y * h - size / 2;

    return Positioned(
      left: posX,
      top: posY,
      child: GestureDetector(
        onTap: editMode
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
        child: _controlWidget(item.controlId, size, item.opacity, editMode, isSelected),
      ),
    );
  }

  Widget _controlWidget(ControlId id, double size, double opacity, bool editMode, bool isSelected) {
    switch (id.type) {
      case ControlType.button:
        return _buttonFromId(id.name, size, opacity, editMode, isSelected);
      case ControlType.trigger:
        return TriggerButton(
          label: id.name.toUpperCase(),
          triggerId: TriggerId.values.firstWhere((t) => t.name == id.name),
          width: size * 1.2,
          height: size * 1.6,
          color: Colors.orange.shade400,
          editMode: editMode,
          isSelected: isSelected,
          opacity: opacity,
        );
      case ControlType.joystick:
        return Joystick(
          stickId: StickId.values.firstWhere((s) => s.name == id.name),
          size: size,
          editMode: editMode,
          isSelected: isSelected,
          opacity: opacity,
        );
    }
  }

  Widget _buttonFromId(String name, double size, double opacity, bool editMode, bool isSelected) {
    final id = ButtonId.values.firstWhere((b) => b.name == name);
    final (label, color) = _buttonProps(id);
    return GameButton(
      label: label,
      buttonId: id,
      size: size,
      color: color,
      editMode: editMode,
      isSelected: isSelected,
      opacity: opacity,
    );
  }

  (String, Color) _buttonProps(ButtonId id) => switch (id) {
        ButtonId.a => ('A', Colors.green),
        ButtonId.b => ('B', Colors.red),
        ButtonId.x => ('X', Colors.blue),
        ButtonId.y => ('Y', Colors.amber),
        ButtonId.lb => ('L1', Colors.orange.shade700),
        ButtonId.rb => ('R1', Colors.orange.shade700),
        ButtonId.start => ('●', Colors.grey.shade600),
        ButtonId.select => ('●', Colors.grey.shade600),
        ButtonId.guide => ('●', Colors.grey.shade400),
        ButtonId.dPadUp => ('▲', Colors.blueGrey),
        ButtonId.dPadDown => ('▼', Colors.blueGrey),
        ButtonId.dPadLeft => ('◀', Colors.blueGrey),
        ButtonId.dPadRight => ('▶', Colors.blueGrey),
        _ => ('?', Colors.grey),
      };

  double _baseSize(ControlId id) {
    if (id.type == ControlType.joystick) return 90;
    if (id.type == ControlType.trigger) return 36;
    if (id.name == 'guide') return 42;
    return 44;
  }
}

/// Paints a subtle grid overlay in edit mode.
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
