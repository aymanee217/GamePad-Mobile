import 'dart:convert';
import '../protocol/enums.dart' show ButtonId, TriggerId, StickId;

/// Which type of control this layout item represents.
enum ControlType {
  button,
  joystick,
  trigger,
  steering,
  back,
  edit,
}

/// Button shape: circle or rectangle.
enum ButtonShape {
  circle,
  rectangle,
}

/// Identifies a specific control for layout purposes.
class ControlId {
  final ControlType type;
  final String name;

  const ControlId({required this.type, required this.name});

  factory ControlId.fromButton(ButtonId id) =>
      ControlId(type: ControlType.button, name: id.name);

  factory ControlId.fromTrigger(TriggerId id) =>
      ControlId(type: ControlType.trigger, name: id.name);

  factory ControlId.fromStick(StickId id) =>
      ControlId(type: ControlType.joystick, name: id.name);

  factory ControlId.fromSteering() =>
      const ControlId(type: ControlType.steering, name: 'steering');

  Map<String, dynamic> toJson() => {'type': type.name, 'name': name};

  factory ControlId.fromJson(Map<String, dynamic> json) =>
      ControlId(type: ControlType.values.byName(json['type']), name: json['name']);

  @override
  bool operator ==(Object other) =>
      other is ControlId && other.type == type && other.name == name;

  @override
  int get hashCode => type.hashCode ^ name.hashCode;
}

/// Position, size, opacity, and shape for a single control.
class ButtonLayoutItem {
  final ControlId controlId;
  double x;
  double y;
  double scale;
  double opacity;
  ButtonShape shape;

  /// Optional display label (e.g. "DRS", "GAS", "BRAKE") shown instead of
  /// the default button name. Does not change the underlying ButtonId.
  String? label;

  ButtonLayoutItem({
    required this.controlId,
    required this.x,
    required this.y,
    this.scale = 1.0,
    this.opacity = 1.0,
    this.shape = ButtonShape.circle,
    this.label,
  });

  Map<String, dynamic> toJson() => {
        'id': controlId.toJson(),
        'x': x,
        'y': y,
        'scale': scale,
        'opacity': opacity,
        'shape': shape.name,
        if (label != null) 'label': label,
      };

  factory ButtonLayoutItem.fromJson(Map<String, dynamic> json) =>
      ButtonLayoutItem(
        controlId: ControlId.fromJson(json['id']),
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
        shape: json['shape'] != null
            ? ButtonShape.values.byName(json['shape'])
            : ButtonShape.circle,
        label: json['label'] as String?,
      );

  ButtonLayoutItem copyWith({
    double? x,
    double? y,
    double? scale,
    double? opacity,
    ButtonShape? shape,
    String? label,
  }) =>
      ButtonLayoutItem(
        controlId: controlId,
        x: x ?? this.x,
        y: y ?? this.y,
        scale: scale ?? this.scale,
        opacity: opacity ?? this.opacity,
        shape: shape ?? this.shape,
        label: label ?? this.label,
      );
}

/// A complete layout profile containing positions for all controls.
class LayoutProfile {
  final String name;
  final List<ButtonLayoutItem> items;

  const LayoutProfile({this.name = 'Default', required this.items});

  Map<String, dynamic> toJson() => {
        'name': name,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory LayoutProfile.fromJson(Map<String, dynamic> json) => LayoutProfile(
        name: json['name'] ?? 'Default',
        items: (json['items'] as List)
            .map((e) => ButtonLayoutItem.fromJson(e))
            .toList(),
      );

  String encode() => jsonEncode(toJson());

  static LayoutProfile? decode(String json) {
    try {
      return LayoutProfile.fromJson(jsonDecode(json));
    } catch (_) {
      return null;
    }
  }
}
