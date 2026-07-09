import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/protocol/enums.dart' show ButtonId;
import '../../../core/protocol/packet_encoder.dart';
import 'connection_provider.dart';

/// Tracks the press state of every button.
class ButtonStateMap {
  final Map<ButtonId, bool> _pressed = {};
  final Map<ButtonId, bool> _longPressed = {};

  bool isPressed(ButtonId id) => _pressed[id] ?? false;
  bool isLongPressed(ButtonId id) => _longPressed[id] ?? false;

  void press(ButtonId id) {
    _pressed[id] = true;
  }

  void release(ButtonId id) {
    _pressed[id] = false;
    _longPressed[id] = false;
  }

  void longPress(ButtonId id) {
    _longPressed[id] = true;
  }
}

/// Notifier that handles press / release / long-press and sends UDP.
class ButtonNotifier extends StateNotifier<ButtonStateMap> {
  final Ref _ref;
  final PacketEncoder _encoder;

  ButtonNotifier(this._ref, this._encoder) : super(ButtonStateMap());

  void onButtonDown(ButtonId buttonId) {
    state.press(buttonId);
    state = ButtonStateMap();
    final packet = _encoder.encodeButtonPress(buttonId);
    _ref.read(connectionProvider.notifier).send(packet.toBytes());
  }

  void onButtonLongPress(ButtonId buttonId) {
    state.longPress(buttonId);
    state = ButtonStateMap();
    final packet = _encoder.encodeButtonLongPress(buttonId);
    _ref.read(connectionProvider.notifier).send(packet.toBytes());
  }

  void onButtonUp(ButtonId buttonId) {
    state.release(buttonId);
    state = ButtonStateMap();
    final packet = _encoder.encodeButtonRelease(buttonId);
    _ref.read(connectionProvider.notifier).send(packet.toBytes());
  }
}

final buttonProvider =
    StateNotifierProvider<ButtonNotifier, ButtonStateMap>((ref) {
  final encoder = ref.watch(packetEncoderProvider);
  return ButtonNotifier(ref, encoder);
});
