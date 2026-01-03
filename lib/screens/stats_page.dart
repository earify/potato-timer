import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:intl/intl.dart';
import '../data/providers.dart';
import '../data/stats_repository.dart';
import '../utils/snack_bar_utils.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(statsPeriodProvider);
    final date = ref.watch(statsDateProvider);
    final statsAsync = ref.watch(statsDataProvider(period));
    final summaryAsync = ref.watch(statsSummaryProvider(period));

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Period Selector
            SegmentedButton<StatsPeriod>(
              segments: const [
                ButtonSegment(value: StatsPeriod.day, label: Text('Day')),
                ButtonSegment(value: StatsPeriod.week, label: Text('Week')),
                ButtonSegment(value: StatsPeriod.month, label: Text('Month')),
                ButtonSegment(value: StatsPeriod.year, label: Text('Year')),
              ],
              selected: {period},
              onSelectionChanged: (Set<StatsPeriod> newSelection) {
                ref.read(statsPeriodProvider.notifier).set(newSelection.first);
              },
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeDate(ref, -1),
                ),
                Text(
                  _formatDateRange(period, date),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeDate(ref, 1),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Summary Cards
            summaryAsync.when(
              data: (summary) => _buildSummaryCards(context, summary),
              loading: () => const SizedBox(height: 80),
              error: (err, stack) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // Visualization
            Expanded(
              child: statsAsync.when(
                data: (data) {
                  if (data is Map<int, double>) {
                    return _buildBarChart(context, period, data);
                  } else if (data is Map<DateTime, int>) {
                    if (period == StatsPeriod.month) {
                      return _buildMonthCalendar(context, date, data);
                    } else {
                      return _buildYearHeatMap(context, date, data);
                    }
                  }
                  return const SizedBox.shrink();
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, StatsSummary summary) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildSummaryCard(
            context,
            'Focused',
            '${summary.focusMinutes.toStringAsFixed(0)}m',
            Icons.timer_rounded,
            Theme.of(context).colorScheme.primary,
          ),
          _buildSummaryCard(
            context,
            'Rest',
            '${summary.restMinutes.toStringAsFixed(0)}m',
            Icons.coffee_rounded,
            Theme.of(context).colorScheme.tertiary,
          ),
          _buildSummaryCard(
            context,
            'Paused',
            '${summary.pauseCount}',
            Icons.pause_circle_rounded,
            Theme.of(context).colorScheme.outline,
          ),
          _buildSummaryCard(
            context,
            'Skipped (F/R)',
            '${summary.skipFocusCount}/${summary.skipRestCount}',
            Icons.skip_next_rounded,
            Theme.of(context).colorScheme.error,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _changeDate(WidgetRef ref, int offset) {
    final current = ref.read(statsDateProvider);
    final period = ref.read(statsPeriodProvider);
    DateTime newDate = current;

    switch (period) {
      case StatsPeriod.day:
        newDate = current.add(Duration(days: offset));
        break;
      case StatsPeriod.week:
        newDate = current.add(Duration(days: offset * 7));
        break;
      case StatsPeriod.month:
        newDate = DateTime(current.year, current.month + offset, 1);
        break;
      case StatsPeriod.year:
        newDate = DateTime(current.year + offset, 1, 1);
        break;
    }
    ref.read(statsDateProvider.notifier).set(newDate);
  }

  String _formatDateRange(StatsPeriod period, DateTime date) {
    if (period == StatsPeriod.day) return DateFormat.yMMMd().format(date);
    if (period == StatsPeriod.week) {
      final start = date.subtract(Duration(days: date.weekday - 1));
      final end = start.add(const Duration(days: 6));
      return '${DateFormat.MMMd().format(start)} - ${DateFormat.MMMd().format(end)}';
    }
    if (period == StatsPeriod.month) return DateFormat.yMMM().format(date);
    return DateFormat.y().format(date);
  }

  Widget _buildMonthCalendar(
    BuildContext context,
    DateTime date,
    Map<DateTime, int> datasets,
  ) {
    return SingleChildScrollView(
      child: HeatMapCalendar(
        initDate: date,
        datasets: datasets,
        colorMode: ColorMode.opacity,
        defaultColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        textColor: Theme.of(context).colorScheme.onSurface,
        showColorTip: false,
        colorsets: {0: Theme.of(context).colorScheme.primary},
        onClick: (value) {
          SnackBarUtils.show(context, 'Focused: ${datasets[value] ?? 0} mins');
        },
      ),
    );
  }

  Widget _buildYearHeatMap(
    BuildContext context,
    DateTime date,
    Map<DateTime, int> datasets,
  ) {
    return SingleChildScrollView(
      child: HeatMap(
        datasets: datasets,
        startDate: DateTime(date.year, 1, 1),
        endDate: DateTime(date.year, 12, 31),
        colorMode: ColorMode.opacity,
        showText: false,
        scrollable: true,
        colorsets: {0: Theme.of(context).colorScheme.primary},
        onClick: (value) {
          SnackBarUtils.show(
            context,
            '${DateFormat.yMMMd().format(value)}: ${datasets[value] ?? 0} mins',
          );
        },
      ),
    );
  }

  Widget _buildBarChart(
    BuildContext context,
    StatsPeriod period,
    Map<int, double> data,
  ) {
    if (data.isEmpty) {
      return const Center(child: Text('No data for this period'));
    }

    final maxY =
        data.values.fold(0.0, (prev, curr) => curr > prev ? curr : prev) * 1.2;
    final targetMaxY = maxY < 60 ? 60.0 : maxY;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: targetMaxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) =>
                Theme.of(context).colorScheme.surfaceContainerHighest,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.round()} min',
                TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) =>
                  _getBottomTitles(value, meta, period),
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  '${value.toInt()}m',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: _getBarGroups(
          period,
          data,
          Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _getBottomTitles(double value, TitleMeta meta, StatsPeriod period) {
    const style = TextStyle(fontSize: 12, fontWeight: FontWeight.bold);
    String text = '';

    switch (period) {
      case StatsPeriod.day:
        // Value is hour 0-23. Show every 4 hours or so?
        if (value % 4 == 0) {
          text = '${value.toInt()}:00';
        }
        break;
      case StatsPeriod.week:
        // Value is weekday 1-7
        const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
        if (value >= 1 && value <= 7) {
          text = days[value.toInt() - 1];
        }
        break;
      case StatsPeriod.month:
      case StatsPeriod.year:
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Text(text, style: style),
    );
  }

  List<BarChartGroupData> _getBarGroups(
    StatsPeriod period,
    Map<int, double> data,
    Color color,
  ) {
    List<BarChartGroupData> groups = [];
    int start = 0, end = 0;

    switch (period) {
      case StatsPeriod.day:
        start = 0;
        end = 23;
        break;
      case StatsPeriod.week:
        start = 1;
        end = 7;
        break;
      default:
        break;
    }

    for (int i = start; i <= end; i++) {
      final value = data[i] ?? 0.0;
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value,
              color: color,
              width: 12,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }
    return groups;
  }
}
