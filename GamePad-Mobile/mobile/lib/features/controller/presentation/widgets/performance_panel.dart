import 'package:flutter/material.dart';
import '../../../../core/network/performance_monitor.dart';

/// Compact performance metrics displayed as a small tappable chip.
/// Expands into an overlay popup when tapped, so it never blocks the controller.
class PerformancePanel extends StatefulWidget {
  final MetricsSnapshot metrics;

  const PerformancePanel({super.key, required this.metrics});

  @override
  State<PerformancePanel> createState() => _PerformancePanelState();
}

class _PerformancePanelState extends State<PerformancePanel> {
  OverlayEntry? _overlay;

  void _toggle() {
    if (_overlay != null) {
      _overlay!.remove();
      _overlay = null;
      return;
    }
    _overlay = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + kToolbarHeight + 4,
        right: 8,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              _overlay?.remove();
              _overlay = null;
            },
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: _buildContent(Theme.of(ctx)),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  @override
  void dispose() {
    _overlay?.remove();
    _overlay = null;
    super.dispose();
  }

  Widget _buildContent(ThemeData theme) {
    final m = widget.metrics;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Performance', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        _row('TX', '${m.packetsSent} packets'),
        _row('Rate', '${m.packetRate} pkt/s'),
        _row('RTT', '${m.lastRttMs} ms', valueColor: _rttColor(m.lastRttMs)),
        _row('Avg/Min/Max', '${m.avgRttMs}/${m.minRttMs}/${m.maxRttMs} ms'),
        _row('Pongs', '${m.pongsReceived}'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;
    final rttColor = _rttColor(m.lastRttMs);

    return GestureDetector(
      onTap: _toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              '${m.packetRate} pkt/s',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 8),
            Text(
              '${m.lastRttMs}ms',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: rttColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: valueColor),
          ),
        ],
      ),
    );
  }

  Color? _rttColor(int ms) {
    if (ms == 0) return null;
    if (ms < 5) return Colors.green;
    if (ms < 15) return Colors.orange;
    return Colors.red;
  }
}
