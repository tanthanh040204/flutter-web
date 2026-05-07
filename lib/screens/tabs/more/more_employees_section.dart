// @file       more_employees_section.dart
// @brief      Employees sub-tab — list, add and delete employee accounts.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/employee_account.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/firebase_repo.dart';
import '../../../utils/date_utils.dart';

/* Public classes ----------------------------------------------------- */
class MoreEmployeesSection extends StatefulWidget {
  const MoreEmployeesSection({super.key});

  @override
  State<MoreEmployeesSection> createState() => _MoreEmployeesSectionState();
}

/* Private classes ---------------------------------------------------- */
class _MoreEmployeesSectionState extends State<MoreEmployeesSection> {
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 10),
        TextField(
          controller: _codeCtrl,
          decoration: const InputDecoration(
            labelText: 'New Employee Code',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordCtrl,
          obscureText: _hidePassword,
          decoration: InputDecoration(
            labelText: 'Password for New Employee Code',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
              icon: Icon(
                _hidePassword ? Icons.visibility_off : Icons.visibility,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordCtrl,
          obscureText: _hideConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.verified_user_outlined),
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _hideConfirmPassword = !_hideConfirmPassword),
              icon: Icon(
                _hideConfirmPassword ? Icons.visibility_off : Icons.visibility,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _addEmployeeAccount,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_alt_1),
            label: const Text('Add Employee Code'),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Employee Codes List',
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
                  child: Text('No employee codes available.'),
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
                    title: Text('Employee Code: ${item.employeeCode}'),
                    subtitle: Text(
                      isCurrent
                          ? 'Currently logged in'
                          : 'Updated: ${AppDateUtils.formatShortDateTime(item.updatedAt)}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Delete Employee Code',
                      onPressed: () => _confirmDelete(item),
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

  Future<void> _addEmployeeAccount() async {
    final messenger = ScaffoldMessenger.of(context);
    final code = _codeCtrl.text.trim();
    final pass = _passwordCtrl.text.trim();
    final confirm = _confirmPasswordCtrl.text.trim();

    if (code.isEmpty || pass.isEmpty || confirm.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    if (pass.length < 4) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 4 characters long.'),
        ),
      );
      return;
    }

    if (pass != confirm) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Password confirmation does not match.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final ok = await FirebaseRepo.instance.addEmployeeAccount(
        employeeCode: code,
        password: pass,
      );

      if (!mounted) return;

      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Employee code already exists or data is invalid.'),
          ),
        );
        return;
      }

      _codeCtrl.clear();
      _passwordCtrl.clear();
      _confirmPasswordCtrl.clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('Employee account added successfully.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmDelete(EmployeeAccount item) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();

    if (item.employeeCode == auth.employeeCode) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the employee code currently logged in.'),
        ),
      );
      return;
    }

    final ok =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Employee Code'),
            content: Text(
              'Are you sure you want to delete employee code ${item.employeeCode}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
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

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Employee code ${item.employeeCode} deleted successfully.'
              : 'Failed to delete employee code.',
        ),
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */
