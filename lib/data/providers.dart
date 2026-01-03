import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database.dart';
import 'stats_repository.dart';
import 'settings_repository.dart';
import 'timer_provider.dart';
import 'auth_repository.dart';
import 'sync_repository.dart';
import 'google_drive_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(ref.watch(databaseProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final presetsProvider = FutureProvider<List<TimerPreset>>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getPresets();
});

class SelectedPresetNotifier extends Notifier<TimerPreset?> {
  @override
  TimerPreset? build() => null;
  void set(TimerPreset preset) => state = preset;
}

final selectedPresetProvider =
    NotifierProvider<SelectedPresetNotifier, TimerPreset?>(
      SelectedPresetNotifier.new,
    );

final timerProvider = NotifierProvider<TimerNotifier, TimerState>(
  TimerNotifier.new,
);

// Auth Providers
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

class AuthLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setLoading(bool value) {
    debugPrint('AuthLoadingNotifier state change: $state -> $value');
    state = value;
  }
}

final authLoadingProvider = NotifierProvider<AuthLoadingNotifier, bool>(
  AuthLoadingNotifier.new,
);

// Sync Providers
final syncRepositoryProvider = Provider<SyncRepository?>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return null;

  final db = ref.watch(databaseProvider);
  return SyncRepository(db, auth);
});

final googleDriveRepositoryProvider = Provider<GoogleDriveRepository?>((ref) {
  final authState = ref.watch(authStateProvider).value;
  if (authState == null) return null;

  final db = ref.watch(databaseProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  return GoogleDriveRepository(db, authRepo);
});
final lastSyncProvider = StreamProvider<DateTime?>((ref) {
  final syncRepo = ref.watch(syncRepositoryProvider);
  if (syncRepo == null) return Stream.value(null);
  return syncRepo.lastSyncStream;
});

enum StatsPeriod { day, week, month, year }

class StatsPeriodNotifier extends Notifier<StatsPeriod> {
  @override
  StatsPeriod build() => StatsPeriod.week;
  void set(StatsPeriod value) => state = value;
}

final statsPeriodProvider = NotifierProvider<StatsPeriodNotifier, StatsPeriod>(
  StatsPeriodNotifier.new,
);

class StatsDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();
  void set(DateTime value) => state = value;
}

final statsDateProvider = NotifierProvider<StatsDateNotifier, DateTime>(
  StatsDateNotifier.new,
);

final statsDataProvider = FutureProvider.family<dynamic, StatsPeriod>((
  ref,
  period,
) async {
  final repo = ref.watch(statsRepositoryProvider);
  final date = ref.watch(statsDateProvider);

  switch (period) {
    case StatsPeriod.day:
      return repo.getDailyStats(date);
    case StatsPeriod.week:
      return repo.getWeeklyStats(date);
    case StatsPeriod.month:
      final start = DateTime(date.year, date.month, 1);
      final end = DateTime(date.year, date.month + 1, 1);
      return repo.getHeatMapStats(start, end);
    case StatsPeriod.year:
      final start = DateTime(date.year, 1, 1);
      final end = DateTime(date.year + 1, 1, 1);
      return repo.getHeatMapStats(start, end);
  }
});

final statsSummaryProvider = FutureProvider.family<StatsSummary, StatsPeriod>((
  ref,
  period,
) async {
  final repo = ref.watch(statsRepositoryProvider);
  final date = ref.watch(statsDateProvider);

  DateTime start;
  DateTime end;

  switch (period) {
    case StatsPeriod.day:
      start = DateTime(date.year, date.month, date.day);
      end = start.add(const Duration(days: 1));
      break;
    case StatsPeriod.week:
      final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
      start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      end = start.add(const Duration(days: 7));
      break;
    case StatsPeriod.month:
      start = DateTime(date.year, date.month, 1);
      end = DateTime(date.year, date.month + 1, 1);
      break;
    case StatsPeriod.year:
      start = DateTime(date.year, 1, 1);
      end = DateTime(date.year + 1, 1, 1);
      break;
  }

  return repo.getStatsSummary(start, end);
});

class CompactModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final compactModeProvider = NotifierProvider<CompactModeNotifier, bool>(
  CompactModeNotifier.new,
);

class AutoStartNextNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final repo = ref.read(settingsRepositoryProvider);
    state = await repo.getAutoStartNext();
  }

  Future<void> set(bool value) async {
    state = value;
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setAutoStartNext(value);
  }
}

final autoStartNextProvider = NotifierProvider<AutoStartNextNotifier, bool>(
  AutoStartNextNotifier.new,
);
