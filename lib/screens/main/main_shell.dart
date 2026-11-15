import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/space.dart';
import '../../models/space_member.dart';
import '../../models/tiffin_log.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/space_service.dart';
import '../../services/supabase_error_mapper.dart';
import '../../services/tiffin_service.dart';
import '../../utils/app_logger.dart';
import '../history/history_tab.dart';
import '../home/home_tab.dart';
import '../money/money_tab.dart';
import '../settings/settings_tab.dart';

/// Main 4-tab shell holding the active Space, Realtime subscription, and
/// Home / History / Money / Settings tabs.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.initialContext,
    required this.authService,
    required this.spaceService,
    required this.tiffinService,
    required this.onSpaceLeft,
  });

  final ActiveSpaceContext initialContext;
  final AuthService authService;
  final SpaceService spaceService;
  final TiffinService tiffinService;
  final VoidCallback onSpaceLeft;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;
  late UserProfile _profile;
  late Space _space;
  List<SpaceMember> _members = const [];
  List<TiffinLog> _todayLogs = const [];
  int _dataVersion = 0;
  bool _isSavingLog = false;
  bool _isInitialLoading = true;
  RealtimeChannel? _realtimeChannel;
  Timer? _debounceRefresh;

  bool get _isLeader => _space.leaderId == _profile.id;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialContext.profile;
    _space = widget.initialContext.space!;
    AppLogger.nav(
      'Entered MainShell (spaceId=${_space.id}, userId=${_profile.id})',
      scope: 'MainShell',
    );
    _subscribeRealtime();
    _refreshWorkspaceData();
  }

  @override
  void dispose() {
    AppLogger.info('MainShell', 'Disposing MainShell and cleaning up realtime');
    _debounceRefresh?.cancel();
    if (_realtimeChannel != null) {
      unawaited(widget.tiffinService.unsubscribe(_realtimeChannel!));
    }
    super.dispose();
  }

  void _subscribeRealtime() {
    _realtimeChannel = widget.tiffinService.subscribeToSpace(
      spaceId: _space.id,
      onDataChanged: () {
        AppLogger.realtime(
          'MainShell',
          'Realtime change received; scheduling refresh (250ms debounce)',
        );
        _debounceRefresh?.cancel();
        _debounceRefresh = Timer(const Duration(milliseconds: 250), () {
          if (mounted) {
            _refreshWorkspaceData();
          }
        });
      },
    );
  }

  Future<void> _refreshWorkspaceData() async {
    try {
      await AppLogger.traceAsync<void>(
        'MainShell',
        'Refresh workspace data (spaceId=${_space.id})',
        () async {
          final profile = await widget.authService.fetchCurrentProfile();
          if (profile == null) {
            AppLogger.warn(
              'MainShell',
              'fetchCurrentProfile returned null during workspace refresh',
            );
            return;
          }
          final active = await widget.spaceService.fetchActiveContext(profile);
          if (!active.hasActiveSpace) {
            AppLogger.nav(
              'User no longer in active space; invoking onSpaceLeft',
              scope: 'MainShell',
            );
            if (mounted) widget.onSpaceLeft();
            return;
          }

          final membersFuture =
              widget.spaceService.fetchSpaceMembers(active.space!.id);
          final todayLogsFuture = widget.tiffinService.fetchLogsForDate(
            spaceId: active.space!.id,
            date: DateTime.now(),
          );

          final results = await Future.wait([membersFuture, todayLogsFuture]);
          if (!mounted) return;
          final members = results[0] as List<SpaceMember>;
          final todayLogs = results[1] as List<TiffinLog>;
          setState(() {
            _profile = profile;
            _space = active.space!;
            _members = members;
            _todayLogs = todayLogs;
            _dataVersion++;
            _isInitialLoading = false;
          });
          AppLogger.info(
            'MainShell',
            'Workspace synced (members=${members.length}, todayLogs=${todayLogs.length}, dataVersion=$_dataVersion)',
          );
        },
      );
    } catch (e, st) {
      AppLogger.error(
        'MainShell',
        'Failed to refresh workspace data',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        setState(() => _isInitialLoading = false);
        _showError(e);
      }
    }
  }

  Future<void> _selectTodayType(TiffinType type) async {
    setState(() => _isSavingLog = true);
    try {
      final saved = await AppLogger.traceAsync(
        'MainShell',
        'Select today tiffin choice (${type.name})',
        () => widget.tiffinService.upsertDailyLog(
          userId: _profile.id,
          spaceId: _space.id,
          date: DateTime.now(),
          type: type,
        ),
      );
      if (!mounted) return;
      setState(() {
        final updated = _todayLogs
            .where((l) => l.userId != _profile.id)
            .toList()
          ..add(saved);
        _todayLogs = updated;
        _dataVersion++;
      });
    } catch (e, st) {
      AppLogger.error(
        'MainShell',
        'Failed to save today tiffin choice (${type.name})',
        error: e,
        stackTrace: st,
      );
      _showError(e);
    } finally {
      if (mounted) setState(() => _isSavingLog = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final msg = error is AppFailure ? error.message : error.toString();
    AppLogger.warn('MainShell', 'Showing error snackbar: $msg');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFB91C1C),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(
        space: _space,
        currentUserId: _profile.id,
        members: _members,
        todayLogs: _todayLogs,
        isSavingLog: _isSavingLog,
        onSelectType: _selectTodayType,
        onRefresh: _refreshWorkspaceData,
      ),
      HistoryTab(
        currentUserId: _profile.id,
        refreshVersion: _dataVersion,
        fetchSpaceMonthLogs: (month) => widget.tiffinService.fetchSpaceMonthLogs(
          spaceId: _space.id,
          month: month,
        ),
      ),
      MoneyTab(
        space: _space,
        currentUserId: _profile.id,
        isLeader: _isLeader,
        members: _members,
        refreshVersion: _dataVersion,
        fetchSpaceMonthLogs: (month) => widget.tiffinService.fetchSpaceMonthLogs(
          spaceId: _space.id,
          month: month,
        ),
      ),
      SettingsTab(
        profile: _profile,
        email: widget.authService.currentUser?.email,
        space: _space,
        isLeader: _isLeader,
        members: _members,
        onUpdateName: (name) => AppLogger.traceAsync(
          'MainShell',
          'Update profile name',
          () async {
            final updated = await widget.authService.updateFullName(name);
            if (mounted) {
              setState(() => _profile = updated);
              await _refreshWorkspaceData();
            }
          },
        ),
        onUpdateSpaceSettings: ({
          required priceFull,
          required priceHalf,
          required cutoffHour,
          required cutoffMinute,
        }) =>
            AppLogger.traceAsync(
          'MainShell',
          'Update space settings (full=$priceFull, half=$priceHalf, cutoff=$cutoffHour:$cutoffMinute)',
          () async {
            final updated = await widget.spaceService.updateSpaceSettings(
              spaceId: _space.id,
              priceFull: priceFull,
              priceHalf: priceHalf,
              cutoffHour: cutoffHour,
              cutoffMinute: cutoffMinute,
            );
            if (mounted) {
              setState(() => _space = updated);
            }
          },
        ),
        onTransferLeadership: (newLeaderId) => AppLogger.traceAsync(
          'MainShell',
          'Transfer leadership (newLeaderId=$newLeaderId)',
          () async {
            await widget.spaceService.transferLeadership(newLeaderId);
            await _refreshWorkspaceData();
          },
        ),
        onLeaveSpace: () => AppLogger.traceAsync(
          'MainShell',
          'Leave space (spaceId=${_space.id})',
          () async {
            await widget.spaceService.leaveSpace();
            if (mounted) widget.onSpaceLeft();
          },
        ),
        onSignOut: () => AppLogger.traceAsync(
          'MainShell',
          'Sign out from MainShell',
          widget.authService.signOut,
        ),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: _isInitialLoading
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(index: _tabIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) {
          const tabNames = ['Home', 'History', 'Money', 'Settings'];
          final fromTab = (_tabIndex >= 0 && _tabIndex < tabNames.length)
              ? tabNames[_tabIndex]
              : '$_tabIndex';
          final toTab =
              (index >= 0 && index < tabNames.length) ? tabNames[index] : '$index';
          if (index != _tabIndex) {
            AppLogger.nav('Switched tab: $fromTab -> $toTab', scope: 'MainShell');
          }
          setState(() => _tabIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Money',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
