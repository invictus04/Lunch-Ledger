import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/app_config.dart';
import '../../models/space.dart';
import '../../models/space_member.dart';
import '../../models/space_menu_item.dart';
import '../../models/tiffin_log.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import '../../widgets/cutoff_countdown_banner.dart';
import '../../widgets/member_monthly_breakdown_sheet.dart';
import '../../widgets/squad_status_strip.dart';
import '../../widgets/tiffin_choice_card.dart';

/// Home Dashboard tab: today's meal logger, cut-off countdown/warning, and
/// real-time horizontal Squad View.
class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.space,
    this.menuItems = const [],
    required this.currentUserId,
    required this.members,
    required this.todayLogs,
    required this.isSavingLog,
    required this.onSelectChoice,
    required this.onRefresh,
    this.fetchSpaceMonthLogs,
    this.onLeaderUpdateLog,
    this.nowOverride,
  });

  final Space space;
  final List<SpaceMenuItem> menuItems;
  final String currentUserId;
  final List<SpaceMember> members;
  final List<TiffinLog> todayLogs;
  final bool isSavingLog;
  final void Function({
    required TiffinType type,
    String? menuItemId,
    String? itemName,
  }) onSelectChoice;
  final Future<void> Function() onRefresh;
  final Future<List<TiffinLog>> Function(DateTime month)? fetchSpaceMonthLogs;
  final Future<void> Function({
    required String userId,
    required DateTime date,
    required TiffinType type,
    String? menuItemId,
    String? itemName,
  })? onLeaderUpdateLog;
  final DateTime? nowOverride;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Timer? _clockTimer;

  DateTime get _now => widget.nowOverride ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.nowOverride == null) {
      _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logsByUser = <String, TiffinLog>{
      for (final log in widget.todayLogs) log.userId: log,
    };
    final myTodayLog = logsByUser[widget.currentUserId];
    final dateLabel = DateFormat('EEEE, d MMM yyyy').format(_now);
    final isLeader = widget.space.leaderId == widget.currentUserId;
    final isPastCutoff = widget.space.isPastCutoffAt(_now);
    final isLocked = isPastCutoff && !isLeader;
    final isLeaderOverride = isPastCutoff && isLeader;

    return RefreshIndicator(
      onRefresh: () => AppLogger.traceAsync(
        'HomeTab',
        'Pull-to-refresh workspace ($dateLabel)',
        widget.onRefresh,
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.space.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppTheme.mutedInk,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  SharePlus.instance.share(
                    ShareParams(
                      text: AppConfig.buildShareMessage(
                        spaceName: widget.space.name,
                        inviteCode: widget.space.inviteCode,
                      ),
                      subject: 'Join "${widget.space.name}" on Lunch Ledger',
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.share_rounded,
                        size: 13,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Code: ${widget.space.inviteCode}',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CutoffCountdownBanner(
            space: widget.space,
            now: _now,
            isLeader: isLeader,
          ),
          const SizedBox(height: 14),
          TiffinChoiceCard(
            space: widget.space,
            menuItems: widget.menuItems,
            todayLog: myTodayLog,
            isSaving: widget.isSavingLog,
            isLocked: isLocked,
            isLeaderOverride: isLeaderOverride,
            onSelect: widget.onSelectChoice,
          ),
          const SizedBox(height: 20),
          SquadStatusStrip(
            members: widget.members,
            todayLogsByUser: logsByUser,
            currentUserId: widget.currentUserId,
            onTapMember: widget.fetchSpaceMonthLogs != null ? _showMemberBreakdown : null,
          ),
        ],
      ),
    );
  }

  void _showMemberBreakdown(SpaceMember member) {
    if (widget.fetchSpaceMonthLogs == null) return;
    AppLogger.nav(
      'Opened member breakdown sheet (${member.user.displayName})',
      scope: 'HomeTab',
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MemberMonthlyBreakdownSheet(
        member: member,
        space: widget.space,
        menuItems: widget.menuItems,
        isLeader: widget.space.leaderId == widget.currentUserId,
        fetchMonthLogs: widget.fetchSpaceMonthLogs!,
        onLeaderUpdateLog: widget.onLeaderUpdateLog,
      ),
    );
  }
}

