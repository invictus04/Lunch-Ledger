import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import '../models/space.dart';
import '../models/space_member.dart';
import '../models/space_menu_item.dart';
import '../models/tiffin_log.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import 'tiffin_style_helper.dart';

/// Modal bottom sheet displaying a colleague's monthly tiffin records, total bill (₹),
/// breakdown by meal item, and WhatsApp billing summary export for end-of-month settlement.
class MemberMonthlyBreakdownSheet extends StatefulWidget {
  const MemberMonthlyBreakdownSheet({
    super.key,
    required this.member,
    required this.space,
    this.menuItems = const [],
    required this.isLeader,
    required this.fetchMonthLogs,
    this.onLeaderUpdateLog,
  });

  final SpaceMember member;
  final Space space;
  final List<SpaceMenuItem> menuItems;
  final bool isLeader;
  final Future<List<TiffinLog>> Function(DateTime month) fetchMonthLogs;
  final Future<void> Function({
    required String userId,
    required DateTime date,
    required TiffinType type,
    String? menuItemId,
    String? itemName,
  })? onLeaderUpdateLog;

  @override
  State<MemberMonthlyBreakdownSheet> createState() =>
      _MemberMonthlyBreakdownSheetState();
}

class _MemberMonthlyBreakdownSheetState
    extends State<MemberMonthlyBreakdownSheet> {
  late DateTime _selectedMonth;
  bool _isLoading = true;
  String? _errorMessage;
  List<TiffinLog> _userLogs = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final allMonthLogs = await widget.fetchMonthLogs(_selectedMonth);
      if (!mounted) return;

      final filtered = allMonthLogs
          .where((l) => l.userId == widget.member.userId)
          .toList()
        ..sort((a, b) => b.logDate.compareTo(a.logDate));

      setState(() {
        _userLogs = filtered;
        _isLoading = false;
      });
    } catch (e, st) {
      AppLogger.error(
        'MemberMonthlyBreakdownSheet',
        'Failed to fetch logs for member ${widget.member.userId}',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load records for this month.';
          _isLoading = false;
        });
      }
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
    });
    _loadLogs();
  }

  double get _totalSpend =>
      _userLogs.fold<double>(0.0, (sum, log) => sum + log.cost);

  int get _mealsCount =>
      _userLogs.where((l) => l.type != TiffinType.skip).length;

  int get _skipCount =>
      _userLogs.where((l) => l.type == TiffinType.skip).length;

  Map<String, int> get _countsByItem {
    final map = <String, int>{};
    for (final log in _userLogs) {
      if (log.type == TiffinType.skip) continue;
      final label = log.displayLabel;
      map[label] = (map[label] ?? 0) + 1;
    }
    return map;
  }

  String _buildWhatsAppSummary() {
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);
    final buffer = StringBuffer()
      ..writeln('🍱 *Lunch Ledger — Monthly Bill Summary*')
      ..writeln('👤 *Colleague:* ${widget.member.user.displayName}')
      ..writeln('🏢 *Space:* ${widget.space.name}')
      ..writeln('📅 *Month:* $monthLabel')
      ..writeln('──────────────────────────────');

    final counts = _countsByItem;
    if (counts.isEmpty && _skipCount == 0) {
      buffer.writeln('No meals logged for this month.');
    } else {
      counts.forEach((item, count) {
        buffer.writeln('• $item: $count days');
      });
      if (_skipCount > 0) {
        buffer.writeln('• Days Skipped: $_skipCount days');
      }
    }

    buffer
      ..writeln('──────────────────────────────')
      ..writeln('💰 *TOTAL PAYABLE:* ${AppConfig.formatInr(_totalSpend)}');

    return buffer.toString();
  }

  Future<void> _shareBill() async {
    try {
      final text = _buildWhatsAppSummary();
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject:
              'Lunch Bill for ${widget.member.user.displayName} (${DateFormat('MMM yyyy').format(_selectedMonth)})',
        ),
      );
    } catch (e, st) {
      AppLogger.error(
        'MemberMonthlyBreakdownSheet',
        'Failed to share bill',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _showLeaderEditDialog(TiffinLog? existingLog) async {
    if (!widget.isLeader || widget.onLeaderUpdateLog == null) return;

    DateTime selectedDate = existingLog?.logDate ?? DateTime.now();
    TiffinType selectedType = existingLog?.type ?? TiffinType.full;
    String? selectedMenuItemId = existingLog?.menuItemId;
    String? selectedItemName = existingLog?.itemName;

    final activeItems = widget.menuItems.where((i) => i.isActive).toList();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(
              existingLog == null ? 'Log Meal for Colleague' : 'Adjust Colleague Meal',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Colleague: ${widget.member.user.displayName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Date: ${DateFormat('EEE, d MMM yyyy').format(selectedDate)}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.mutedInk),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Choose Meal:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (activeItems.isNotEmpty) ...[
                    ...activeItems.map((item) {
                      final isSelected = selectedType != TiffinType.skip &&
                          (selectedMenuItemId == item.id ||
                              selectedItemName == item.name);
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          setDialogState(() {
                            selectedType = TiffinType.custom;
                            selectedMenuItemId = item.id;
                            selectedItemName = item.name;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primarySoft
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.cardBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.mutedInk,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: isSelected
                                        ? AppTheme.primary
                                        : AppTheme.ink,
                                  ),
                                ),
                              ),
                              Text(
                                AppConfig.formatInr(item.price),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: isSelected
                                      ? AppTheme.primary
                                      : AppTheme.mutedInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ] else ...[
                    _buildDialogOption(
                      title: 'Full Tiffin',
                      subtitle: AppConfig.formatInr(widget.space.priceFull),
                      isSelected: selectedType == TiffinType.full,
                      onTap: () {
                        setDialogState(() {
                          selectedType = TiffinType.full;
                          selectedMenuItemId = null;
                          selectedItemName = 'Full Tiffin';
                        });
                      },
                    ),
                    _buildDialogOption(
                      title: 'Half Tiffin',
                      subtitle: AppConfig.formatInr(widget.space.priceHalf),
                      isSelected: selectedType == TiffinType.half,
                      onTap: () {
                        setDialogState(() {
                          selectedType = TiffinType.half;
                          selectedMenuItemId = null;
                          selectedItemName = 'Half Tiffin';
                        });
                      },
                    ),
                  ],
                  _buildDialogOption(
                    title: 'Skip Lunch',
                    subtitle: 'Free (₹0)',
                    isSelected: selectedType == TiffinType.skip,
                    onTap: () {
                      setDialogState(() {
                        selectedType = TiffinType.skip;
                        selectedMenuItemId = null;
                        selectedItemName = 'Skip';
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('Save Override'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true && mounted) {
      try {
        await widget.onLeaderUpdateLog!(
          userId: widget.member.userId,
          date: selectedDate,
          type: selectedType,
          menuItemId: selectedMenuItemId,
          itemName: selectedItemName,
        );
        await _loadLogs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Meal log updated successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update log: $e'),
              backgroundColor: const Color(0xFFB91C1C),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header: Colleague profile info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: widget.member.isLeader
                          ? AppTheme.primarySoft
                          : AppTheme.skipSoft,
                      child: Text(
                        widget.member.user.initials,
                        style: TextStyle(
                          color: widget.member.isLeader
                              ? AppTheme.primary
                              : AppTheme.skipColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.member.user.displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.member.isLeader
                                      ? AppTheme.primarySoft
                                      : AppTheme.skipSoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.member.isLeader ? 'Leader' : 'Member',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: widget.member.isLeader
                                        ? AppTheme.primary
                                        : AppTheme.skipColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.space.name,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.mutedInk,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),

              // Month Selector Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      tooltip: 'Previous month',
                      onPressed: _isLoading ? null : () => _changeMonth(-1),
                    ),
                    Text(
                      monthLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      tooltip: 'Next month',
                      onPressed: _isLoading ? null : () => _changeMonth(1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Main content body
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFFB91C1C),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                FilledButton.tonal(
                                  onPressed: _loadLogs,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            children: [
                              // Total Bill & Meals Banner
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border:
                                      Border.all(color: AppTheme.cardBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'TOTAL MONTHLY BILL',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                        color: AppTheme.mutedInk,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          AppConfig.formatInr(_totalSpend),
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primarySoft,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '$_mealsCount meals logged',
                                            style: const TextStyle(
                                              color: AppTheme.primary,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Itemized chips
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        ..._countsByItem.entries.map((e) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: AppTheme.cardBorder,
                                              ),
                                            ),
                                            child: Text(
                                              '${e.value}x ${e.key}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.ink,
                                              ),
                                            ),
                                          );
                                        }),
                                        if (_skipCount > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.skipSoft,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '$_skipCount skipped',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.skipColor,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Action Bar: Share WhatsApp Bill & Leader Add Meal
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: _userLogs.isEmpty
                                          ? null
                                          : _shareBill,
                                      icon: const Icon(
                                        Icons.share_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Share Bill Summary'),
                                    ),
                                  ),
                                  if (widget.isLeader &&
                                      widget.onLeaderUpdateLog != null) ...[
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _showLeaderEditDialog(null),
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('Add Meal'),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Date-by-Date Log History
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Daily Records',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.ink,
                                    ),
                                  ),
                                  Text(
                                    '${_userLogs.length} days recorded',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppTheme.mutedInk,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              if (_userLogs.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'No tiffins logged for this month.',
                                    style: TextStyle(color: AppTheme.mutedInk),
                                  ),
                                )
                              else
                                ..._userLogs.map((log) {
                                  final style = TiffinVisualStyle.of(
                                    log.type,
                                    customLabel: log.displayLabel,
                                  );
                                  final dateStr = DateFormat('EEE, d MMM')
                                      .format(log.logDate);

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppTheme.cardBorder,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          style.icon,
                                          size: 20,
                                          color: style.color,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                log.displayLabel,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13.5,
                                                  color: AppTheme.ink,
                                                ),
                                              ),
                                              Text(
                                                dateStr,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.mutedInk,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          log.cost == 0
                                              ? 'Free'
                                              : AppConfig.formatInr(log.cost),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                            color: log.cost == 0
                                                ? AppTheme.skipColor
                                                : AppTheme.ink,
                                          ),
                                        ),
                                        if (widget.isLeader &&
                                            widget.onLeaderUpdateLog !=
                                                null) ...[
                                          const SizedBox(width: 4),
                                          IconButton(
                                            iconSize: 18,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 28,
                                              minHeight: 28,
                                            ),
                                            icon:
                                                const Icon(Icons.edit_outlined),
                                            tooltip: 'Edit record',
                                            onPressed: () =>
                                                _showLeaderEditDialog(log),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }),
                              const SizedBox(height: 24),
                            ],
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDialogOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: isSelected ? AppTheme.primary : AppTheme.mutedInk,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isSelected ? AppTheme.primary : AppTheme.ink,
                ),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: isSelected ? AppTheme.primary : AppTheme.mutedInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
