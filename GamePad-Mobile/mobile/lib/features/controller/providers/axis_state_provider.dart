import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the latest analog values from joysticks and triggers.
class AxisState {
  final int lx;
  final int ly;
  final int rx;
  final int ry;
  final int lt;
  final int rt;

  const AxisState({
    this.lx = 0,
    this.ly = 0,
    this.rx = 0,
    this.ry = 0,
    this.lt = 0,
    this.rt = 0,
  });
}

final axisStateProvider = StateProvider<AxisState>((ref) => const AxisState());
