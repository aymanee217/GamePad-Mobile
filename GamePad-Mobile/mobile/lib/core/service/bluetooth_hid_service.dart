import 'dart:async';
import 'package:flutter/services.dart';

enum BthConnectionState {
  disconnected,
  connecting,
  connected,
  failed,
}

class BluetoothHidService {
  static const _channel = MethodChannel('bluetooth_hid');

  final _connectionController = StreamController<BthConnectionState>.broadcast();
  Stream<BthConnectionState> get connectionStream => _connectionController.stream;

  bool _ready = false;
  bool get isReady => _ready;

  BluetoothHidService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onReady':
        _ready = true;
        _connectionController.add(BthConnectionState.connected);
      case 'onConnectionState':
        final state = call.arguments['state'] as String?;
        _connectionController.add(
          state == 'connected'
              ? BthConnectionState.connected
              : BthConnectionState.disconnected,
        );
    }
  }

  Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> init() async {
    try {
      await _channel.invokeMethod('init');
      return null;
    } on PlatformException catch (e) {
      return e.message ?? 'Unknown error';
    }
  }

  Future<String?> sendReport(List<int> data) async {
    if (!_ready) return 'HID not ready';
    try {
      await _channel.invokeMethod('sendReport', {'data': data});
      return null;
    } on PlatformException catch (e) {
      return e.message ?? 'Send failed';
    }
  }

  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
    } catch (_) {}
    _ready = false;
    _connectionController.add(BthConnectionState.disconnected);
  }

  void dispose() {
    _connectionController.close();
    disconnect();
  }
}
