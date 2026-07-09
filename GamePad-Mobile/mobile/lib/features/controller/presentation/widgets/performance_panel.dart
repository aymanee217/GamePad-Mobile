import 'package:flutter/material.dart';
import '../../../../core/network/performance_monitor.dart';

/// Displays real-time network performance metrics.
class PerformancePanel extends StatelessWidget {
  final MetricsSnapshot metrics;

  const PerformancePanel({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Performance',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _row('Packets sent', '${metrics.packetsSent}'),
            _row('Packet rate', '${metrics.packetRate} pkt/s'),
            _row('RTT (last)', '${metrics.lastRttMs} ms',
                valueColor: _rttColor(metrics.lastRttMs)),
            _row('RTT (avg / min / max)',
                '${metrics.avgRttMs} / ${metrics.minRttMs} / ${metrics.maxRttMs} ms'),
            _row('Pongs received', '${metrics.pongsReceived}'),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
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
