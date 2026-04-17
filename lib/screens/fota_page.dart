// @file       fota_page.dart
// @brief      Screen UI for FOTA.

/* Imports ------------------------------------------------------------ */
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/fota_provider.dart';
import '../services/fota_service.dart';
import '../models/bluetooth_device_info.dart';

/* Public classes ----------------------------------------------------- */
class FotaPage extends StatefulWidget {
  const FotaPage({super.key});

  @override
  State<FotaPage> createState() => _FotaPageState();
}

/* Private classes ---------------------------------------------------- */
class _FotaPageState extends State<FotaPage> {
  final ScrollController _logScrollController = ScrollController();
  StreamSubscription? _connectionSubscription;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFota();
      _setupConnectionListener();
    });
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  void _setupConnectionListener() {
    final btProvider = context.read<BluetoothProvider>();

    // Listen for disconnect
    _connectionSubscription = btProvider.connectionStateStream.listen((state) {
      if (state == AppBluetoothConnectionState.disconnected) {
        // Show dialog and exit
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.bluetooth_disabled, color: AppColors.danger),
                  SizedBox(width: 12),
                  Text('Disconnected'),
                ],
              ),
              content: const Text(
                'Bluetooth connection has been lost.\nPlease reconnect and try again.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      }
    });
  }

  Future<void> _initFota() async {
    final btProvider = context.read<BluetoothProvider>();
    final fotaProvider = context.read<FotaProvider>();

    if (!btProvider.isConnected || btProvider.connectedBleDevice == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not connected to Bluetooth'),
            backgroundColor: AppColors.danger,
          ),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    final success = await fotaProvider.initWithDevice(
      btProvider.connectedBleDevice!,
    );
    if (mounted) {
      setState(() => _isInitialized = success);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to initialize FOTA'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _autoScrollLog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _selectApp1File() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['bin'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      final data = result.files.single.bytes!;
      if (mounted) {
        context.read<FotaProvider>().setApp1Firmware(
          Uint8List.fromList(data),
          result.files.single.name,
        );
      }
    }
  }

  Future<void> _selectApp2File() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['bin'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      final data = result.files.single.bytes!;
      if (mounted) {
        context.read<FotaProvider>().setApp2Firmware(
          Uint8List.fromList(data),
          result.files.single.name,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FOTA Update'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final fotaProvider = context.read<FotaProvider>();
            if (fotaProvider.isUpdating) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Updating'),
                  content: const Text(
                    'The update process is in progress. Are you sure you want to exit?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Stay'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                      ),
                      onPressed: () {
                        fotaProvider.reset();
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Exit'),
                    ),
                  ],
                ),
              );
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          Consumer<FotaProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: provider.isUpdating ? null : () => provider.reset(),
                tooltip: 'Reset',
              );
            },
          ),
        ],
      ),
      body: Consumer<FotaProvider>(
        builder: (context, provider, _) {
          _autoScrollLog();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Card
                _buildStatusCard(provider),
                const SizedBox(height: 16),

                // File Selection
                _buildFileSelectionCard(provider),
                const SizedBox(height: 16),

                // Progress
                _buildProgressCard(provider),
                const SizedBox(height: 16),

                // Log
                Expanded(child: _buildLogCard(provider)),
                const SizedBox(height: 16),

                // Action Buttons
                _buildActionButtons(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(FotaProvider provider) {
    Color statusColor;
    IconData statusIcon;

    switch (provider.state) {
      case FotaState.idle:
        statusColor = AppColors.gray500;
        statusIcon = Icons.hourglass_empty;
        break;
      case FotaState.completed:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        break;
      case FotaState.error:
        statusColor = AppColors.danger;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = AppColors.primary;
        statusIcon = Icons.sync;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status',
                    style: TextStyle(color: AppColors.gray500, fontSize: 12),
                  ),
                  Text(
                    provider.stateText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  if (provider.error != null)
                    Text(
                      provider.error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (provider.isUpdating)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelectionCard(FotaProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.folder_open, size: 20),
                SizedBox(width: 8),
                Text(
                  'Firmware Files',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // APP_1
            _buildFileSelector(
              label: 'APP_1',
              fileName: provider.app1FileName,
              onSelect: provider.isUpdating ? null : _selectApp1File,
            ),
            const SizedBox(height: 12),

            // APP_2
            _buildFileSelector(
              label: 'APP_2',
              fileName: provider.app2FileName,
              onSelect: provider.isUpdating ? null : _selectApp2File,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelector({
    required String label,
    String? fileName,
    VoidCallback? onSelect,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gray300),
            ),
            child: Text(
              fileName ?? 'No file selected',
              style: TextStyle(
                color: fileName != null ? AppColors.dark : AppColors.gray500,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.folder_open),
          onPressed: onSelect,
          tooltip: 'Select File',
        ),
      ],
    );
  }

  Widget _buildProgressCard(FotaProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Progress',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${provider.progress.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: provider.progress / 100,
                minHeight: 12,
                backgroundColor: AppColors.gray200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  provider.hasError
                      ? AppColors.danger
                      : provider.isCompleted
                      ? AppColors.success
                      : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(FotaProvider provider) {
    return Card(
      color: const Color(0xFF1e1e2e),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.terminal, color: Colors.green, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Log',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.white54,
                    size: 20,
                  ),
                  onPressed: () => provider.clearLogs(),
                  tooltip: 'Clear log',
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: ListView.builder(
                controller: _logScrollController,
                itemCount: provider.logs.length,
                itemBuilder: (context, index) {
                  final log = provider.logs[index];
                  Color textColor = const Color(0xFFa6e3a1);

                  if (log.contains('[ERROR]')) {
                    textColor = const Color(0xFFf38ba8);
                  } else if (log.contains('[WARN]')) {
                    textColor = const Color(0xFFf9e2af);
                  } else if (log.contains('[TX]')) {
                    textColor = const Color(0xFF89b4fa);
                  } else if (log.contains('[RX]')) {
                    textColor = const Color(0xFFcba6f7);
                  } else if (log.contains('[INFO]')) {
                    textColor = const Color(0xFF94e2d5);
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      log,
                      style: TextStyle(
                        color: textColor,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(FotaProvider provider) {
    return Row(
      children: [
        // Start Bootloader
        Expanded(
          child: ElevatedButton.icon(
            onPressed: !provider.isReady || provider.isUpdating
                ? null
                : () => provider.startUpdate(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Bootloader'),
          ),
        ),
        const SizedBox(width: 12),

        // Update Firmware
        Expanded(
          child: ElevatedButton.icon(
            onPressed: provider.isCompleted
                ? () async {
                    final success = await provider.sendUpdateCommand();
                    if (mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Update command sent'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.system_update),
            label: const Text('Update Firmware'),
          ),
        ),
      ],
    );
  }
}

/* End of file -------------------------------------------------------- */
