import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../data/providers.dart';
import '../data/timer_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:simple_pip_mode/pip_widget.dart';

class TimerPage extends ConsumerStatefulWidget {
  const TimerPage({super.key});

  @override
  ConsumerState<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends ConsumerState<TimerPage> {
  @override
  void initState() {
    super.initState();
    // Initialize with first preset when available
    ref.read(presetsProvider.future).then((presets) {
      if (presets.isNotEmpty && ref.read(selectedPresetProvider) == null) {
        ref.read(selectedPresetProvider.notifier).set(presets.first);
        ref.read(timerProvider.notifier).setPreset(presets.first);
      }
    });
  }

  Future<void> _toggleCompactMode() async {
    final isCompact = ref.read(compactModeProvider);
    final nextCompact = !isCompact;

    if (Platform.isWindows) {
      if (nextCompact) {
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setResizable(false);
        await windowManager.setSize(const Size(350, 120));
      } else {
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setResizable(true);
        await windowManager.setSize(const Size(800, 700)); // Default size
      }
    } else if (Platform.isAndroid && nextCompact) {
      SimplePip().enterPipMode();
    }

    ref.read(compactModeProvider.notifier).set(nextCompact);
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(timerProvider);
    final presetsAsync = ref.watch(presetsProvider);
    final currentPreset = ref.watch(selectedPresetProvider);
    final isCompact = ref.watch(compactModeProvider);

    // 컴팩트 모드 전용 UI (가로형) - 윈도우 한정
    if (isCompact && Platform.isWindows) {
      return Scaffold(
        body: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 1. 시계 (숫자만)
                Text(
                  _formatTime(timerState.remainingSeconds),
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                    fontFeatures: [const FontFeature.tabularFigures()],
                    color: timerState.mode == TimerMode.focus
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: 8),
                // 2. 재생/중지 버튼
                IconButton.filledTonal(
                  iconSize: 24,
                  onPressed: () {
                    if (timerState.status == TimerStatus.running) {
                      ref.read(timerProvider.notifier).pause();
                    } else {
                      ref.read(timerProvider.notifier).start();
                    }
                  },
                  icon: Icon(
                    timerState.status == TimerStatus.running
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
                // 3. 컴팩트 모드 복귀 버튼
                IconButton(
                  onPressed: _toggleCompactMode,
                  icon: const Icon(Icons.close_fullscreen_rounded, size: 20),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final mainContent = Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Preset Selector
              presetsAsync.when(
                data: (presets) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: presets.map((preset) {
                        final isSelected = currentPreset?.name == preset.name;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Text(preset.name),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                ref
                                    .read(selectedPresetProvider.notifier)
                                    .set(preset);
                                ref
                                    .read(timerProvider.notifier)
                                    .setPreset(preset);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (err, stack) => const Text('Failed to load presets'),
              ),
              const SizedBox(height: 32),

              // Timer Display
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    height: 300,
                    child: CircularProgressIndicator(
                      value: timerState.progress,
                      strokeWidth: 20,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        timerState.mode == TimerMode.focus
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timerState.mode == TimerMode.focus ? 'FOCUS' : 'REST',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTime(timerState.remainingSeconds),
                        style: GoogleFonts.outfit(
                          fontSize: 80,
                          fontWeight: FontWeight.w200,
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  // Compact Mode Toggle Button inside the Stack
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      onPressed: _toggleCompactMode,
                      icon: Icon(
                        Platform.isWindows
                            ? Icons.open_in_full_rounded
                            : Icons.picture_in_picture_alt_rounded,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    onPressed: () {
                      ref.read(timerProvider.notifier).reset();
                    },
                    heroTag: 'reset',
                    elevation: 0,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.refresh_rounded),
                  ),
                  const SizedBox(width: 24),
                  FloatingActionButton.large(
                    onPressed: () {
                      if (timerState.status == TimerStatus.running) {
                        ref.read(timerProvider.notifier).pause();
                      } else {
                        ref.read(timerProvider.notifier).start();
                      }
                    },
                    heroTag: 'play_pause',
                    backgroundColor: timerState.status == TimerStatus.running
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      timerState.status == TimerStatus.running
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 48,
                    ),
                  ),
                  const SizedBox(width: 24),
                  FloatingActionButton(
                    onPressed: () {
                      ref.read(timerProvider.notifier).skip();
                    },
                    heroTag: 'skip',
                    elevation: 0,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (Platform.isAndroid) {
      return PipWidget(
        pipChild: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  timerState.mode == TimerMode.focus ? 'FOCUS' : 'REST',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  _formatTime(timerState.remainingSeconds),
                  style: GoogleFonts.outfit(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 32,
                      onPressed: () {
                        if (timerState.status == TimerStatus.running) {
                          ref.read(timerProvider.notifier).pause();
                        } else {
                          ref.read(timerProvider.notifier).start();
                        }
                      },
                      icon: Icon(
                        timerState.status == TimerStatus.running
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        child: mainContent,
      );
    }

    return mainContent;
  }
}
