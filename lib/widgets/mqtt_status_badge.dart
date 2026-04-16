import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/feature_config.dart';
import '../providers/device_provider.dart';

/// Badge nhỏ hiển thị trạng thái kết nối MQTT.
/// Dùng trong AppBar hoặc bất kỳ widget nào.
///
/// - [compact] = true → chỉ icon + text ngắn (dùng trong AppBar)
/// - [compact] = false → card đầy đủ với host:port (dùng trong panel)
class MqttStatusBadge extends StatelessWidget {
  final bool compact;

  const MqttStatusBadge({super.key, this.compact = true});

  @override
  Widget build(BuildContext context) {
    final connected =
        context.watch<DeviceProvider>().mqttConnected;

    if (compact) {
      return _CompactBadge(connected: connected);
    }
    return _FullCard(connected: connected);
  }
}

// ── Compact badge (dùng trong AppBar) ───────────────────────────
class _CompactBadge extends StatelessWidget {
  final bool connected;
  const _CompactBadge({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: connected
          ? 'MQTT: ${FeatureConfig.mqttHost}:${FeatureConfig.mqttWsPort}'
          : 'MQTT: Chưa kết nối',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(connected: connected),
          const SizedBox(width: 4),
          Text(
            connected ? 'MQTT' : 'MQTT',
            style: TextStyle(
              fontSize: 12,
              color: connected ? Colors.green.shade700 : Colors.red.shade400,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full status card ─────────────────────────────────────────────
class _FullCard extends StatelessWidget {
  final bool connected;
  const _FullCard({required this.connected});

  @override
  Widget build(BuildContext context) {
    final color = connected ? Colors.green.shade700 : Colors.red.shade600;
    final bg = connected ? Colors.green.shade50 : Colors.red.shade50;
    final label = connected ? 'Đã kết nối' : 'Chưa kết nối';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          _Dot(connected: connected, size: 12),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MQTT Broker',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${FeatureConfig.mqttHost}:${FeatureConfig.mqttWsPort}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Indicator dot ────────────────────────────────────────────────
class _Dot extends StatelessWidget {
  final bool connected;
  final double size;

  const _Dot({required this.connected, this.size = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: connected ? Colors.green.shade600 : Colors.red.shade400,
        boxShadow: [
          BoxShadow(
            color: (connected ? Colors.green : Colors.red).withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
