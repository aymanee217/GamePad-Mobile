import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/connection_provider.dart';
import '../../providers/layout_provider.dart';
import '../../providers/bluetooth_hid_provider.dart';
import '../../../../core/model/button_layout_item.dart';
import '../widgets/performance_panel.dart';
import '../widgets/gamepad_layout.dart';

class ControllerScreen extends ConsumerWidget {
  const ControllerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionProvider);
    final layout = ref.watch(layoutProvider);
    final hidState = ref.watch(hidProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(connectionProvider.notifier).tryAutoReconnect();
      ref.read(layoutProvider.notifier).load();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('GamePad Mobile'),
        centerTitle: true,
        actions: [
          Icon(
            connection.phase == ConnectionPhase.connected
                ? Icons.wifi
                : Icons.wifi_off,
            color: connection.phase == ConnectionPhase.connected
                ? Colors.green
                : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 4),
          // Bluetooth HID indicator / toggle
          _HidButton(hidState: hidState),
          const SizedBox(width: 4),
          // Edit mode toggle
          IconButton(
            icon: Icon(
              layout.editMode ? Icons.check : Icons.tune,
              color: layout.editMode ? Colors.cyanAccent : null,
            ),
            onPressed: () => ref.read(layoutProvider.notifier).toggleEditMode(),
            tooltip: layout.editMode ? 'Done editing' : 'Customize layout',
          ),
        ],
      ),
      body: Column(
        children: [
          if (!layout.editMode) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: ConnectionTile(
                state: connection,
                onConnect: () => ref.read(connectionProvider.notifier).connect(),
                onDisconnect: () => ref.read(connectionProvider.notifier).disconnect(),
                onRetry: () => ref.read(connectionProvider.notifier).connect(),
              ),
            ),
            if (connection.phase == ConnectionPhase.connected)
              PerformancePanel(metrics: connection.metrics),
          ],
          Expanded(child: layout.editMode ? const _EditorPanel() : const GamepadLayout()),
        ],
      ),
    );
  }
}

/// Bottom panel shown in edit mode with size / opacity sliders + save/reset.
class _EditorPanel extends ConsumerWidget {
  const _EditorPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(layoutProvider);
    final selected = layout.selectedControl;
    final item = selected != null ? layout.find(selected) : null;

    return Column(
      children: [
        // Layout area
        const Expanded(child: GamepadLayout()),
        // Controls
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selected != null
                    ? 'Editing: ${_label(selected)}'
                    : 'Tap a button to edit',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (item != null) ...[
                const SizedBox(height: 8),
                _slider('Size', item.scale, 0.5, 2.0, (v) {
                  ref.read(layoutProvider.notifier).resizeControl(selected!, v);
                }),
                _slider('Opacity', item.opacity, 0.2, 1.0, (v) {
                  ref.read(layoutProvider.notifier).changeOpacity(selected!, v);
                }),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => ref.read(layoutProvider.notifier).save(),
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('Save'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => ref.read(layoutProvider.notifier).reset(),
                    icon: const Icon(Icons.restore, size: 16),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 36, child: Text(value.toStringAsFixed(2), style: const TextStyle(fontSize: 12))),
      ],
    );
  }

  String _label(ControlId id) {
    if (id.type == ControlType.joystick) return 'Joystick ${id.name == 'left' ? 'L' : 'R'}';
    if (id.type == ControlType.trigger) return 'Trigger ${id.name.toUpperCase()}';
    return 'Button ${id.name.toUpperCase()}';
  }
}

/// Bluetooth HID toggle button in the app bar.
class _HidButton extends ConsumerWidget {
  final HidState hidState;

  const _HidButton({required this.hidState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = hidState.connected;

    IconData icon;
    Color color;
    String tooltip;
    VoidCallback? onPressed;

    switch (hidState.status) {
      case HidStatus.idle:
      case HidStatus.initializing:
        icon = Icons.bluetooth_disabled;
        color = Colors.grey;
        tooltip = 'Bluetooth HID — tap to connect';
        onPressed = () => ref.read(hidProvider.notifier).init();
        break;
      case HidStatus.unsupported:
        icon = Icons.bluetooth_disabled;
        color = Colors.red.withValues(alpha: 0.4);
        tooltip = 'Bluetooth HID not supported';
        onPressed = null;
        break;
      case HidStatus.error:
        icon = Icons.bluetooth;
        color = Colors.red;
        tooltip = hidState.error ?? 'HID error';
        onPressed = () => ref.read(hidProvider.notifier).init();
        break;
      case HidStatus.ready:
        if (connected) {
          icon = Icons.bluetooth_connected;
          color = Colors.blue;
          tooltip = 'Bluetooth HID — connected';
          onPressed = () => ref.read(hidProvider.notifier).disconnect();
        } else {
          icon = Icons.bluetooth_searching;
          color = Colors.orange;
          tooltip = 'Bluetooth HID — waiting for PC to connect';
          onPressed = null;
        }
        break;
    }

    return IconButton(
      icon: Icon(icon, color: color, size: 20),
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }
}

class ConnectionTile extends StatelessWidget {
  final ConnectionState state;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onRetry;

  const ConnectionTile({
    super.key,
    required this.state,
    required this.onConnect,
    required this.onDisconnect,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phase = state.phase;

    Widget icon;
    String text;
    Color color;
    Widget? action;

    switch (phase) {
      case ConnectionPhase.disconnected:
        icon = const Icon(Icons.wifi_off, size: 16, color: Colors.red);
        text = 'Disconnected';
        color = Colors.red;
        action = TextButton.icon(
          onPressed: onConnect,
          icon: const Icon(Icons.search, size: 14),
          label: const Text('Discover', style: TextStyle(fontSize: 12)));
        break;
      case ConnectionPhase.discovering:
        icon = const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
        text = 'Scanning...';
        color = Colors.orange;
        action = null;
        break;
      case ConnectionPhase.discovered:
        icon = const Icon(Icons.cloud_done, size: 16, color: Colors.lightBlue);
        text = 'Found ${state.serverName ?? "PC"}';
        color = Colors.lightBlue;
        action = TextButton.icon(
          onPressed: onConnect,
          icon: const Icon(Icons.link, size: 14),
          label: const Text('Connect', style: TextStyle(fontSize: 12)));
        break;
      case ConnectionPhase.connecting:
        icon = const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
        text = 'Connecting...';
        color = Colors.orange;
        action = null;
        break;
      case ConnectionPhase.connected:
        icon = const Icon(Icons.wifi, size: 16, color: Colors.green);
        text = '${state.serverName ?? state.host}';
        color = Colors.green;
        action = TextButton.icon(
          onPressed: onDisconnect,
          icon: const Icon(Icons.close, size: 14),
          label: const Text('Disconnect', style: TextStyle(fontSize: 12)));
        break;
      case ConnectionPhase.failed:
        icon = const Icon(Icons.error_outline, size: 16, color: Colors.red);
        text = 'No server found';
        color = Colors.red;
        action = TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 14),
          label: const Text('Retry', style: TextStyle(fontSize: 12)));
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        icon,
        const SizedBox(width: 4),
        Text(text, style: theme.textTheme.bodySmall?.copyWith(color: color)),
        if (action != null) ...[const SizedBox(width: 4), action],
      ],
    );
  }
}
