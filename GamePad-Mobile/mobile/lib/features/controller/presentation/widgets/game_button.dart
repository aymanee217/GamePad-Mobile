import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/model/button_layout_item.dart' show ButtonShape;
import '../../../../core/protocol/enums.dart' show ButtonId;
import '../../providers/button_provider.dart';

/// Pressable game button with press / release / long-press support.
/// Supports circle or rectangle shape.
class GameButton extends ConsumerStatefulWidget {
  final String label;
  final ButtonId buttonId;
  final double size;
  final Color? color;
  final TextStyle? labelStyle;
  final bool editMode;
  final bool isSelected;
  final double opacity;
  final ButtonShape shape;
  final double? width;
  final double? height;

  const GameButton({
    super.key,
    required this.label,
    required this.buttonId,
    this.size = 64,
    this.color,
    this.labelStyle,
    this.editMode = false,
    this.isSelected = false,
    this.opacity = 1.0,
    this.shape = ButtonShape.circle,
    this.width,
    this.height,
  });

  @override
  ConsumerState<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends ConsumerState<GameButton> {
  bool _isPressed = false;
  bool _isLongPressed = false;
  Timer? _longPressTimer;

  void _onTapDown(_) {
    if (widget.editMode) return;
    setState(() => _isPressed = true);
    ref.read(buttonProvider.notifier).onButtonDown(widget.buttonId);
    _longPressTimer = Timer(
      Duration(milliseconds: AppConfig.longPressDurationMs),
      () {
        if (mounted) {
          setState(() => _isLongPressed = true);
          ref.read(buttonProvider.notifier).onButtonLongPress(widget.buttonId);
        }
      },
    );
  }

  void _onTapUp(_) {
    if (widget.editMode) return;
    _longPressTimer?.cancel();
    setState(() {
      _isPressed = false;
      _isLongPressed = false;
    });
    ref.read(buttonProvider.notifier).onButtonUp(widget.buttonId);
  }

  void _onTapCancel() {
    if (widget.editMode) return;
    _longPressTimer?.cancel();
    if (_isPressed) {
      setState(() {
        _isPressed = false;
        _isLongPressed = false;
      });
      ref.read(buttonProvider.notifier).onButtonUp(widget.buttonId);
    }
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = widget.color ?? theme.colorScheme.primary;

    Color effectiveColor;
    if (_isLongPressed) effectiveColor = bgColor.withValues(alpha: 0.7);
    else if (_isPressed) effectiveColor = bgColor.withValues(alpha: 0.4);
    else effectiveColor = bgColor;

    final isRect = widget.shape == ButtonShape.rectangle;
    final w = widget.width ?? widget.size;
    final h = widget.height ?? widget.size;

    return Opacity(
      opacity: widget.opacity,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 50),
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: effectiveColor,
            borderRadius: isRect
                ? BorderRadius.circular(8)
                : null,
            shape: isRect ? BoxShape.rectangle : BoxShape.circle,
            border: widget.isSelected
                ? Border.all(color: Colors.cyanAccent, width: 2.5)
                : _isLongPressed
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
            boxShadow: _isPressed || widget.editMode
                ? []
                : [
                    BoxShadow(
                      color: bgColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: widget.labelStyle ??
                    theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: isRect ? 14 : null,
                    ),
              ),
              if (widget.editMode)
                Icon(Icons.drag_indicator, size: 10, color: theme.colorScheme.onPrimary.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
