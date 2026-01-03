import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'database.dart';
import 'providers.dart';
import 'settings_repository.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:developer' as dev;
import '../utils/notification_service.dart';

enum TimerStatus { initial, running, paused, finished }

enum TimerMode { focus, rest }

class TimerState {
  final int remainingSeconds;
  final int totalSeconds;
  final TimerStatus status;
  final TimerMode mode;
  final TimerPreset currentPreset;

  TimerState({
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.status,
    required this.mode,
    required this.currentPreset,
  });

  TimerState copyWith({
    int? remainingSeconds,
    int? totalSeconds,
    TimerStatus? status,
    TimerMode? mode,
    TimerPreset? currentPreset,
  }) {
    return TimerState(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      status: status ?? this.status,
      mode: mode ?? this.mode,
      currentPreset: currentPreset ?? this.currentPreset,
    );
  }

  double get progress =>
      totalSeconds > 0 ? remainingSeconds / totalSeconds : 0.0;
}

class TimerNotifier extends Notifier<TimerState> {
  Timer? _ticker;
  late AppDatabase _db;
  final _audioPlayer = AudioPlayer();

  @override
  TimerState build() {
    _db = ref.watch(databaseProvider);
    final preset =
        ref.watch(selectedPresetProvider) ??
        TimerPreset(name: 'Default', focusMinutes: 25, restMinutes: 5);

    // Cleanup old ticker if rebuilding
    ref.onDispose(() {
      _ticker?.cancel();
      _audioPlayer.dispose();
    });

    return TimerState(
      remainingSeconds: preset.focusMinutes * 60,
      totalSeconds: preset.focusMinutes * 60,
      status: TimerStatus.initial,
      mode: TimerMode.focus,
      currentPreset: preset,
    );
  }

  void setPreset(TimerPreset preset) {
    _ticker?.cancel();
    state = TimerState(
      remainingSeconds: preset.focusMinutes * 60,
      totalSeconds: preset.focusMinutes * 60,
      status: TimerStatus.initial,
      mode: TimerMode.focus,
      currentPreset: preset,
    );
  }

  void start() {
    if (state.status == TimerStatus.running) return;

    state = state.copyWith(status: TimerStatus.running);
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds > 0) {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      } else {
        _handleTimerComplete();
      }
    });
  }

  void pause() {
    _ticker?.cancel();
    state = state.copyWith(status: TimerStatus.paused);

    // Record pause event
    _db.addEvent(
      TimerEventsCompanion(
        timestamp: drift.Value(DateTime.now()),
        type: const drift.Value('pause'),
      ),
    );
  }

  void reset() {
    _ticker?.cancel();
    final duration = state.mode == TimerMode.focus
        ? state.currentPreset.focusMinutes * 60
        : state.currentPreset.restMinutes * 60;

    state = state.copyWith(
      remainingSeconds: duration,
      totalSeconds: duration,
      status: TimerStatus.initial,
    );
  }

  void skip() {
    final wasRunning = state.status == TimerStatus.running;
    _ticker?.cancel();

    // Switch modes
    if (state.mode == TimerMode.focus) {
      // Skipping Focus -> Go to Rest
      _db.addEvent(
        TimerEventsCompanion(
          timestamp: drift.Value(DateTime.now()),
          type: const drift.Value('skip_focus'),
        ),
      );
      final restDuration = state.currentPreset.restMinutes * 60;
      state = state.copyWith(
        mode: TimerMode.rest,
        remainingSeconds: restDuration,
        totalSeconds: restDuration,
        status: wasRunning ? TimerStatus.running : TimerStatus.initial,
      );
    } else {
      // Skipping Rest -> Go to Focus
      _db.addEvent(
        TimerEventsCompanion(
          timestamp: drift.Value(DateTime.now()),
          type: const drift.Value('skip_rest'),
        ),
      );
      final focusDuration = state.currentPreset.focusMinutes * 60;
      state = state.copyWith(
        mode: TimerMode.focus,
        remainingSeconds: focusDuration,
        totalSeconds: focusDuration,
        status: wasRunning ? TimerStatus.running : TimerStatus.initial,
      );
    }

    // If it was running, we must restart the ticker because we canceled it above
    // and we are bypassing the 'start()' method's check (or we can just copy the start logic).
    if (wasRunning) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (state.remainingSeconds > 0) {
          state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
        } else {
          _handleTimerComplete();
        }
      });
    }
  }

  Future<void> _handleTimerComplete() async {
    _ticker?.cancel();
    state = state.copyWith(status: TimerStatus.finished);

    // 알림 발송 및 효과음 재생
    final isFocus = state.mode == TimerMode.focus;
    final title = isFocus ? 'Focus Session Complete!' : 'Break Over!';
    final body = isFocus
        ? 'Time to take a short break.'
        : 'Ready to focus again?';

    NotificationService().showNotification(id: 0, title: title, body: body);

    try {
      await _audioPlayer.play(AssetSource('notification.mp3'));
    } catch (e) {
      dev.log('Sound playback failed: $e');
    }

    if (isFocus) {
      // Record session in DB
      try {
        await _db.addSession(
          SessionsCompanion(
            startTime: drift.Value(
              DateTime.now().subtract(Duration(seconds: state.totalSeconds)),
            ),
            durationSeconds: drift.Value(state.totalSeconds),
            type: const drift.Value('focus'),
            completed: const drift.Value(true),
          ),
        );
        dev.log('Session saved successfully');
      } catch (e) {
        dev.log('Failed to save session: $e');
      }

      // Trigger sync
      ref.read(syncRepositoryProvider)?.syncAll().catchError((e) {
        dev.log('Auto-sync failed: $e');
      });

      // 통계 UI 갱신 강제
      ref.invalidate(statsDataProvider);

      // Switch to rest
      final restDuration = state.currentPreset.restMinutes * 60;
      state = state.copyWith(
        mode: TimerMode.rest,
        remainingSeconds: restDuration,
        totalSeconds: restDuration,
        status: TimerStatus.initial,
      );
    } else {
      // Finished rest, record session
      try {
        await _db.addSession(
          SessionsCompanion(
            startTime: drift.Value(
              DateTime.now().subtract(Duration(seconds: state.totalSeconds)),
            ),
            durationSeconds: drift.Value(state.totalSeconds),
            type: const drift.Value('rest'),
            completed: const drift.Value(true),
          ),
        );
        dev.log('Rest session saved successfully');
      } catch (e) {
        dev.log('Failed to save rest session: $e');
      }

      // Finished rest, switch back to focus
      final focusDuration = state.currentPreset.focusMinutes * 60;
      state = state.copyWith(
        mode: TimerMode.focus,
        remainingSeconds: focusDuration,
        totalSeconds: focusDuration,
        status: TimerStatus.initial,
      );
    }

    // 자동으로 다음 타이머 시작 (설정에 따라)
    final autoStart = ref.read(autoStartNextProvider);
    if (autoStart) {
      start();
    }
  }
}
