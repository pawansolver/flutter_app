import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

bool isMediaPermissionError(Object error) {
  if (error is! PlatformException) return false;
  return switch (error.code) {
    'camera_access_denied' ||
    'camera_access_restricted' ||
    'photo_access_denied' ||
    'photo_access_restricted' => true,
    _ => false,
  };
}

Future<void> showPermissionSettingsDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final openSettings = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Open settings'),
        ),
      ],
    ),
  );

  if (openSettings == true) {
    await openAppSettings();
  }
}
