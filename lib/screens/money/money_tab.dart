import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../models/money_summary.dart';
import '../../models/space.dart';
import '../../models/space_member.dart';
import '../../models/tiffin_log.dart';
import '../../services/tiffin_calculator.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import '../../widgets/leader_member_breakdown_card.dart';
import '../../widgets/month_selector_bar.dart';
import '../../widgets/week_budget_list.dart';

/// Money tab: INR monthly spend, week-wise breakdown & weekday projection,
/// current Space fixed prices, and Leader-only per-member billing summary.
class MoneyTab extends StatefulWidget {
  const MoneyTab({
    super.key,
    required this.space,
    required this.currentUserId,
    required this.isLeader,
    required this.members,
    required this.refreshVersion,
    required this.fetchSpaceMonthLogs,
    this.nowOverride,
  });

  final Space space;
  final String currentUserId;
  final bool isLeader;
  final List<SpaceMember> members;
  final int refreshVersion;
  final Future<List<TiffinLog>> Function(DateTime month) fetchSpaceMonthLogs;
  final DateTime? nowOverride;

  @override
  State<MoneyTab> createState() => _MoneyTabState();
}

class _MoneyTabState extends State<MoneyTab> {
  late DateTime _selectedMonth;
  bool _isLoading = true;
  String? _error;
  MonthlyBudgetSummary? _summary;

  DateTime get _today => widget.nowOverride ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(_today.year, _today.month);
    _loadSummary();
  }

  @override
  void didUpdateWidget(covariant MoneyTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshVersion != widget.refreshVersion ||
        oldWidget.space.priceFull != widget.space.priceFull ||
        oldWidget.space.priceHalf != widget.space.priceHalf ||
        oldWidget.members.length != widget.members.length) {
      _loadSummary();
    }
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final monthLabel =
        '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
    try {
      final logs = await AppLogger.traceAsync(
        'MoneyTab',
        'Load monthly summary logs ($monthLabel)',
        () => widget.fetchSpaceMonthLogs(_selectedMonth),
        describeResult: (rows) => 'logs=${rows.length}',
      );
      final summary = TiffinCalculator.buildMonthlySummary(
        month: _selectedMonth,
        now: _today,
        currentUserId: widget.currentUserId,
        space: widget.space,
        members: widget.members,
        spaceMonthLogs: logs,
      );
      AppLogger.info(
        'MoneyTab',
        'Built budget summary for $monthLabel (actual=${summary.actualSpend}, projected=${summary.projectedTotal}, weeks=${summary.weeks.length})',
      );
      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      AppLogger.error(
        'MoneyTab',
        'Failed to load monthly budget summary for $monthLabel',
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
    final next = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + delta,
    );
    AppLogger.nav(
      'Changed money month: '
      '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')} -> '
      '${next.year}-${next.month.toString().padLeft(2, '0')}',
      scope: 'MoneyTab',
    );
    setState(() {
      _selectedMonth = next;
    });
    _loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadSummary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Money & Budget',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'INR totals calculated from snapshotted daily prices.',
            style: TextStyle(fontSize: 13, color: AppTheme.mutedInk),
          ),
          const SizedBox(height: 14),
          MonthSelectorBar(
            month: _selectedMonth,
            today: _today,
            onPrev: () => _changeMonth(-1),
            onNext: () => _changeMonth(1),
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
          else if (_summary != null) ...[
            _MonthlyHeroCard(summary: _summary!),
            const SizedBox(height: 14),
            WeekBudgetList(
              month: _selectedMonth,
              weeks: _summary!.weeks,
            ),
            const SizedBox(height: 14),
            _FixedPricesCard(space: widget.space),
            if (widget.isLeader) ...[
              const SizedBox(height: 14),
              LeaderMemberBreakdownCard(
                rows: _summary!.memberBreakdown,
                grandTotal: _summary!.squadGrandTotal,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MonthlyHeroCard extends StatelessWidget {
  const _MonthlyHeroCard({required this.summary});

  final MonthlyBudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatColumn(
                    label: 'Spent This Month',
                    value: AppConfig.formatInr(summary.actualSpend),
                    valueColor: AppTheme.ink,
                  ),
                ),
                Expanded(
                  child: _StatColumn(
                    label: 'Projected Total',
                    value: AppConfig.formatInr(summary.projectedTotal),
                    valueColor: AppTheme.primary,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${summary.fullCount} Full · ${summary.halfCount} Half · ${summary.skipCount} Skip',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.ink,
                    ),
                  ),
                  Text(
                    summary.remainingWeekdays > 0
                        ? '${summary.remainingWeekdays} weekdays left'
                        : 'Month closed',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.mutedInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (summary.remainingWeekdays > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Estimate uses ${AppConfig.formatInr(summary.estimatedDailyRate)}/weekday across remaining Mon–Fri office days.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.mutedInk,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.valueColor,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppTheme.mutedInk,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _FixedPricesCard extends StatelessWidget {
  const _FixedPricesCard({required this.space});

  final Space space;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Space Prices',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PriceTile(
                    label: 'Full Tiffin',
                    price: AppConfig.formatInr(space.priceFull),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PriceTile(
                    label: 'Half Tiffin',
                    price: AppConfig.formatInr(space.priceHalf),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Past logs keep their original snapshotted price even if the Leader updates Space prices mid-month.',
              style: TextStyle(fontSize: 12, color: AppTheme.mutedInk),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceTile extends StatelessWidget {
  const _PriceTile({required this.label, required this.price});

  final String label;
  final String price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppTheme.mutedInk,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}
