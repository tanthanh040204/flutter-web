// @file       file_upload_panel.dart
// @brief      Widget for File Upload Panel.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_constants.dart';
import '../config/app_theme.dart';
import '../providers/route_provider.dart';

/* Public classes ----------------------------------------------------- */
class FileUploadPanel extends StatelessWidget {
  const FileUploadPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RouteProvider>(
      builder: (context, routeProvider, child) {
        return Card(
          margin: const EdgeInsets.all(UIConfig.paddingSmall),
          child: Padding(
            padding: const EdgeInsets.all(UIConfig.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Row(
                  children: [
                    Icon(Icons.folder_open, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Upload Data File',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: UIConfig.paddingMedium),

                // Pick file button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: routeProvider.isLoading
                        ? null
                        : () => routeProvider.loadFromFilePicker(),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Select File (.json, .csv, .txt)'),
                  ),
                ),
                const SizedBox(height: UIConfig.paddingSmall),

                // Load sample button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: routeProvider.isLoading
                        ? null
                        : () => routeProvider.loadSampleData(),
                    icon: routeProvider.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Icon(Icons.location_on),
                    label: Text(
                      routeProvider.isLoading
                          ? 'Loading...'
                          : 'Load Sample Data',
                    ),
                  ),
                ),

                // Error message
                if (routeProvider.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      routeProvider.error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/* End of file -------------------------------------------------------- */
