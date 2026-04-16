import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/feature_config.dart';
import '../../models/app_note.dart';
import '../../models/employee_account.dart';
import '../../providers/auth_provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/fleet_provider.dart';
import '../../services/firebase_repo.dart';
import '../../services/mqtt_service.dart';
import '../../widgets/mqtt_status_badge.dart';
import '../../widgets/vehicle_picker.dart';

class MoreTab extends StatefulWidget {
  const MoreTab({super.key});

  @override
  State<MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<MoreTab> {
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  final _employeeCodeCtrl = TextEditingController();
  final _employeePasswordCtrl = TextEditingController();
  final _employeeConfirmPasswordCtrl = TextEditingController();

  // ---- MQTT console ----
  final _mqttTopicCtrl = TextEditingController();
  final _mqttMessageCtrl = TextEditingController();
  final List<_SentEntry> _sentLog = [];

  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;
  bool _hideEmployeePassword = true;
  bool _hideEmployeeConfirmPassword = true;
  bool _isSavingEmployee = false;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _employeeCodeCtrl.dispose();
    _employeePasswordCtrl.dispose();
    _employeeConfirmPasswordCtrl.dispose();
    _mqttTopicCtrl.dispose();
    _mqttMessageCtrl.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final mo = value.month.toString().padLeft(2, '0');
    final y = value.year.toString();
    return '$h:$m - $d/$mo/$y';
  }

  Future<void> _changePassword() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.changePassword(
      currentPassword: _currentPasswordCtrl.text,
      newPassword: _newPasswordCtrl.text,
      confirmPassword: _confirmPasswordCtrl.text,
    );

    if (!mounted) return;

    if (ok) {
      _currentPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đổi mật khẩu thành công.')),
      );
      return;
    }

    if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage!)),
      );
    }
  }

  Future<void> _addEmployeeAccount() async {
    final code = _employeeCodeCtrl.text.trim();
    final pass = _employeePasswordCtrl.text.trim();
    final confirm = _employeeConfirmPasswordCtrl.text.trim();

    if (code.isEmpty || pass.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đủ mã số và mật khẩu.')),
      );
      return;
    }

    if (pass.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu phải có ít nhất 4 ký tự.')),
      );
      return;
    }

    if (pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xác nhận mật khẩu chưa khớp.')),
      );
      return;
    }

    setState(() => _isSavingEmployee = true);
    try {
      final ok = await FirebaseRepo.instance.addEmployeeAccount(
        employeeCode: code,
        password: pass,
      );

      if (!mounted) return;

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mã nhân viên đã tồn tại hoặc dữ liệu chưa hợp lệ.'),
          ),
        );
        return;
      }

      _employeeCodeCtrl.clear();
      _employeePasswordCtrl.clear();
      _employeeConfirmPasswordCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm mã nhân viên đăng nhập.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingEmployee = false);
      }
    }
  }

  Future<void> _confirmDeleteEmployee(EmployeeAccount item) async {
    final auth = context.read<AuthProvider>();
    if (item.employeeCode == auth.employeeCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xóa mã nhân viên đang đăng nhập.'),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xóa mã nhân viên'),
            content: Text(
              'Bạn có chắc muốn xóa mã nhân viên ${item.employeeCode} không?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Xóa'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    final deleted = await FirebaseRepo.instance.deleteEmployeeAccount(
      item.employeeCode,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Đã xóa mã nhân viên ${item.employeeCode}.'
              : 'Không thể xóa mã nhân viên.',
        ),
      ),
    );
  }

  Future<void> _openNoteEditor({AppNote? note}) async {
    final titleCtrl = TextEditingController(text: note?.title ?? '');
    final contentCtrl = TextEditingController(text: note?.content ?? '');

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 700),
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sticky_note_2_outlined),
                      const SizedBox(width: 8),
                      Text(
                        note == null ? 'Ghi chú mới' : 'Chỉnh sửa ghi chú',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề ghi chú',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.blueGrey.shade100),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 8,
                            color: Color(0x11000000),
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: contentCtrl,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          hintText: 'Nhập nội dung ghi chú ở đây...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Hủy'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Lưu ghi chú'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result != true) {
      titleCtrl.dispose();
      contentCtrl.dispose();
      return;
    }

    final title = titleCtrl.text.trim();
    final content = contentCtrl.text.trim();
    titleCtrl.dispose();
    contentCtrl.dispose();

    if (content.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nội dung ghi chú không được để trống.')),
      );
      return;
    }

    if (note == null) {
      await FirebaseRepo.instance.createNote(title: title, content: content);
    } else {
      await FirebaseRepo.instance.updateNote(
        noteId: note.id,
        title: title,
        content: content,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(note == null ? 'Đã thêm ghi chú.' : 'Đã cập nhật ghi chú.'),
      ),
    );
  }

  Future<void> _deleteNote(AppNote note) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xóa ghi chú'),
            content: Text(
              'Bạn có chắc muốn xóa ghi chú "${note.title.isEmpty ? 'Không tiêu đề' : note.title}" không?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Xóa'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;
    await FirebaseRepo.instance.deleteNote(note.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã xóa ghi chú.')),
    );
  }

  Widget _buildInfoTab(FleetProvider fleet, AuthProvider auth) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 10),
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: const Text('Mã nhân viên đang đăng nhập'),
          trailing: Text(auth.employeeCode ?? '---'),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.directions_car_outlined),
          title: const Text('Số xe đang quản lí'),
          trailing: Text('${fleet.vehicles.length}'),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Gợi ý sử dụng',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Tab Ghi chú dùng để tạo nhiều ghi chú và xóa từng ghi chú.'),
                SizedBox(height: 4),
                Text('• Tab Nhân viên dùng để thêm mã số có thể đăng nhập web.'),
                SizedBox(height: 4),
                Text('• Tab Đổi mật khẩu dùng để đổi mật khẩu của tài khoản đang đăng nhập.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () {
            context.read<AuthProvider>().logout();
          },
          icon: const Icon(Icons.logout),
          label: const Text('Đăng xuất'),
        ),
      ],
    );
  }

  Widget _buildNotesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openNoteEditor(),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm ghi chú'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AppNote>>(
            stream: FirebaseRepo.instance.watchNotes(),
            builder: (context, snapshot) {
              final notes = snapshot.data ?? const <AppNote>[];
              if (notes.isEmpty) {
                return const Center(
                  child: Text('Chưa có ghi chú nào. Hãy bấm "Thêm ghi chú".'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  final title =
                      note.title.trim().isEmpty ? 'Không tiêu đề' : note.title;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Cập nhật: ${_formatDateTime(note.updatedAt)}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Sửa',
                                onPressed: () => _openNoteEditor(note: note),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Xóa',
                                onPressed: () => _deleteNote(note),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: Colors.blueGrey.shade100,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(note.content),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeesTab(AuthProvider auth) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 10),
        TextField(
          controller: _employeeCodeCtrl,
          decoration: const InputDecoration(
            labelText: 'Mã nhân viên mới',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _employeePasswordCtrl,
          obscureText: _hideEmployeePassword,
          decoration: InputDecoration(
            labelText: 'Mật khẩu cho mã nhân viên mới',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              onPressed: () {
                setState(
                  () => _hideEmployeePassword = !_hideEmployeePassword,
                );
              },
              icon: Icon(
                _hideEmployeePassword
                    ? Icons.visibility_off
                    : Icons.visibility,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _employeeConfirmPasswordCtrl,
          obscureText: _hideEmployeeConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Xác nhận mật khẩu',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.verified_user_outlined),
            suffixIcon: IconButton(
              onPressed: () {
                setState(
                  () => _hideEmployeeConfirmPassword =
                      !_hideEmployeeConfirmPassword,
                );
              },
              icon: Icon(
                _hideEmployeeConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isSavingEmployee ? null : _addEmployeeAccount,
            icon: _isSavingEmployee
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_alt_1),
            label: const Text('Thêm mã nhân viên đăng nhập'),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Danh sách mã nhân viên',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<EmployeeAccount>>(
          stream: FirebaseRepo.instance.watchEmployeeAccounts(),
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <EmployeeAccount>[];
            if (items.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Chưa có mã nhân viên nào.'),
                ),
              );
            }

            return Column(
              children: items.map((item) {
                final isCurrent = item.employeeCode == auth.employeeCode;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Icon(
                      isCurrent ? Icons.verified_user : Icons.badge_outlined,
                    ),
                    title: Text('Mã số ${item.employeeCode}'),
                    subtitle: Text(
                      isCurrent
                          ? 'Đang đăng nhập'
                          : 'Cập nhật: ${_formatDateTime(item.updatedAt)}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Xóa mã nhân viên',
                      onPressed: () => _confirmDeleteEmployee(item),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildChangePasswordTab(AuthProvider auth) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 10),
        TextField(
          controller: _currentPasswordCtrl,
          obscureText: _hideCurrent,
          decoration: InputDecoration(
            labelText: 'Mật khẩu hiện tại',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() => _hideCurrent = !_hideCurrent);
              },
              icon: Icon(
                _hideCurrent ? Icons.visibility_off : Icons.visibility,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _newPasswordCtrl,
          obscureText: _hideNew,
          decoration: InputDecoration(
            labelText: 'Mật khẩu mới',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.password_outlined),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() => _hideNew = !_hideNew);
              },
              icon: Icon(_hideNew ? Icons.visibility_off : Icons.visibility),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordCtrl,
          obscureText: _hideConfirm,
          decoration: InputDecoration(
            labelText: 'Xác nhận mật khẩu mới',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.verified_user_outlined),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() => _hideConfirm = !_hideConfirm);
              },
              icon: Icon(
                _hideConfirm ? Icons.visibility_off : Icons.visibility,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: auth.isLoading ? null : _changePassword,
            icon: auth.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Cập nhật mật khẩu'),
          ),
        ),
      ],
    );
  }

  // ================================================================
  //  MQTT Console tab
  // ================================================================

  void _sendMqttMessage() {
    final topic = _mqttTopicCtrl.text.trim();
    final message = _mqttMessageCtrl.text.trim();
    if (topic.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập topic và message.')),
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
      if (_sentLog.length > 30) _sentLog.removeLast();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Đã gửi → $topic' : 'Gửi thất bại (chưa kết nối)'),
        backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade600,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildMqttTab() {
    final deviceProvider = context.watch<DeviceProvider>();
    final notiList = deviceProvider.notifications;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---- Status card ----
        const MqttStatusBadge(compact: false),
        const SizedBox(height: 4),
        Text(
          'SSL: ${FeatureConfig.mqttUseSsl ? "Bật (WSS)" : "Tắt (WS)"}',
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
          controller: _mqttTopicCtrl,
          decoration: const InputDecoration(
            labelText: 'Topic',
            hintText: 'haq-trk-001/cmd',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.topic_outlined),
            isDense: true,
          ),
          onSubmitted: (_) => _sendMqttMessage(),
        ),
        const SizedBox(height: 10),

        // Message field
        TextField(
          controller: _mqttMessageCtrl,
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
            for (final cmd in ['LOCK', 'UNLOCK', 'RESET', 'KEEPALIVE'])
              ActionChip(
                label: Text(cmd, style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  _mqttMessageCtrl.text = cmd;
                  // Set default topic = first device /cmd if empty
                  if (_mqttTopicCtrl.text.isEmpty &&
                      FeatureConfig.defaultDevices.isNotEmpty) {
                    _mqttTopicCtrl.text =
                        '${FeatureConfig.defaultDevices.first}/cmd';
                  }
                },
              ),
            // Fill with device IDs from registry
            for (final d in deviceProvider.devices)
              ActionChip(
                avatar: CircleAvatar(
                  backgroundColor:
                      _hexColor(d.color).withValues(alpha: 0.85),
                  radius: 6,
                ),
                label: Text(
                  d.id,
                  style: const TextStyle(fontSize: 11),
                ),
                onPressed: () {
                  _mqttTopicCtrl.text = '${d.id}/cmd';
                },
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Send button
        SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: _sendMqttMessage,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Gửi'),
          ),
        ),

        // ---- Sent log ----
        if (_sentLog.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                'Lịch sử gửi',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _sentLog.clear()),
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Xóa', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final entry in _sentLog)
            _SentLogTile(entry: entry),
        ],

        // ---- Received notifications ----
        if (notiList.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Notifications nhận được (/noti)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          for (final noti in notiList.take(20))
            Card(
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.notifications_outlined, size: 18),
                title: Text(
                  noti.message,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  '${noti.deviceId}  •  ${_fmtTime(noti.receivedAt)}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy, size: 15),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: noti.message));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã copy'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ],
    );
  }

  static Color _hexColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  static String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ================================================================
  //  Build
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    final auth = context.watch<AuthProvider>();

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thông tin khác'),
          actions: [
            const MqttStatusBadge(compact: true),
            const SizedBox(width: 8),
            const VehiclePicker(),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Thông tin'),
              Tab(text: 'Ghi chú'),
              Tab(text: 'Nhân viên'),
              Tab(text: 'Đổi mật khẩu'),
              Tab(text: 'MQTT'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildInfoTab(fleet, auth),
            _buildNotesTab(),
            _buildEmployeesTab(auth),
            _buildChangePasswordTab(auth),
            _buildMqttTab(),
          ],
        ),
      ),
    );
  }
}

// ================================================================
//  Helper classes
// ================================================================

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
        subtitle: Text(
          timeStr,
          style: const TextStyle(fontSize: 10),
        ),
        trailing: IconButton(
          tooltip: 'Copy message',
          icon: const Icon(Icons.copy, size: 15),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: entry.message));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã copy'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
      ),
    );
  }
}
