import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/protocol/enums.dart' show TriggerId;
import '../../providers/connection_provider.dart';
import '../../providers/axis_state_provider.dart';

/// Press-and-hold trigger button (L2/R2). Press to activate, release to deactivate.
/// Works like L1/R1 buttons instead of toggle.
class TriggerButton extends ConsumerStatefulWidget {
  final String label;
  final TriggerId triggerId;
  final double width;
  final double height;
  final Color color;
  final bool editMode;
  final bool isSelected;
  final double opacity;

  const TriggerButton({
    super.key,
    required this.label,
    required this.triggerId,
    this.width = 48,
    this.height = 48,
    this.color = Colors.orange,
    this.editMode = false,
    this.isSelected = false,
    this.opacity = 1.0,
  });

  @override
  ConsumerState<TriggerButton> createState() => _TriggerButtonState();
}

class _TriggerButtonState extends ConsumerState<TriggerButton> {
  bool _isPressed = false;

  void _onTapDown(_) {
    if (widget.editMode) return;
    setState(() => _isPressed = true);
    _send(255);
  }

  void _onTapUp(_) {
    if (widget.editMode) return;
    setState(() => _isPressed = false);
    _send(0);
  }

  void _onTapCancel() {
    if (widget.editMode) return;
    if (_isPressed) {
      setState(() => _isPressed = false);
      _send(0);
    }
  }

  void _send(int value) {
    final encoder = ref.read(packetEncoderProvider);
    final packet = encoder.encodeTriggerEvent(widget.triggerId, value);
    ref.read(connectionProvider.notifier).send(packet.toBytes());
    ref.read(axisStateProvider.notifier).update((s) {
      if (widget.triggerId == TriggerId.l2) {
        return AxisState(lx: s.lx, ly: s.ly, rx: s.rx, ry: s.ry, lt: value, rt: s.rt);
      } else {
        return AxisState(lx: s.lx, ly: s.ly, rx: s.rx, ry: s.ry, lt: s.lt, rt: value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.opacity,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 50),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(widget.width / 2),
            color: _isPressed
                ? widget.color.withValues(alpha: 0.9)
                : widget.color.withValues(alpha: 0.2),
            border: widget.isSelected
                ? Border.all(color: Colors.cyanAccent, width: 2.5)
                : Border.all(
                    color: _isPressed
                        ? widget.color
                        : widget.color.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.6),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              color: _isPressed ? Colors.white : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
