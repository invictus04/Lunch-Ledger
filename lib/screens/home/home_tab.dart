import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/space.dart';
import '../../models/space_member.dart';
import '../../models/tiffin_log.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import '../../widgets/cutoff_countdown_banner.dart';
import '../../widgets/squad_status_strip.dart';
import '../../widgets/tiffin_choice_card.dart';

/// Home Dashboard tab: today's meal logger, cut-off countdown/warning, and
/// real-time horizontal Squad View.
class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.space,
    required this.currentUserId,
    required this.members,
    required this.todayLogs,
    required this.isSavingLog,
    required this.onSelectType,
    required this.onRefresh,
    this.nowOverride,
  });

  final Space space;
  final String currentUserId;
  final List<SpaceMember> members;
  final List<TiffinLog> todayLogs;
  final bool isSavingLog;
  final ValueChanged<TiffinType> onSelectType;
  final Future<void> Function() onRefresh;
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Code: ${widget.space.inviteCode}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CutoffCountdownBanner(
            space: widget.space,
            now: _now,
          ),
          const SizedBox(height: 14),
          TiffinChoiceCard(
            space: widget.space,
            todayLog: myTodayLog,
            isSaving: widget.isSavingLog,
            onSelect: widget.onSelectType,
          ),
          const SizedBox(height: 20),
          SquadStatusStrip(
            members: widget.members,
            todayLogsByUser: logsByUser,
            currentUserId: widget.currentUserId,
          ),
        ],
      ),
    );
  }
}

