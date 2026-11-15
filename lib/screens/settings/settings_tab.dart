import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_config.dart';
import '../../models/space.dart';
import '../../models/space_member.dart';
import '../../models/user_profile.dart';
import '../../services/supabase_error_mapper.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';

/// Settings tab: user profile, Space invite code, Leader price/cut-off admin
/// panel, leadership transfer, leave space (with 2-day cooldown), and sign out.
class SettingsTab extends StatefulWidget {
  const SettingsTab({
    super.key,
    required this.profile,
    required this.email,
    required this.space,
    required this.isLeader,
    required this.members,
    required this.onUpdateName,
    required this.onUpdateSpaceSettings,
    required this.onTransferLeadership,
    required this.onLeaveSpace,
    required this.onSignOut,
  });

  final UserProfile profile;
  final String? email;
  final Space space;
  final bool isLeader;
  final List<SpaceMember> members;
  final Future<void> Function(String fullName) onUpdateName;
  final Future<void> Function({
    required double priceFull,
    required double priceHalf,
    required int cutoffHour,
    required int cutoffMinute,
  }) onUpdateSpaceSettings;
  final Future<void> Function(String newLeaderId) onTransferLeadership;
  final Future<void> Function() onLeaveSpace;
  final Future<void> Function() onSignOut;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _priceFormKey = GlobalKey<FormState>();
  late final TextEditingController _fullPriceController;
  late final TextEditingController _halfPriceController;
  late int _cutoffHour;
  late int _cutoffMinute;

  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _fullPriceController = TextEditingController(
      text: _cleanNumber(widget.space.priceFull),
    );
    _halfPriceController = TextEditingController(
      text: _cleanNumber(widget.space.priceHalf),
    );
    _cutoffHour = widget.space.cutoffHour;
    _cutoffMinute = widget.space.cutoffMinute;
  }

  @override
  void didUpdateWidget(covariant SettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.space.priceFull != widget.space.priceFull) {
      _fullPriceController.text = _cleanNumber(widget.space.priceFull);
    }
    if (oldWidget.space.priceHalf != widget.space.priceHalf) {
      _halfPriceController.text = _cleanNumber(widget.space.priceHalf);
    }
    if (oldWidget.space.cutoffHour != widget.space.cutoffHour ||
        oldWidget.space.cutoffMinute != widget.space.cutoffMinute) {
      _cutoffHour = widget.space.cutoffHour;
      _cutoffMinute = widget.space.cutoffMinute;
    }
  }

  @override
  void dispose() {
    _fullPriceController.dispose();
    _halfPriceController.dispose();
    super.dispose();
  }

  String _cleanNumber(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFB91C1C) : null,
      ),
    );
  }

  Future<void> _editNameDialog() async {
    AppLogger.nav('Opened Update Name dialog', scope: 'SettingsTab');
    final controller = TextEditingController(text: widget.profile.displayName);
    final updated = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update Name'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Full Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (updated == null || updated.trim().isEmpty) {
      AppLogger.nav(
        'Update Name dialog closed without changes',
        scope: 'SettingsTab',
      );
      return;
    }

    setState(() => _isBusy = true);
    try {
      await AppLogger.traceAsync(
        'SettingsTab',
        'Update profile name',
        () => widget.onUpdateName(updated.trim()),
      );
      _showSnack('Profile name updated.');
    } catch (e, st) {
      AppLogger.error(
        'SettingsTab',
        'Failed to update profile name',
        error: e,
        stackTrace: st,
      );
      _showSnack(e is AppFailure ? e.message : e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _pickCutoffTime() async {
    AppLogger.nav('Opened cut-off time picker', scope: 'SettingsTab');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _cutoffHour, minute: _cutoffMinute),
    );
    if (picked != null && mounted) {
      AppLogger.info(
        'SettingsTab',
        'Selected cut-off time ${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
      );
      setState(() {
        _cutoffHour = picked.hour;
        _cutoffMinute = picked.minute;
      });
    } else {
      AppLogger.nav('Dismissed cut-off time picker', scope: 'SettingsTab');
    }
  }

  Future<void> _saveSpaceSettings() async {
    FocusScope.of(context).unfocus();
    if (!_priceFormKey.currentState!.validate()) {
      AppLogger.warn('SettingsTab', 'Space settings form validation failed');
      return;
    }

    final parsedFull = double.tryParse(_fullPriceController.text.trim());
    final parsedHalf = double.tryParse(_halfPriceController.text.trim());
    if (parsedFull == null ||
        parsedHalf == null ||
        parsedFull < 0 ||
        parsedHalf < 0) {
      AppLogger.error(
        'SettingsTab',
        'Invalid INR price input during _saveSpaceSettings (full="${_fullPriceController.text}", half="${_halfPriceController.text}")',
      );
      _showSnack('Enter valid non-negative INR prices.', isError: true);
      return;
    }

    AppLogger.nav(
      'Opened Update Space Prices confirmation dialog',
      scope: 'SettingsTab',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update Space Prices?'),
        content: const Text(
          'New prices apply to future logs only. Past tiffin logs retain their original snapshotted cost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      AppLogger.nav(
        'Cancelled Update Space Prices dialog',
        scope: 'SettingsTab',
      );
      return;
    }

    setState(() => _isBusy = true);
    try {
      await AppLogger.traceAsync(
        'SettingsTab',
        'Save space settings (full=$parsedFull, half=$parsedHalf, cutoff=$_cutoffHour:${_cutoffMinute.toString().padLeft(2, '0')})',
        () => widget.onUpdateSpaceSettings(
          priceFull: parsedFull,
          priceHalf: parsedHalf,
          cutoffHour: _cutoffHour,
          cutoffMinute: _cutoffMinute,
        ),
      );
      _showSnack('Space prices and cut-off updated.');
    } catch (e, st) {
      AppLogger.error(
        'SettingsTab',
        'Failed to save space settings',
        error: e,
        stackTrace: st,
      );
      _showSnack(e is AppFailure ? e.message : e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _showTransferLeadershipDialog() async {
    final candidates = widget.members
        .where((m) => m.userId != widget.profile.id)
        .toList();
    if (candidates.isEmpty) {
      AppLogger.warn(
        'SettingsTab',
        'Transfer leadership blocked: no other members in Space',
      );
      _showSnack('Invite another colleague before transferring leadership.');
      return;
    }

    AppLogger.nav(
      'Opened Transfer Leadership dialog (candidates=${candidates.length})',
      scope: 'SettingsTab',
    );
    String selectedId = candidates.first.userId;
    final confirmedId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Transfer Leadership'),
            content: DropdownButtonFormField<String>(
              initialValue: selectedId,
              decoration: const InputDecoration(labelText: 'New Space Leader'),
              items: candidates
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.userId,
                      child: Text(c.user.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setDialogState(() => selectedId = value);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(selectedId),
                child: const Text('Transfer'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmedId == null) {
      AppLogger.nav(
        'Cancelled Transfer Leadership dialog',
        scope: 'SettingsTab',
      );
      return;
    }

    setState(() => _isBusy = true);
    try {
      await AppLogger.traceAsync(
        'SettingsTab',
        'Transfer leadership (newLeaderId=$confirmedId)',
        () => widget.onTransferLeadership(confirmedId),
      );
      _showSnack('Leadership transferred.');
    } catch (e, st) {
      AppLogger.error(
        'SettingsTab',
        'Failed to transfer leadership',
        error: e,
        stackTrace: st,
      );
      _showSnack(e is AppFailure ? e.message : e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _confirmLeaveSpace() async {
    if (widget.isLeader && widget.members.length > 1) {
      AppLogger.warn(
        'SettingsTab',
        'Leave space blocked: leader must transfer leadership first',
      );
      _showSnack(
        'Transfer leadership to another colleague before leaving this space.',
        isError: true,
      );
      return;
    }

    AppLogger.nav(
      'Opened Leave Space confirmation dialog',
      scope: 'SettingsTab',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave Space?'),
        content: Text(
          widget.isLeader && widget.members.length == 1
              ? 'You are the only member. Leaving will delete this Space and start a 2-day (48-hour) cooling period before joining another Space.'
              : 'Leaving "${widget.space.name}" starts a 2-day (48-hour) cooling period before you can join another Space.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave Space'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      AppLogger.nav('Cancelled Leave Space dialog', scope: 'SettingsTab');
      return;
    }

    setState(() => _isBusy = true);
    try {
      await AppLogger.traceAsync(
        'SettingsTab',
        'Leave space (spaceId=${widget.space.id})',
        widget.onLeaveSpace,
      );
    } catch (e, st) {
      AppLogger.error(
        'SettingsTab',
        'Failed to leave space',
        error: e,
        stackTrace: st,
      );
      _showSnack(e is AppFailure ? e.message : e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Settings',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.primarySoft,
                  child: Text(
                    widget.profile.initials,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.profile.displayName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                      if (widget.email != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.email!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.mutedInk,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isLeader
                              ? AppTheme.primarySoft
                              : AppTheme.skipSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.isLeader ? 'Space Leader' : 'Member',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: widget.isLeader
                                ? AppTheme.primary
                                : AppTheme.skipColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _isBusy ? null : _editNameDialog,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit name',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Space Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 10),
                _InfoRow(label: 'Space Name', value: widget.space.name),
                _InfoRow(
                  label: 'Members',
                  value: '${widget.members.length}',
                ),
                _InfoRow(
                  label: 'Daily Cut-off',
                  value: widget.space.cutoffDisplay,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '6-Digit Invite Code',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.mutedInk,
                            ),
                          ),
                          Text(
                            widget.space.inviteCode,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await Clipboard.setData(
                            ClipboardData(text: widget.space.inviteCode),
                          );
                          AppLogger.info(
                            'SettingsTab',
                            'Copied space invite code to clipboard (spaceId=${widget.space.id})',
                          );
                          _showSnack('Invite code copied!');
                        } catch (e, st) {
                          AppLogger.error(
                            'SettingsTab',
                            'Failed to copy invite code to clipboard',
                            error: e,
                            stackTrace: st,
                          );
                          _showSnack('Failed to copy invite code.');
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 17),
                      label: const Text('Copy'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (widget.isLeader) ...[
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _priceFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Leader Admin Panel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Price updates only apply to future logs; past snapshotted logs remain untouched.',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.mutedInk),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _fullPriceController,
                            enabled: !_isBusy,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Full Price (₹)',
                              prefixText: '₹ ',
                            ),
                            validator: _validateAmount,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _halfPriceController,
                            enabled: !_isBusy,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Half Price (₹)',
                              prefixText: '₹ ',
                            ),
                            validator: _validateAmount,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _isBusy ? null : _pickCutoffTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Daily Order Cut-off',
                          prefixIcon: Icon(Icons.schedule_rounded),
                        ),
                        child: Text(
                          AppConfig.formatCutoffDisplay(
                            _cutoffHour,
                            _cutoffMinute,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _isBusy ? null : _saveSpaceSettings,
                      child: const Text('Save Space Settings'),
                    ),
                    if (widget.members.length > 1) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _isBusy ? null : _showTransferLeadershipDialog,
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: const Text('Transfer Leadership'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _confirmLeaveSpace,
                  icon: const Icon(
                    Icons.exit_to_app_rounded,
                    color: Color(0xFFB91C1C),
                  ),
                  label: const Text(
                    'Leave Space (2-Day Cooldown)',
                    style: TextStyle(color: Color(0xFFB91C1C)),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _isBusy
                      ? null
                      : () async {
                          AppLogger.nav(
                            'Sign out tapped',
                            scope: 'SettingsTab',
                          );
                          setState(() => _isBusy = true);
                          try {
                            await AppLogger.traceAsync(
                              'SettingsTab',
                              'Sign out',
                              widget.onSignOut,
                            );
                          } catch (e, st) {
                            AppLogger.error(
                              'SettingsTab',
                              'Sign out failed',
                              error: e,
                              stackTrace: st,
                            );
                            _showSnack(
                              e is AppFailure ? e.message : e.toString(),
                              isError: true,
                            );
                          } finally {
                            if (mounted) setState(() => _isBusy = false);
                          }
                        },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String? _validateAmount(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 0) return 'Invalid price';
    return null;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.mutedInk, fontSize: 13.5),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.ink,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

