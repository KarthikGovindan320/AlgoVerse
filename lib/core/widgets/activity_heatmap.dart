import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'package:intl/intl.dart';

/// Activity heatmap showing 52 weeks × 7 days.
/// [activity] maps date strings ("2025-01-14") to problem counts.
class ActivityHeatmap extends StatefulWidget {
  final Map<String, int> activity;

  const ActivityHeatmap({super.key, required this.activity});

  @override
  State<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends State<ActivityHeatmap> {
  String? _tooltipDate;
  final _scrollController = ScrollController();

  static const double _cellSize = 11;
  static const double _cellGap = 2;
  static const double _step = _cellSize + _cellGap;

  @override
  void initState() {
    super.initState();
    // Scroll to current week after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _cellColor(int count) {
    if (count == 0) return const Color(0xFF0D1117);
    if (count == 1) return const Color(0xFF003D2E);
    if (count == 2) return const Color(0xFF00694E);
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Start 52 weeks back from the most recent Sunday
    final weekday = now.weekday % 7; // Sunday = 0
    final startDate = now
        .subtract(Duration(days: weekday + 51 * 7))
        .copyWith(hour: 0, minute: 0, second: 0, microsecond: 0);

    final weeks = 52;
    final dayFmt = DateFormat('yyyy-MM-dd');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day labels
        Row(
          children: [
            const SizedBox(width: 20),
            ...['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) => SizedBox(
                  width: _step,
                  child: Text(d,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted)),
                )),
          ],
        ),
        const SizedBox(height: 4),

        // Scrollable grid
        SizedBox(
          height: 7 * _step,
          child: Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(weeks, (week) {
                    return Column(
                      children: List.generate(7, (dow) {
                        final date =
                            startDate.add(Duration(days: week * 7 + dow));
                        final key = dayFmt.format(date);
                        final count = widget.activity[key] ?? 0;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _tooltipDate = key;
                          }),
                          child: Container(
                            width: _cellSize,
                            height: _cellSize,
                            margin: const EdgeInsets.all(_cellGap / 2),
                            decoration: BoxDecoration(
                              color: _cellColor(count),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    );
                  }),
                ),
              ),

              // Tooltip
              if (_tooltipDate != null)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _tooltipDate = null),
                    child: Container(
                      color: Colors.transparent,
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Builder(builder: (_) {
                          final count = widget.activity[_tooltipDate!] ?? 0;
                          final d = DateTime.parse(_tooltipDate!);
                          final label = DateFormat('MMM d').format(d);
                          return Text(
                            count == 0
                                ? '$label — No activity'
                                : '$label — $count problem${count > 1 ? 's' : ''} solved',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textPrimary),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Legend
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Less',
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
            const SizedBox(width: 4),
            ...([0, 1, 2, 3]).map((i) => Container(
                  width: _cellSize,
                  height: _cellSize,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _cellColor(i),
                    borderRadius: BorderRadius.circular(2),
                  ),
                )),
            const SizedBox(width: 4),
            Text('More',
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
          ],
        ),
      ],
    );
  }
}
