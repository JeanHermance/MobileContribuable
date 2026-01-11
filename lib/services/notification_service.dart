import 'package:flutter/material.dart';

enum ToastType { success, error, warning, info }

class NotificationService {
  static OverlayEntry? _overlayEntry;

  static void showToast(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    _overlayEntry?.remove();
    _overlayEntry = null;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 10,
        right: 10,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: _getToastColor(type),
              borderRadius: BorderRadius.circular(8.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  _getToastIcon(type),
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final overlay = Overlay.of(context);
    if (_overlayEntry != null) {
      overlay.insert(_overlayEntry!);
    }

    Future.delayed(duration, () {
      if (_overlayEntry != null) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  // Show success notification
  static void showSuccess(BuildContext context, String message) {
    showToast(context, message, type: ToastType.success);
  }

  // Show error notification
  static void showError(BuildContext context, String message) {
    showToast(context, message, type: ToastType.error, duration: const Duration(seconds: 4));
  }

  // Show warning notification
  static void showWarning(BuildContext context, String message) {
    showToast(context, message, type: ToastType.warning);
  }

  // Show info notification
  static void showInfo(BuildContext context, String message) {
    showToast(context, message, type: ToastType.info);
  }

  static Color _getToastColor(ToastType type) {
    switch (type) {
      case ToastType.success:
        return Colors.green;
      case ToastType.error:
        return Colors.red;
      case ToastType.warning:
        return Colors.orange;
      case ToastType.info:
        return const Color.fromARGB(221, 25, 88, 160);
    }
  }

  static IconData _getToastIcon(ToastType type) {
    switch (type) {
      case ToastType.success:
        return Icons.check_circle;
      case ToastType.error:
        return Icons.error;
      case ToastType.warning:
        return Icons.warning;
      case ToastType.info:
        return Icons.info;
    }
  }
}