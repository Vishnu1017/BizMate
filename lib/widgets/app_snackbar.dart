// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';

class AppSnackBar {
  /// Core reusable method
  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.info_outline,
    Color backgroundColor = Colors.blueAccent,
    String actionLabel = 'OK',
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.of(context);

    // Proper hide
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.horizontal,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        duration: duration,
        content: _AnimatedSnackBarContent(
          icon: icon,
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ),
    );
  }

  /// 🔴 Error snackbar
  static void showError(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      icon: Icons.error_outline_rounded,
      backgroundColor: Colors.red.shade700,
      duration: duration,
    );
  }

  /// 🟢 Success snackbar
  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      icon: Icons.check_circle_outline_rounded,
      backgroundColor: Colors.green.shade600,
      duration: duration,
    );
  }

  /// 🟦 Info snackbar
  static void showInfo(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      icon: Icons.info_outline_rounded,
      backgroundColor: Colors.blueAccent,
      duration: duration,
    );
  }

  /// 🟨 Warning snackbar
  static void showWarning(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      icon: Icons.warning_amber_rounded,
      backgroundColor: Colors.orange.shade700,
      duration: duration,
    );
  }

  /// 🔄 Loading Snackbar
  static void showLoading(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 2),
  }) {
    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        backgroundColor: Colors.blue.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: duration,
        content: _AnimatedSnackBarContent(isLoading: true, message: message),
      ),
    );
  }
}

/// ⭐ Smooth fade + slide animation
class _AnimatedSnackBarContent extends StatefulWidget {
  final IconData? icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isLoading;

  const _AnimatedSnackBarContent({
    this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isLoading = false,
  });

  @override
  State<_AnimatedSnackBarContent> createState() =>
      _AnimatedSnackBarContentState();
}

class _AnimatedSnackBarContentState extends State<_AnimatedSnackBarContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _opacity = Tween<double>(begin: 0, end: 1).animate(_anim);
    _slide = Tween(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));

    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Row(
          children: [
            // Loader or Icon
            if (widget.isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(widget.icon, color: Colors.white, size: 22),

            const SizedBox(width: 12),

            // Message text
            Expanded(
              child: Text(
                widget.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Action label (OK)
            if (widget.actionLabel != null)
              GestureDetector(
                onTap: () {
                  // Close Snackbar immediately
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();

                  // If developer provided extra action, call it
                  if (widget.onAction != null) {
                    widget.onAction!();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Text(
                    widget.actionLabel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      decoration: TextDecoration.none, // No underline
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
