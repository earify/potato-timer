import 'database.dart';

class StatsRepository {
  final AppDatabase db;

  StatsRepository(this.db);

  // Helper: Get start of day
  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // No longer generating fake data

  Future<Map<int, double>> getDailyStats(DateTime date) async {
    final start = _startOfDay(date);
    final end = start.add(const Duration(days: 1));
    final sessions = await db.getSessionsInRange(start, end);

    // Group by hour (0-23)
    final Map<int, double> hourlyFocus = {};
    for (var session in sessions) {
      if (session.type == 'focus') {
        final hour = session.startTime.hour;
        hourlyFocus[hour] =
            (hourlyFocus[hour] ?? 0) + (session.durationSeconds / 60);
      }
    }
    return hourlyFocus;
  }

  Future<Map<int, double>> getWeeklyStats(DateTime date) async {
    // Find start of week (Monday)
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    final start = _startOfDay(startOfWeek);
    final end = start.add(const Duration(days: 7));

    final sessions = await db.getSessionsInRange(start, end);

    // Group by weekday (1-7)
    final Map<int, double> dailyFocus = {};
    for (var session in sessions) {
      if (session.type == 'focus') {
        final day = session.startTime.weekday; // 1 = Monday
        dailyFocus[day] =
            (dailyFocus[day] ?? 0) + (session.durationSeconds / 60);
      }
    }
    return dailyFocus;
  }

  Future<Map<int, double>> getMonthlyStats(DateTime date) async {
    final start = DateTime(date.year, date.month, 1);
    final end = DateTime(date.year, date.month + 1, 1);

    final sessions = await db.getSessionsInRange(start, end);

    // Group by day of month
    final Map<int, double> dailyFocus = {};
    for (var session in sessions) {
      if (session.type == 'focus') {
        final day = session.startTime.day;
        dailyFocus[day] =
            (dailyFocus[day] ?? 0) + (session.durationSeconds / 60);
      }
    }
    return dailyFocus;
  }

  Future<Map<int, double>> getYearlyStats(DateTime date) async {
    final start = DateTime(date.year, 1, 1);
    final end = DateTime(date.year + 1, 1, 1);

    final sessions = await db.getSessionsInRange(start, end);

    // Group by month (1-12)
    final Map<int, double> monthlyFocus = {};
    for (var session in sessions) {
      if (session.type == 'focus') {
        final month = session.startTime.month;
        monthlyFocus[month] =
            (monthlyFocus[month] ?? 0) + (session.durationSeconds / 60);
      }
    }
    return monthlyFocus;
  }

  Future<Map<DateTime, int>> getHeatMapStats(
    DateTime start,
    DateTime end,
  ) async {
    final sessions = await db.getSessionsInRange(start, end);

    final Map<DateTime, int> dailyData = {};
    for (var session in sessions) {
      if (session.type == 'focus') {
        // Normalize date to YYYY-MM-DD
        final date = DateTime(
          session.startTime.year,
          session.startTime.month,
          session.startTime.day,
        );
        final minutes = (session.durationSeconds / 60).round();
        dailyData[date] = (dailyData[date] ?? 0) + minutes;
      }
    }
    return dailyData;
  }

  Future<StatsSummary> getStatsSummary(DateTime start, DateTime end) async {
    final sessions = await db.getSessionsInRange(start, end);
    final events = await db.getEventsInRange(start, end);

    double focusMinutes = 0;
    double restMinutes = 0;
    int pauseCount = 0;
    int skipFocusCount = 0;
    int skipRestCount = 0;

    for (var session in sessions) {
      if (session.type == 'focus') {
        focusMinutes += session.durationSeconds / 60;
      } else if (session.type == 'rest') {
        restMinutes += session.durationSeconds / 60;
      }
    }

    for (var event in events) {
      if (event.type == 'pause') {
        pauseCount++;
      } else if (event.type == 'skip_focus') {
        skipFocusCount++;
      } else if (event.type == 'skip_rest') {
        skipRestCount++;
      }
    }

    return StatsSummary(
      focusMinutes: focusMinutes,
      restMinutes: restMinutes,
      pauseCount: pauseCount,
      skipFocusCount: skipFocusCount,
      skipRestCount: skipRestCount,
    );
  }
}

class StatsSummary {
  final double focusMinutes;
  final double restMinutes;
  final int pauseCount;
  final int skipFocusCount;
  final int skipRestCount;

  StatsSummary({
    required this.focusMinutes,
    required this.restMinutes,
    required this.pauseCount,
    required this.skipFocusCount,
    required this.skipRestCount,
  });
}
