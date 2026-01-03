import 'package:flutter/material.dart';

class SnackBarUtils {
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null || isError)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Icon(
                  icon ??
                      (isError
                          ? Icons.error_outline_rounded
                          : Icons.info_outline_rounded),
                  color: isError
                      ? colorScheme.onErrorContainer
                      : colorScheme.onInverseSurface,
                  size: 20,
                ),
              ),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isError
                      ? colorScheme.onErrorContainer
                      : colorScheme.onInverseSurface,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? colorScheme.errorContainer
            : colorScheme.inverseSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showSyncing(BuildContext context) {
    show(context, 'Syncing with cloud...', icon: Icons.sync_rounded);
  }
}
