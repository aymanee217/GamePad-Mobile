/// Message types used in the GamePad binary protocol.
enum MessageType {
  buttonEvent(0x01),
  discovery(0x02),
  discoveryResponse(0x03),
  axisEvent(0x04),
  vibration(0x05),
  macroEvent(0x06),
  ping(0x07),
  pong(0x08),
  triggerEvent(0x09);

  final int value;
  const MessageType(this.value);

  static MessageType fromValue(int value) {
    return MessageType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MessageType.buttonEvent,
    );
  }
}

/// Identifiers for every physical/virtual button on the controller.
enum ButtonId {
  a(0x01),
  b(0x02),
  x(0x03),
  y(0x04),
  lb(0x05),
  rb(0x06),
  lt(0x07),
  rt(0x08),
  start(0x09),
  select(0x0A),
  guide(0x0B),
  dPadUp(0x0C),
  dPadDown(0x0D),
  dPadLeft(0x0E),
  dPadRight(0x0F),
  l3(0x10),
  r3(0x11);

  final int value;
  const ButtonId(this.value);
}

/// Binary state of a button.
enum ButtonState {
  released(0x00),
  pressed(0x01),
  longPressed(0x02);

  final int value;
  const ButtonState(this.value);
}

/// Identifies which analog stick.
enum StickId {
  left(0x01),
  right(0x02);

  final int value;
  const StickId(this.value);
}

/// Identifies an analog trigger.
enum TriggerId {
  l2(0x01),
  r2(0x02);

  final int value;
  const TriggerId(this.value);
}
