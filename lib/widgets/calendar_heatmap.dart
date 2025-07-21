import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarHeatmapData {
  final DateTime date;
  final int value;

  CalendarHeatmapData({required this.date, required this.value});
}

class CalendarHeatmap extends StatefulWidget {
  final List<CalendarHeatmapData> data;
  final DateTime startDate;
  final DateTime endDate;
  final double cellSize;
  final double spacing;
  final Color baseColor;
  final Color emptyColor;
  final Function(CalendarHeatmapData?)? onTap;

  const CalendarHeatmap({
    super.key,
    required this.data,
    required this.startDate,
    required this.endDate,
    this.cellSize = 8,
    this.spacing = 2,
    this.baseColor = Colors.green,
    this.emptyColor = Colors.grey,
    this.onTap,
  });

  factory CalendarHeatmap.withDefaults({
    Key? key,
    required List<CalendarHeatmapData> data,
    DateTime? startDate,
    DateTime? endDate,
    double cellSize = 8,
    double spacing = 2,
    Color baseColor = Colors.green,
    Color emptyColor = Colors.grey,
    Function(CalendarHeatmapData?)? onTap,
  }) {
    final now = DateTime.now();
    // Show last 6 months like LeetCode
    final defaultStart = DateTime(now.year, now.month - 6, 1);
    final defaultEnd = now;

    return CalendarHeatmap(
      key: key,
      data: data,
      startDate: startDate ?? defaultStart,
      endDate: endDate ?? defaultEnd,
      cellSize: cellSize,
      spacing: spacing,
      baseColor: baseColor,
      emptyColor: emptyColor,
      onTap: onTap,
    );
  }

  @override
  State<CalendarHeatmap> createState() => _CalendarHeatmapState();
}

class _CalendarHeatmapState extends State<CalendarHeatmap> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Auto-scroll to the right (latest dates) after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final months = _generateMonthsData();
    final maxValue = widget.data.isNotEmpty
        ? widget.data.map((d) => d.value).reduce((a, b) => a > b ? a : b)
        : 0;

    return Column(
      children: [
        // Scrollable month view like LeetCode
        SizedBox(
          height: 100,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            controller: _scrollController, // Assign the controller
            child: Row(
              children: months
                  .map((monthData) => _buildMonth(monthData, maxValue))
                  .toList(),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Less',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                for (int i = 0; i < 5; i++)
                  Container(
                    width: widget.cellSize,
                    height: widget.cellSize,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: i == 0
                          ? widget.emptyColor.withOpacity(0.1)
                          : widget.baseColor.withOpacity(0.2 + i * 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Text(
              'More',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonth(MonthData monthData, int maxValue) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month label
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              DateFormat('MMM').format(monthData.month),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),

          // Calendar grid for the month
          SizedBox(
            width: _getMonthWidth(),
            child: Wrap(
              spacing: widget.spacing,
              runSpacing: widget.spacing,
              children: monthData.days.map((day) {
                final dayData = widget.data.firstWhere(
                  (d) => DateUtils.isSameDay(d.date, day),
                  orElse: () => CalendarHeatmapData(date: day, value: 0),
                );

                final intensity = maxValue > 0 ? dayData.value / maxValue : 0.0;
                final color = dayData.value > 0
                    ? widget.baseColor.withOpacity(0.2 + intensity * 0.8)
                    : widget.emptyColor.withOpacity(0.1);

                return GestureDetector(
                  onTap: () =>
                      widget.onTap?.call(dayData.value > 0 ? dayData : null),
                  child: Container(
                    width: widget.cellSize,
                    height: widget.cellSize,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<MonthData> _generateMonthsData() {
    final months = <MonthData>[];
    DateTime current = DateTime(
      widget.startDate.year,
      widget.startDate.month,
      1,
    );
    final end = DateTime(
      widget.endDate.year,
      widget.endDate.month,
      widget.endDate.day,
    );

    while (current.isBefore(end) || current.month == end.month) {
      final days = <DateTime>[];

      DateTime day = current;
      while (day.month == current.month &&
          (day.isBefore(end) || DateUtils.isSameDay(day, end))) {
        days.add(day);
        day = day.add(const Duration(days: 1));
      }

      months.add(MonthData(month: current, days: days));
      current = DateTime(current.year, current.month + 1, 1);
    }

    return months;
  }

  double _getMonthWidth() {
    // Calculate width for a month (roughly 7 columns for weekdays)
    return 7 * (widget.cellSize + widget.spacing) - widget.spacing;
  }
}

class MonthData {
  final DateTime month;
  final List<DateTime> days;

  MonthData({required this.month, required this.days});
}
