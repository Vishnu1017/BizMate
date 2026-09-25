import 'dart:ui';
import 'package:flutter/material.dart';

Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required VoidCallback onConfirm,
  IconData icon = Icons.delete_forever_rounded,
  Color iconColor = Colors.redAccent,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, anim1, anim2) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
      final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
      final titleColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
      final messageColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
      final cancelBg = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
      final cancelText = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF475569);

      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: MediaQuery.of(ctx).size.width * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: dialogBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: iconColor, size: 64),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: messageColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cancelBg,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: cancelText, fontWeight: FontWeight.w600),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx, true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim1, anim2, child) {
      return Transform.scale(
        scale: anim1.value,
        child: Opacity(opacity: anim1.value, child: child),
      );
    },
  );

  if (result == true) {
    onConfirm();
    return true;
  }

  return false;
}
