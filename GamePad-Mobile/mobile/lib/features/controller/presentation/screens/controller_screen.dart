import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/connection_provider.dart';
import '../../../../core/model/button_layout_item.dart';
import '../widgets/gamepad_layout.dart';

/// Fullscreen controller screen - nothing visible except the gamepad.
/// Tap top-left corner to go back to profile selection.
class ControllerScreen extends ConsumerStatefulWidget {
  final LayoutProfile profile;
  final int profileIndex;

  const ControllerScreen({
    super.key,
    required this.profile,
    required this.profileIndex,
  });

  @override
  ConsumerState<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends ConsumerState<ControllerScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(connectionProvider.notifier).tryAutoReconnect();
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(child: GamepadLayout()),

          // Tiny connection dot (top-right)
          Positioned(
            top: 8,
            right: 8,
            child: Builder(
              builder: (context) {
                final connection = ref.watch(connectionProvider);
                return Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connection.phase == ConnectionPhase.connected
                        ? Colors.green
                        : connection.phase == ConnectionPhase.connecting
                            ? Colors.orange
                            : Colors.red,
                  ),
                );
              },
            ),
          ),

          // Back button (top-left corner)
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: GestureDetector(
                onTap: () {
                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white54,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
