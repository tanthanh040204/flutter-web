// @file       more_tab.dart
// @brief      Tab UI for More.

/* Imports ------------------------------------------------------------ */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/feature_config.dart';
import '../../models/app_note.dart';
import '../../models/employee_account.dart';
import '../../providers/auth_provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/fleet_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/firebase_repo.dart';
import '../../services/mqtt_service.dart';
import '../../widgets/mqtt_status_badge.dart';
import '../../widgets/vehicle_picker.dart';

/* Public classes ----------------------------------------------------- */
class MoreTab extends StatefulWidget {
  const MoreTab({super.key});

  @override
  State<MoreTab> createState() => _MoreTabState();
}

/* Private classes ---------------------------------------------------- */
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

  // ---- MQTT live data/noti log (populated in initState) ----
  final List<_LogEntry> _dataLog = [];
  final List<_LogEntry> _notiLog = [];
  StreamSubscription<MqttDataMessage>? _dataSub;
  StreamSubscription<MqttNotiMessage>? _notiSub;
  bool _logsInited = false;

  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;
  bool _hideEmployeePassword = true;
  bool _hideEmployeeConfirmPassword = true;
  bool _isSavingEmployee = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _logsInited) return;
      _logsInited = true;
      final mqtt = context.read<MqttService>();

      _dataSub = mqtt.dataMessages.listen((msg) {
        if (!mounted) return;
        setState(() {
          _dataLog.insert(0, _LogEntry(
            deviceId: msg.deviceId,
            text: msg.raw,
            time: DateTime.now(),
          ));
          if (_dataLog.length > 60) _dataLog.removeLast();
        });
      });

      _notiSub = mqtt.notifications.listen((msg) {
        if (!mounted) return;
        setState(() {
          _notiLog.insert(0, _LogEntry(
            deviceId: msg.deviceId,
            text: msg.message,
            time: DateTime.now(),
          ));
          if (_notiLog.length > 60) _notiLog.removeLast();
        });
      });
    });
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _notiSub?.cancel();
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
        SnackBar(content: Text(context.tr('Đổi mật khẩu thành công.', 'Password changed successfully.'))),
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
        SnackBar(content: Text(context.tr('Vui lòng nhập đầy đủ thông tin.', 'Please fill in all fields.'))),
      );
      return;
    }

    if (pass.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Mật khẩu phải có ít nhất 4 ký tự.', 'Password must be at least 4 characters long.'))),
      );
      return;
    }

    if (pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Xác nhận mật khẩu không khớp.', 'Password confirmation does not match.'))),
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
          SnackBar(
            content: Text(context.tr('Mã nhân viên đã tồn tại hoặc dữ liệu không hợp lệ.', 'Employee code already exists or data is invalid.')),
          ),
        );
        return;
      }

      _employeeCodeCtrl.clear();
      _employeePasswordCtrl.clear();
      _employeeConfirmPasswordCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Đã thêm mã nhân viên.', 'Employee account added successfully.'))),
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
        SnackBar(
          content: Text(context.tr('Không thể xóa mã nhân viên đang đăng nhập.', 'Cannot delete the employee code currently logged in.')),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr('Xóa mã nhân viên', 'Delete Employee Code')),
            content: Text(
              context.tr('Bạn có chắc muốn xóa mã nhân viên ${item.employeeCode}?', 'Are you sure you want to delete employee code ${item.employeeCode}?'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.tr('Hủy', 'Cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.tr('Xóa', 'Delete')),
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
              ? context.tr('Đã xóa mã nhân viên ${item.employeeCode}.', 'Employee code ${item.employeeCode} deleted successfully.')
              : context.tr('Không xóa được mã nhân viên.', 'Failed to delete employee code.')
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
                        note == null ? context.tr('Ghi chú mới', 'New Note') : context.tr('Sửa ghi chú', 'Edit Note'),
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
                    decoration: InputDecoration(
                      labelText: context.tr('Tiêu đề ghi chú', 'Note Title'),
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
                        decoration: InputDecoration(
                          hintText: context.tr('Nhập nội dung ghi chú tại đây...', 'Enter note content here...'),
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
                        child: Text(context.tr('Hủy', 'Cancel')),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.save_outlined),
                        label: Text(context.tr('Lưu ghi chú', 'Save Note')),
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
        SnackBar(content: Text(context.tr('Nội dung ghi chú không được để trống.', 'Note content cannot be empty.'))) ,
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
        content: Text(note == null ? context.tr('Đã thêm ghi chú.', 'Note added successfully.') : context.tr('Đã cập nhật ghi chú.', 'Note updated successfully.')),
      ),
    );
  }

  Future<void> _deleteNote(AppNote note) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr('Xóa ghi chú', 'Delete Note')),
            content: Text(
              context.tr('Bạn có chắc muốn xóa ghi chú "${note.title.isEmpty ? 'Không có tiêu đề' : note.title}"?', 'Are you sure you want to delete the note "${note.title.isEmpty ? 'Untitled' : note.title}"?'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.tr('Hủy', 'Cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.tr('Xóa', 'Delete')),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;
    await FirebaseRepo.instance.deleteNote(note.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('Đã xóa ghi chú.', 'Note deleted successfully.'))),
    );
  }

  Widget _buildInfoTab(FleetProvider fleet, AuthProvider auth) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 10),
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: Text(context.tr('Mã nhân viên đang đăng nhập', 'Current employee code')),
          trailing: Text(auth.employeeCode ?? '---'),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.directions_car_outlined),
          title: Text(context.tr('Số xe đang quản lí', 'Managed vehicles')),
          trailing: Text('${fleet.vehicles.length}'),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Gợi ý sử dụng', 'Usage tips'),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(context.tr('• Tab Thông báo dùng để xem thông báo từ thiết bị.', '• Notifications tab shows messages from devices.')),
                const SizedBox(height: 4),
                Text(context.tr('• Tab Ghi chú dùng để tạo và quản lý ghi chú.', '• Notes tab is for creating and managing notes.')),
                const SizedBox(height: 4),
                Text(context.tr('• Tab đổi mật khẩu dùng để cập nhật mật khẩu đăng nhập.', '• Change password tab updates your login password.')),
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
          label: Text(context.tr('Đăng xuất', 'Logout')),
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
                  label: Text(context.tr('Thêm ghi chú', 'Add Note')),
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
                return Center(
                  child: Text(context.tr('Chưa có ghi chú. Bấm "Thêm ghi chú" để tạo mới.', 'No notes available. Press "Add Note" to create one.')),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  final title =
                      note.title.trim().isEmpty ? context.tr('Không có tiêu đề', 'No title') : note.title;
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
                                      context.tr('Cập nhật: ${_formatDateTime(note.updatedAt)}', 'Updated: ${_formatDateTime(note.updatedAt)}'),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: context.tr('Sửa', 'Edit'),
                                onPressed: () => _openNoteEditor(note: note),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: context.tr('Xóa', 'Delete'),
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
          decoration: InputDecoration(
            labelText: context.tr('Mã nhân viên mới', 'New Employee Code'),
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _employeePasswordCtrl,
          obscureText: _hideEmployeePassword,
          decoration: InputDecoration(
            labelText: context.tr('Mật khẩu cho mã nhân viên mới', 'Password for New Employee Code'),
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
            labelText: context.tr('Xác nhận mật khẩu', 'Confirm Password'),
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
            label: Text(context.tr('Thêm mã nhân viên', 'Add Employee Code')),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          context.tr('Danh sách mã nhân viên', 'Employee Codes List'),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<EmployeeAccount>>(
          stream: FirebaseRepo.instance.watchEmployeeAccounts(),
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <EmployeeAccount>[];
            if (items.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(context.tr('Chưa có mã nhân viên.', 'No employee codes available.')),
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
                    title: Text(context.tr('Mã nhân viên: ${item.employeeCode}', 'Employee Code: ${item.employeeCode}')),
                    subtitle: Text(
                      isCurrent
                          ? context.tr('Đang đăng nhập', 'Currently logged in')
                          : context.tr('Cập nhật: ${_formatDateTime(item.updatedAt)}', 'Updated: ${_formatDateTime(item.updatedAt)}'),
                    ),
                    trailing: IconButton(
                      tooltip: context.tr('Xóa mã nhân viên', 'Delete Employee Code'),
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
            labelText: context.tr('Mật khẩu hiện tại', 'Current Password'),
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
            labelText: context.tr('Mật khẩu mới', 'New Password'),
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
            labelText: context.tr('Xác nhận mật khẩu mới', 'Confirm New Password'),
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
            label: Text(context.tr('Cập nhật mật khẩu', 'Update Password')),
          ),
        ),
      ],
    );
  }


  Widget _buildLanguageTab() {
    final language = context.watch<LanguageProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.translate_outlined),
                    const SizedBox(width: 10),
                    Text(
                      context.tr('Ngôn ngữ hiển thị', 'Display language'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'Chọn ngôn ngữ cho giao diện web. Một vài dữ liệu lấy trực tiếp từ Firebase/MQTT sẽ giữ nguyên theo nội dung đã lưu.',
                    'Choose the language for the web interface. Some values coming directly from Firebase/MQTT will remain exactly as stored.',
                  ),
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        RadioListTile<AppLanguage>(
          value: AppLanguage.vi,
          groupValue: language.language,
          onChanged: (value) {
            if (value != null) context.read<LanguageProvider>().setLanguage(value);
          },
          secondary: const Text('🇻🇳', style: TextStyle(fontSize: 24)),
          title: const Text('Tiếng Việt'),
          subtitle: const Text('Giao diện tiếng Việt'),
        ),
        RadioListTile<AppLanguage>(
          value: AppLanguage.en,
          groupValue: language.language,
          onChanged: (value) {
            if (value != null) context.read<LanguageProvider>().setLanguage(value);
          },
          secondary: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
          title: const Text('English'),
          subtitle: Text(context.tr('Giao diện tiếng Anh', 'English interface')),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => context.read<LanguageProvider>().toggle(),
          icon: const Icon(Icons.swap_horiz),
          label: Text(context.tr('Chuyển sang English', 'Switch to Tiếng Việt')),
        ),
      ],
    );
  }

  // ---- MQTT Console Tab ----
  void _sendMqttMessage() {
    final topic = _mqttTopicCtrl.text.trim();
    final message = _mqttMessageCtrl.text.trim();
    if (topic.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Vui lòng nhập đủ topic và nội dung gửi.', 'Please enter both topic and message.'))) ,
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
        content: Text(ok ? context.tr('Đã gửi tin nhắn → $topic', 'Message sent → $topic') : context.tr('Gửi tin nhắn thất bại (chưa kết nối)', 'Failed to send message (not connected)')),
        backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade600,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildMqttTab() {
    final deviceProvider = context.watch<DeviceProvider>();
    final fleet = context.watch<FleetProvider>();
    final notiList = deviceProvider.notifications;
    final selectedId = fleet.selectedOrNull?.id;
    final filteredData = _dataLog
        .where((e) => selectedId == null || e.deviceId == selectedId)
        .take(20)
        .toList();
    final filteredNoti = _notiLog
        .where((e) => selectedId == null || e.deviceId == selectedId)
        .take(20)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---- Status card ----
        const MqttStatusBadge(compact: false),
        const SizedBox(height: 4),
        Text(
          context.tr('SSL: ${FeatureConfig.mqttUseSsl ? "Bật (WSS)" : "Tắt (WS)"}', 'SSL: ${FeatureConfig.mqttUseSsl ? "Enabled (WSS)" : "Disabled (WS)"}'),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),

        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 4),

        // ---- Console ----
        Text(
          context.tr('Bảng điều khiển MQTT', 'MQTT Console'),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Topic field
        TextField(
          controller: _mqttTopicCtrl,
          decoration: InputDecoration(
            labelText: context.tr('Chủ đề', 'Topic'),
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
          decoration: InputDecoration(
            labelText: context.tr('Nội dung gửi', 'Message'),
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
            label: Text(context.tr('Gửi', 'Send')),
          ),
        ),

        // ---- Sent log ----
        if (_sentLog.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                context.tr('Lịch sử gửi', 'Send History'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _sentLog.clear()),
                icon: const Icon(Icons.clear_all, size: 16),
                label: Text(context.tr('Xóa', 'Clear'), style: const TextStyle(fontSize: 12)),
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
          Text(
            context.tr('Thông báo nhận được (/noti)', 'Received Notifications (/noti)'),
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
                  tooltip: context.tr('Sao chép', 'Copy'),
                  icon: const Icon(Icons.copy, size: 15),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: noti.message));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('Đã copy', 'Copied')),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],

        // ---- Live /data log ----
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              context.tr('Nhật ký dữ liệu trực tiếp (/data)', 'Live Data Log (/data)'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _dataLog.clear()),
              icon: const Icon(Icons.clear_all, size: 16),
              label: Text(context.tr('Xóa', 'Clear'), style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (filteredData.isEmpty) ...[
          Text(
            context.tr('Chưa nhận được dữ liệu.', 'No data received yet.'),
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ] else ...[
          for (final entry in filteredData)
            Card(
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.data_object, size: 18),
                title: Text(
                  entry.text,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${entry.deviceId}  •  ${_fmtTime(entry.time)}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: IconButton(
                  tooltip: context.tr('Sao chép', 'Copy'),
                  icon: const Icon(Icons.copy, size: 15),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: entry.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('Đã copy', 'Copied')),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],

        // ---- Live /noti log ----
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              context.tr('Nhật ký thông báo trực tiếp (/noti)', 'Live Noti Log (/noti)'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _notiLog.clear()),
              icon: const Icon(Icons.clear_all, size: 16),
              label: Text(context.tr('Xóa', 'Clear'), style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (filteredNoti.isEmpty) ...[
          Text(
            context.tr('Chưa nhận được thông báo.', 'No notifications received yet.'),
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ] else ...[
          for (final entry in filteredNoti)
            Card(
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.notifications_outlined, size: 18),
                title: Text(
                  entry.text,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  '${entry.deviceId}  •  ${_fmtTime(entry.time)}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: IconButton(
                  tooltip: context.tr('Sao chép', 'Copy'),
                  icon: const Icon(Icons.copy, size: 15),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: entry.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('Đã copy', 'Copied')),
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

  // Build method
  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    final auth = context.watch<AuthProvider>();

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Mở rộng', 'More Options')),
          actions: [
            const MqttStatusBadge(compact: true),
            const SizedBox(width: 8),
            const VehiclePicker(),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: context.tr('Thông tin', 'Information')),
              Tab(text: context.tr('Ghi chú', 'Notes')),
              Tab(text: context.tr('Nhân viên', 'Employees')),
              Tab(text: context.tr('Đổi mật khẩu', 'Change Password')),
              Tab(text: context.tr('Ngôn ngữ', 'Language')),
              const Tab(text: 'MQTT'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildInfoTab(fleet, auth),
            _buildNotesTab(),
            _buildEmployeesTab(auth),
            _buildChangePasswordTab(auth),
            _buildLanguageTab(),
            _buildMqttTab(),
          ],
        ),
      ),
    );
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
          tooltip: context.tr('Sao chép tin nhắn', 'Copy message'),
          icon: const Icon(Icons.copy, size: 15),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: entry.message));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr('Đã copy vào clipboard', 'Copied to clipboard')),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
      ),
    );
  }
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

/* End of file -------------------------------------------------------- */