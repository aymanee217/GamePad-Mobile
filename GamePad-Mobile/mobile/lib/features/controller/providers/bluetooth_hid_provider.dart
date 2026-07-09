import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/service/bluetooth_hid_service.dart';
import '../../../core/protocol/enums.dart';
import 'button_provider.dart';
import 'axis_state_provider.dart';

final bluetoothHidServiceProvider = Provider<BluetoothHidService>((ref) {
  final service = BluetoothHidService();
  ref.onDispose(() => service.dispose());
  return service;
});

enum HidStatus { idle, unsupported, initializing, ready, error }

class HidState {
  final HidStatus status;
  final String? error;
  final bool connected;

  const HidState({
    this.status = HidStatus.idle,
    this.error,
    this.connected = false,
  });

  HidState copyWith({HidStatus? status, String? error, bool? connected}) {
    return HidState(
      status: status ?? this.status,
      error: error ?? this.error,
      connected: connected ?? this.connected,
    );
  }
}

class HidNotifier extends StateNotifier<HidState> {
  final BluetoothHidService _service;
  final Ref _ref;
  Timer? _reportTimer;
  StreamSubscription? _connSub;

  HidNotifier(this._service, this._ref) : super(const HidState());

  Future<void> init() async {
    state = state.copyWith(status: HidStatus.initializing);

    final supported = await _service.isSupported();
    if (!supported) {
      state = state.copyWith(
        status: HidStatus.unsupported,
        error: 'Bluetooth HID not supported on this device',
      );
      return;
    }

    final error = await _service.init();
    if (error != null) {
      state = state.copyWith(status: HidStatus.error, error: error);
      return;
    }

    _connSub = _service.connectionStream.listen((connState) {
      final connected = connState == BthConnectionState.connected;
      state = state.copyWith(
        connected: connected,
        status: connected ? HidStatus.ready : HidStatus.idle,
      );
      if (connected) {
        startReporting();
      } else {
        stopReporting();
      }
    });
  }

  void startReporting() {
    _reportTimer?.cancel();
    _reportTimer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      _sendReport();
    });
  }

  void stopReporting() {
    _reportTimer?.cancel();
    _reportTimer = null;
  }

  void _sendReport() {
    if (state.status != HidStatus.ready || !state.connected) return;

    final btnState = _ref.read(buttonProvider);
    final axisState = _ref.read(axisStateProvider);
    final report = _buildReport(btnState, axisState);
    _service.sendReport(report);
  }

  /// Builds a 9-byte HID input report matching the descriptor.
  List<int> _buildReport(ButtonStateMap buttons, AxisState axis) {
    final report = List<int>.filled(9, 0);

    // Byte 0–1: buttons (16 bits)
    if (buttons.isPressed(ButtonId.a)) report[0] |= 0x01;
    if (buttons.isPressed(ButtonId.b)) report[0] |= 0x02;
    if (buttons.isPressed(ButtonId.x)) report[0] |= 0x04;
    if (buttons.isPressed(ButtonId.y)) report[0] |= 0x08;
    if (buttons.isPressed(ButtonId.lb)) report[0] |= 0x10;
    if (buttons.isPressed(ButtonId.rb)) report[0] |= 0x20;
    if (buttons.isPressed(ButtonId.select)) report[0] |= 0x40;
    if (buttons.isPressed(ButtonId.start)) report[0] |= 0x80;
    if (buttons.isPressed(ButtonId.guide)) report[1] |= 0x01;
    if (buttons.isPressed(ButtonId.l3)) report[1] |= 0x02;
    if (buttons.isPressed(ButtonId.r3)) report[1] |= 0x04;

    // Byte 2: hat switch (D-Pad)
    final up = buttons.isPressed(ButtonId.dPadUp);
    final down = buttons.isPressed(ButtonId.dPadDown);
    final left = buttons.isPressed(ButtonId.dPadLeft);
    final right = buttons.isPressed(ButtonId.dPadRight);

    if (up && right) {
      report[2] = 0x01;
    } else if (right && down) {
      report[2] = 0x03;
    } else if (down && left) {
      report[2] = 0x05;
    } else if (left && up) {
      report[2] = 0x07;
    } else if (up) {
      report[2] = 0x00;
    } else if (right) {
      report[2] = 0x02;
    } else if (down) {
      report[2] = 0x04;
    } else if (left) {
      report[2] = 0x06;
    } else {
      report[2] = 0x08;
    }

    // Byte 3–6: joysticks (scale 16-bit → 8-bit signed)
    report[3] = (axis.lx >> 8).clamp(-127, 127);
    report[4] = (-(axis.ly) >> 8).clamp(-127, 127); // invert Y for Xbox
    report[5] = (axis.rx >> 8).clamp(-127, 127);
    report[6] = (-(axis.ry) >> 8).clamp(-127, 127);

    // Byte 7–8: triggers (0–255, already 0-255 from widget)
    report[7] = axis.lt.clamp(0, 255);
    report[8] = axis.rt.clamp(0, 255);

    return report;
  }

  Future<void> disconnect() async {
    stopReporting();
    await _service.disconnect();
    _connSub?.cancel();
    state = const HidState();
  }

  @override
  void dispose() {
    stopReporting();
    _connSub?.cancel();
    super.dispose();
  }
}

final hidProvider = StateNotifierProvider<HidNotifier, HidState>((ref) {
  final service = ref.watch(bluetoothHidServiceProvider);
  return HidNotifier(service, ref);
});
