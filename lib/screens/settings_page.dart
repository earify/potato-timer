import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/theme_provider.dart';
import 'package:intl/intl.dart';
import '../data/providers.dart';
import '../data/settings_repository.dart';
import '../data/timer_provider.dart';
import '../utils/snack_bar_utils.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeProvider);
    final authState = ref.watch(authStateProvider);
    final syncRepo = ref.watch(syncRepositoryProvider);
    final isLoading = ref.watch(authLoadingProvider);
    debugPrint('SettingsPage build. isLoading: $isLoading');

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, 'Account & Sync'),
          Card(
            elevation: 0,
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            margin: const EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: authState.when(
                data: (user) {
                  if (user == null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Sign in to sync your data across devices.'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  debugPrint(
                                    'Login button clicked. isLoading: $isLoading',
                                  );
                                  ref
                                      .read(authLoadingProvider.notifier)
                                      .setLoading(true);
                                  debugPrint('isLoading set to true');
                                  try {
                                    final result = await ref
                                        .read(authRepositoryProvider)
                                        .signInWithGoogle();
                                    if (result == null) {
                                      SnackBarUtils.show(
                                        context,
                                        'Sign in cancelled',
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      SnackBarUtils.show(
                                        context,
                                        'Error: $e',
                                        isError: true,
                                      );
                                    }
                                  } finally {
                                    ref
                                        .read(authLoadingProvider.notifier)
                                        .setLoading(false);
                                  }
                                },
                          icon: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: Text(
                            isLoading ? 'Signing in...' : 'Sign in with Google',
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage: user.photoURL != null
                              ? NetworkImage(user.photoURL!)
                              : null,
                          child: user.photoURL == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(user.displayName ?? 'User'),
                        subtitle: Text(user.email ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.logout),
                          onPressed: () =>
                              ref.read(authRepositoryProvider).signOut(),
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      ref
                          .watch(lastSyncProvider)
                          .when(
                            data: (lastSync) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: 8.0,
                                left: 4.0,
                              ),
                              child: Text(
                                lastSync != null
                                    ? 'Last synced: ${DateFormat('yyyy-MM-dd HH:mm').format(lastSync)}'
                                    : 'Not synced yet',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outline,
                                    ),
                              ),
                            ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                if (syncRepo != null) {
                                  try {
                                    SnackBarUtils.showSyncing(context);
                                    await syncRepo.syncAll();
                                    if (context.mounted) {
                                      SnackBarUtils.show(
                                        context,
                                        'Cloud sync complete!',
                                        icon: Icons.cloud_done_rounded,
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      SnackBarUtils.show(
                                        context,
                                        'Sync failed: $e',
                                        isError: true,
                                      );
                                    }
                                  }
                                }
                              },
                              icon: const Icon(Icons.cloud_sync),
                              label: const Text('Sync Now'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Reset Statistics?'),
                                    content: const Text(
                                      'This will permanently delete ALL local session records, including example data. This cannot be undone.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                          foregroundColor: Theme.of(
                                            context,
                                          ).colorScheme.onError,
                                        ),
                                        child: const Text('Reset All'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed == true) {
                                  final db = ref.read(databaseProvider);
                                  final syncRepo = ref.read(
                                    syncRepositoryProvider,
                                  );

                                  SnackBarUtils.show(
                                    context,
                                    'Cleaning up all data...',
                                    icon: Icons.cleaning_services_rounded,
                                  );

                                  try {
                                    await db.deleteAllSessions();
                                    if (syncRepo != null) {
                                      await syncRepo.clearCloudData();
                                    }

                                    if (context.mounted) {
                                      SnackBarUtils.show(
                                        context,
                                        'All local & cloud data cleared!',
                                        icon: Icons.delete_sweep_rounded,
                                      );
                                      ref.invalidate(statsDataProvider);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      SnackBarUtils.show(
                                        context,
                                        'Cleanup failed: $e',
                                        isError: true,
                                      );
                                    }
                                  }
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              icon: const Icon(Icons.delete_forever),
                              label: const Text('Reset Stats'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final driveRepo = ref.read(
                                  googleDriveRepositoryProvider,
                                );
                                if (driveRepo != null) {
                                  SnackBarUtils.show(
                                    context,
                                    'Backing up to Drive...',
                                    icon: Icons.cloud_upload_rounded,
                                  );
                                  await driveRepo.backupToDrive();
                                  if (context.mounted) {
                                    SnackBarUtils.show(
                                      context,
                                      'Drive backup complete!',
                                      icon: Icons.cloud_done_rounded,
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.add_to_drive),
                              label: const Text('Drive Backup'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final driveRepo = ref.read(
                            googleDriveRepositoryProvider,
                          );
                          if (driveRepo != null) {
                            SnackBarUtils.show(
                              context,
                              'Restoring from Drive...',
                              icon: Icons.cloud_download_rounded,
                            );
                            await driveRepo.restoreFromDrive();
                            if (context.mounted) {
                              SnackBarUtils.show(
                                context,
                                'Drive restore complete!',
                                icon: Icons.settings_backup_restore_rounded,
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.file_download),
                        label: const Text('Drive Restore'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 36),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) {
                  final errorMessage = err.toString();
                  final isFirebaseError =
                      errorMessage.contains('Firebase') ||
                      errorMessage.contains('core/no-app');

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Initialization Error',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isFirebaseError
                            ? 'Firebase가 초기화되지 않았습니다.\n터미널에서 "flutterfire configure"를 실행해 주세요.'
                            : 'Error: $err',
                        style: const TextStyle(fontSize: 13),
                      ),
                      if (isFirebaseError) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: () => ref.refresh(authStateProvider),
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Try Again'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: isLoading
                                    ? null
                                    : () async {
                                        ref
                                            .read(authLoadingProvider.notifier)
                                            .setLoading(true);
                                        try {
                                          await ref
                                              .read(authRepositoryProvider)
                                              .signInWithGoogle();
                                        } catch (e) {
                                          if (context.mounted) {
                                            SnackBarUtils.show(
                                              context,
                                              'Error: $e',
                                              isError: true,
                                            );
                                          }
                                        } finally {
                                          ref
                                              .read(
                                                authLoadingProvider.notifier,
                                              )
                                              .setLoading(false);
                                        }
                                      },
                                icon: isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.login, size: 18),
                                label: const Text('Sign In'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),

          _buildSectionHeader(context, 'Timer Presets'),
          ref
              .watch(presetsProvider)
              .when(
                data: (presets) => Card(
                  elevation: 0,
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: presets.asMap().entries.map((entry) {
                      final index = entry.key;
                      final preset = entry.value;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        title: Text(
                          preset.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Focus: ${preset.focusMinutes}m · Rest: ${preset.restMinutes}m',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () =>
                              _editPreset(context, ref, presets, index),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) =>
                    ListTile(title: Text('Error loading presets: $e')),
              ),

          _buildSectionHeader(context, 'Timer Settings'),
          Card(
            elevation: 0,
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            margin: const EdgeInsets.only(bottom: 24),
            child: SwitchListTile(
              title: const Text('Auto-start next session'),
              subtitle: const Text(
                'Automatically start the next timer when finished',
              ),
              secondary: const Icon(Icons.auto_mode_rounded),
              value: ref.watch(autoStartNextProvider),
              onChanged: (value) {
                ref.read(autoStartNextProvider.notifier).set(value);
              },
            ),
          ),

          _buildSectionHeader(context, 'Theme'),
          Card(
            elevation: 0,
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            margin: const EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Theme Mode',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode),
                      ),
                    ],
                    selected: {themeSettings.mode},
                    onSelectionChanged: (Set<ThemeMode> newSelection) {
                      ref
                          .read(themeProvider.notifier)
                          .setThemeMode(newSelection.first);
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Color Scheme',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(appThemeColors.length, (index) {
                      final color = appThemeColors[index];
                      final isSelected = themeSettings.colorIndex == index;
                      return GestureDetector(
                        onTap: () {
                          ref.read(themeProvider.notifier).setColorIndex(index);
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    width: 3,
                                  )
                                : null,
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 28,
                                )
                              : null,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),

          _buildSectionHeader(context, 'About'),
          Card(
            elevation: 0,
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Podomoro Timer'),
              subtitle: Text('Version 1.1.0 (with Firebase)'),
            ),
          ),
        ],
      ),
    );
  }

  void _editPreset(
    BuildContext context,
    WidgetRef ref,
    List<TimerPreset> presets,
    int index,
  ) async {
    final preset = presets[index];
    final nameController = TextEditingController(text: preset.name);
    final focusController = TextEditingController(
      text: preset.focusMinutes.toString(),
    );
    final restController = TextEditingController(
      text: preset.restMinutes.toString(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Preset'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Preset Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: focusController,
              decoration: const InputDecoration(labelText: 'Focus Minutes'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: restController,
              decoration: const InputDecoration(labelText: 'Rest Minutes'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final newPresets = List<TimerPreset>.from(presets);
      newPresets[index] = TimerPreset(
        name: nameController.text,
        focusMinutes: int.tryParse(focusController.text) ?? preset.focusMinutes,
        restMinutes: int.tryParse(restController.text) ?? preset.restMinutes,
      );

      final repo = ref.read(settingsRepositoryProvider);
      await repo.savePresets(newPresets);

      // Update selected preset if it was the one edited
      final currentPreset = ref.read(selectedPresetProvider);
      if (currentPreset != null && currentPreset.name == preset.name) {
        ref.read(selectedPresetProvider.notifier).set(newPresets[index]);
        // Also update timer display if not running
        final timerNotifier = ref.read(timerProvider.notifier);
        if (ref.read(timerProvider).status != TimerStatus.running) {
          timerNotifier.setPreset(newPresets[index]);
        }
      }

      // Refresh presets list
      ref.invalidate(presetsProvider);

      if (context.mounted) {
        SnackBarUtils.show(context, 'Preset saved!', icon: Icons.save_rounded);
      }
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
