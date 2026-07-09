import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/protocol/enums.dart' show TriggerId;
import '../../providers/connection_provider.dart';
import '../../providers/axis_state_provider.dart';

/// Toggle button for triggers (L2/R2). Tap to activate, tap again to release.
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
  bool _isActive = false;

  void _toggle() {
    if (widget.editMode) return;
    setState(() => _isActive = !_isActive);
    final value = _isActive ? 255 : 0;
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
        onTap: _toggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isActive
                ? widget.color.withValues(alpha: 0.9)
                : widget.color.withValues(alpha: 0.2),
            border: widget.isSelected
                ? Border.all(color: Colors.cyanAccent, width: 2.5)
                : Border.all(
                    color: _isActive
                        ? widget.color
                        : widget.color.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
            boxShadow: _isActive
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: _isActive ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              if (widget.editMode)
                Icon(Icons.drag_indicator, size: 10, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
