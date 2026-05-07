// @file       more_mqtt_section.dart
// @brief      MQTT Console sub-tab — manual publish, live data and noti logs.

/* Imports ------------------------------------------------------------ */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../config/feature_config.dart';
import '../../../providers/device_provider.dart';
import '../../../providers/fleet_provider.dart';
import '../../../services/mqtt_service.dart';
import '../../../utils/date_utils.dart';
import '../../../widgets/mqtt_status_badge.dart';

/* Constants ---------------------------------------------------------- */
const int _kSentLogMaxEntries = 30;
const int _kLiveLogMaxEntries = 60;
const int _kVisibleLogEntries = 20;
const List<String> _kQuickCommands = ['LOCK', 'UNLOCK', 'RESET', 'KEEPALIVE'];

/* Public classes ----------------------------------------------------- */
class MoreMqttSection extends StatefulWidget {
  const MoreMqttSection({super.key});

  @override
  State<MoreMqttSection> createState() => _MoreMqttSectionState();
}

/* Private classes ---------------------------------------------------- */
class _MoreMqttSectionState extends State<MoreMqttSection> {
  final _topicCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final List<_SentEntry> _sentLog = [];
  final List<_LogEntry> _dataLog = [];
  final List<_LogEntry> _notiLog = [];

  StreamSubscription<MqttDataMessage>? _dataSub;
  StreamSubscription<MqttNotiMessage>? _notiSub;
  bool _subscribed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _subscribed) return;
      _subscribed = true;
      final mqtt = context.read<MqttService>();

      _dataSub = mqtt.dataMessages.listen((msg) {
        if (!mounted) return;
        setState(() {
          _dataLog.insert(
            0,
            _LogEntry(
              deviceId: msg.deviceId,
              text: msg.raw,
              time: DateTime.now(),
            ),
          );
          if (_dataLog.length > _kLiveLogMaxEntries) _dataLog.removeLast();
        });
      });

      _notiSub = mqtt.notifications.listen((msg) {
        if (!mounted) return;
        setState(() {
          _notiLog.insert(
            0,
            _LogEntry(
              deviceId: msg.deviceId,
              text: msg.message,
              time: DateTime.now(),
            ),
          );
          if (_notiLog.length > _kLiveLogMaxEntries) _notiLog.removeLast();
        });
      });
    });
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _notiSub?.cancel();
    _topicCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    final fleet = context.watch<FleetProvider>();
    final notiList = deviceProvider.notifications;
    final selectedId = fleet.selectedOrNull?.id;
    final filteredData = _dataLog
        .where((e) => selectedId == null || e.deviceId == selectedId)
        .take(_kVisibleLogEntries)
        .toList();
    final filteredNoti = _notiLog
        .where((e) => selectedId == null || e.deviceId == selectedId)
        .take(_kVisibleLogEntries)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---- Status card ----
        const MqttStatusBadge(compact: false),
        const SizedBox(height: 4),
        Text(
          'SSL: ${FeatureConfig.mqttUseSsl ? "Enabled (WSS)" : "Disabled (WS)"}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),

        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 4),

        // ---- Console ----
        const Text(
          'MQTT Console',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Topic field
        TextField(
          controller: _topicCtrl,
          decoration: const InputDecoration(
            labelText: 'Topic',
            hintText: 'haq-trk-001/cmd',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.topic_outlined),
            isDense: true,
          ),
          onSubmitted: (_) => _sendMessage(),
        ),
        const SizedBox(height: 10),

        // Message field
        TextField(
          controller: _messageCtrl,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Message',
            hintText: 'LOCK  /  UNLOCK  /  RESET  /  {"key":"value"}',
            border: OutlineInputBorder(),
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(Icons.message_outlined),
            ),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 10),

        // Quick-fill buttons
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final cmd in _kQuickCommands)
              ActionChip(
                label: Text(cmd, style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  _messageCtrl.text = cmd;
                  if (_topicCtrl.text.isEmpty &&
                      FeatureConfig.defaultDevices.isNotEmpty) {
                    _topicCtrl.text =
                        '${FeatureConfig.defaultDevices.first}/cmd';
                  }
                },
              ),
            for (final d in deviceProvider.devices)
              ActionChip(
                avatar: CircleAvatar(
                  backgroundColor: _hexColor(d.color).withValues(alpha: 0.85),
                  radius: 6,
                ),
                label: Text(d.id, style: const TextStyle(fontSize: 11)),
                onPressed: () => _topicCtrl.text = '${d.id}/cmd',
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Send button
        SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Send'),
          ),
        ),

        // ---- Sent log ----
        if (_sentLog.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                'Send History',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _sentLog.clear()),
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final entry in _sentLog) _SentLogTile(entry: entry),
        ],

        // ---- Received notifications ----
        if (notiList.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Received Notifications (/noti)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          for (final noti in notiList.take(_kVisibleLogEntries))
            _CopyableTile(
              icon: Icons.notifications_outlined,
              title: noti.message,
              subtitle: '${noti.deviceId}  •  ${AppDateUtils.formatTime(noti.receivedAt)}',
              copyText: noti.message,
            ),
        ],

        // ---- Live /data log ----
        const SizedBox(height: 20),
        Row(
          children: [
            const Text(
              'Live Data Log (/data)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _dataLog.clear()),
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Clear', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (filteredData.isEmpty)
          const Text(
            'No data received yet.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          )
        else
          for (final entry in filteredData)
            _CopyableTile(
              icon: Icons.data_object,
              title: entry.text,
              subtitle: '${entry.deviceId}  •  ${AppDateUtils.formatTime(entry.time)}',
              copyText: entry.text,
              monospace: true,
            ),

        // ---- Live /noti log ----
        const SizedBox(height: 20),
        Row(
          children: [
            const Text(
              'Live Noti Log (/noti)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _notiLog.clear()),
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Clear', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (filteredNoti.isEmpty)
          const Text(
            'No notifications received yet.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          )
        else
          for (final entry in filteredNoti)
            _CopyableTile(
              icon: Icons.notifications_outlined,
              title: entry.text,
              subtitle: '${entry.deviceId}  •  ${AppDateUtils.formatTime(entry.time)}',
              copyText: entry.text,
            ),
      ],
    );
  }

  void _sendMessage() {
    final messenger = ScaffoldMessenger.of(context);
    final topic = _topicCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (topic.isEmpty || message.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter both topic and message.')),
      );
      return;
    }

    final mqtt = context.read<MqttService>();
    final ok = mqtt.publishRaw(topic, message);

    setState(() {
      _sentLog.insert(
        0,
        _SentEntry(
          topic: topic,
          message: message,
          time: DateTime.now(),
          success: ok,
        ),
      );
      if (_sentLog.length > _kSentLogMaxEntries) _sentLog.removeLast();
    });

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Message sent → $topic' : 'Failed to send message (not connected)',
        ),
        backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade600,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static Color _hexColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

class _SentEntry {
  final String topic;
  final String message;
  final DateTime time;
  final bool success;

  const _SentEntry({
    required this.topic,
    required this.message,
    required this.time,
    required this.success,
  });
}

class _LogEntry {
  final String deviceId;
  final String text;
  final DateTime time;

  const _LogEntry({
    required this.deviceId,
    required this.text,
    required this.time,
  });
}

class _SentLogTile extends StatelessWidget {
  final _SentEntry entry;
  const _SentLogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final h = entry.time.hour.toString().padLeft(2, '0');
    final m = entry.time.minute.toString().padLeft(2, '0');
    final s = entry.time.second.toString().padLeft(2, '0');
    final timeStr = '$h:$m:$s';

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: entry.success ? null : Colors.red.shade50,
      child: ListTile(
        dense: true,
        leading: Icon(
          entry.success ? Icons.check_circle_outline : Icons.error_outline,
          size: 18,
          color: entry.success ? Colors.green.shade600 : Colors.red.shade400,
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blueGrey.shade200),
              ),
              child: Text(
                entry.topic,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.message,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Text(timeStr, style: const TextStyle(fontSize: 10)),
        trailing: IconButton(
          tooltip: 'Copy message',
          icon: const Icon(Icons.copy, size: 15),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: entry.message));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Copied to clipboard'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CopyableTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String copyText;
  final bool monospace;

  const _CopyableTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.copyText,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: Icon(icon, size: 18),
        title: Text(
          title,
          style: TextStyle(
            fontSize: monospace ? 12 : 13,
            fontFamily: monospace ? 'monospace' : null,
          ),
          overflow: monospace ? TextOverflow.ellipsis : null,
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: IconButton(
          tooltip: 'Copy',
          icon: const Icon(Icons.copy, size: 15),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: copyText));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Copied'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */
