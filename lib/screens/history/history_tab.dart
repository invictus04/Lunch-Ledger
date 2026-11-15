import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/app_config.dart';
import '../../models/tiffin_log.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import '../../widgets/month_calendar_grid.dart';
import '../../widgets/month_selector_bar.dart';
import '../../widgets/tiffin_style_helper.dart';

/// Strictly read-only History tab showing past logs in Calendar or List mode
/// so users can audit daily entries and their snapshotted INR prices.
class HistoryTab extends StatefulWidget {
  const HistoryTab({
    super.key,
    required this.currentUserId,
    required this.refreshVersion,
    required this.fetchSpaceMonthLogs,
    this.nowOverride,
  });

  final String currentUserId;
  final int refreshVersion;
  final Future<List<TiffinLog>> Function(DateTime month) fetchSpaceMonthLogs;
  final DateTime? nowOverride;

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  late DateTime _selectedMonth;
  int? _selectedDay;
  bool _showListView = false;
  bool _isLoading = true;
  String? _error;
  List<TiffinLog> _userLogs = const [];

  DateTime get _today => widget.nowOverride ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(_today.year, _today.month);
    _selectedDay = _today.day;
    _loadLogs();
  }

  @override
  void didUpdateWidget(covariant HistoryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshVersion != widget.refreshVersion) {
      _loadLogs();
    }
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final monthLabel =
        '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
    try {
      final allLogs = await AppLogger.traceAsync(
        'HistoryTab',
        'Load space logs ($monthLabel)',
        () => widget.fetchSpaceMonthLogs(_selectedMonth),
        describeResult: (logs) => 'totalSpaceLogs=${logs.length}',
      );
      final mine = allLogs
          .where((l) => l.userId == widget.currentUserId)
          .toList()
        ..sort((a, b) => b.logDate.compareTo(a.logDate));

      AppLogger.info(
        'HistoryTab',
        'Filtered history logs for $monthLabel (mine=${mine.length}, spaceTotal=${allLogs.length})',
      );

      if (mounted) {
        setState(() {
          _userLogs = mine;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      AppLogger.error(
        'HistoryTab',
        'Failed to load history logs for $monthLabel',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _changeMonth(int delta) {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    final isCurrent = next.year == _today.year && next.month == _today.month;
    AppLogger.nav(
      'Changed history month: '
      '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')} -> '
      '${next.year}-${next.month.toString().padLeft(2, '0')}',
      scope: 'HistoryTab',
    );
    setState(() {
      _selectedMonth = next;
      _selectedDay = isCurrent ? _today.day : 1;
    });
    _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    final logsByDay = <int, TiffinLog>{
      for (final log in _userLogs) log.logDate.day: log,
    };
    final selectedLog = _selectedDay != null ? logsByDay[_selectedDay!] : null;

    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'History',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Read-only record of your daily logs and snapshotted costs.',
                      style: TextStyle(fontSize: 13, color: AppTheme.mutedInk),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.skipSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Read Only',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.skipColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          MonthSelectorBar(
            month: _selectedMonth,
            today: _today,
            onPrev: () => _changeMonth(-1),
            onNext: () => _changeMonth(1),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                icon: Icon(Icons.calendar_month_outlined),
                label: Text('Calendar'),
              ),
              ButtonSegment<bool>(
                value: true,
                icon: Icon(Icons.view_list_rounded),
                label: Text('List'),
              ),
            ],
            selected: {_showListView},
            onSelectionChanged: (values) {
              final showList = values.first;
              if (showList != _showListView) {
                AppLogger.nav(
                  'Switched history view: ${showList ? 'List' : 'Calendar'}',
                  scope: 'HistoryTab',
                );
              }
              setState(() => _showListView = showList);
            },
          ),
          const SizedBox(height: 14),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                ),
              ),
            )
          else if (!_showListView) ...[
            MonthCalendarGrid(
              month: _selectedMonth,
              logsByDay: logsByDay,
              selectedDay: _selectedDay,
              today: _today,
              onSelectDay: (day) {
                AppLogger.info(
                  'HistoryTab',
                  'Selected calendar day ${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
                );
                setState(() => _selectedDay = day);
              },
            ),
            const SizedBox(height: 12),
            if (_selectedDay != null)
              _SelectedDayDetailCard(
                date: DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month,
                  _selectedDay!,
                ),
                log: selectedLog,
              ),
          ] else if (_userLogs.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No tiffin logs recorded for this month.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.mutedInk),
                ),
              ),
            )
          else
            ..._userLogs.map((log) => _LogRowCard(log: log)),
        ],
      ),
    );
  }
}

class _SelectedDayDetailCard extends StatelessWidget {
  const _SelectedDayDetailCard({
    required this.date,
    required this.log,
  });

  final DateTime date;
  final TiffinLog? log;

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('EEE, d MMM yyyy').format(date);
    final style = TiffinVisualStyle.of(log?.type);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: style.softBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(style.icon, color: style.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    log == null
                        ? 'No tiffin logged on this date'
                        : '${style.label} tiffin · Snapshotted at log time',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
            if (log != null)
              Text(
                AppConfig.formatInr(log!.cost),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: style.color,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LogRowCard extends StatelessWidget {
  const _LogRowCard({required this.log});

  final TiffinLog log;

  @override
  Widget build(BuildContext context) {
    final style = TiffinVisualStyle.of(log.type);
    final dateText = DateFormat('EEE, d MMM yyyy').format(log.logDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: style.softBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(style.icon, color: style.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.ink,
                    ),
                  ),
                  Text(
                    style.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: style.color,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              AppConfig.formatInr(log.cost),
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
