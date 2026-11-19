import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_config.dart';
import '../../models/space.dart';
import '../../models/user_profile.dart';
import '../../services/supabase_error_mapper.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';

/// Gateway for users with no active Space: Join via 6-digit code (respecting
/// the 2-day cooling period after leaving) or Create a new Space as Leader.
class SpaceGatewayScreen extends StatefulWidget {
  const SpaceGatewayScreen({
    super.key,
    required this.profile,
    this.initialInviteCode,
    required this.onJoinSpace,
    required this.onCreateSpace,
    required this.onSpaceEntered,
    required this.onSignOut,
    this.nowOverride,
  });

  final UserProfile profile;
  final String? initialInviteCode;
  final Future<Space> Function(String inviteCode) onJoinSpace;
  final Future<Space> Function({
    required String name,
    required double priceFull,
    required double priceHalf,
    required int cutoffHour,
    required int cutoffMinute,
  }) onCreateSpace;
  final VoidCallback onSpaceEntered;
  final Future<void> Function() onSignOut;
  final DateTime? nowOverride;

  @override
  State<SpaceGatewayScreen> createState() => _SpaceGatewayScreenState();
}

class _SpaceGatewayScreenState extends State<SpaceGatewayScreen> {
  final _joinFormKey = GlobalKey<FormState>();
  final _createFormKey = GlobalKey<FormState>();

  final _inviteCodeController = TextEditingController();
  final _spaceNameController = TextEditingController();
  final _fullPriceController = TextEditingController(text: '120');
  final _halfPriceController = TextEditingController(text: '80');

  int _cutoffHour = AppConfig.defaultCutoffHour;
  int _cutoffMinute = AppConfig.defaultCutoffMinute;

  bool _showCreateTab = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  DateTime? _serverCooldownUnlockAt;
  Timer? _cooldownTimer;

  DateTime get _now => widget.nowOverride ?? DateTime.now();

  DateTime? get _effectiveCooldownEnd {
    final profileEnd = widget.profile.cooldownEndsAt;
    if (profileEnd == null) return _serverCooldownUnlockAt;
    if (_serverCooldownUnlockAt == null) return profileEnd;
    return profileEnd.isAfter(_serverCooldownUnlockAt!)
        ? profileEnd
        : _serverCooldownUnlockAt;
  }

  Duration get _cooldownRemaining {
    final end = _effectiveCooldownEnd;
    if (end == null) return Duration.zero;
    final diff = end.difference(_now);
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get _isCooldownActive => _cooldownRemaining > Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.initialInviteCode != null &&
        widget.initialInviteCode!.trim().isNotEmpty) {
      final extracted =
          AppConfig.extractInviteCode(widget.initialInviteCode!) ??
              widget.initialInviteCode!.trim();
      _inviteCodeController.text = extracted;
    }
    AppLogger.nav(
      'Entered SpaceGatewayScreen (cooldownActive=$_isCooldownActive)',
      scope: 'SpaceGatewayScreen',
    );
    _ensureTimerIfCoolingDown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _inviteCodeController.dispose();
    _spaceNameController.dispose();
    _fullPriceController.dispose();
    _halfPriceController.dispose();
    super.dispose();
  }

  void _ensureTimerIfCoolingDown() {
    if (widget.nowOverride != null || !_isCooldownActive) return;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {});
      if (!_isCooldownActive) {
        _cooldownTimer?.cancel();
      }
    });
  }

  Future<void> _pickCutoffTime() async {
    AppLogger.nav('Opening cutoff TimePicker', scope: 'SpaceGatewayScreen');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _cutoffHour, minute: _cutoffMinute),
    );
    if (picked != null && mounted) {
      AppLogger.info(
        'SpaceGatewayScreen',
        'Selected cutoff time ${picked.hour}:${picked.minute}',
      );
      setState(() {
        _cutoffHour = picked.hour;
        _cutoffMinute = picked.minute;
      });
    }
  }

  Future<void> _submitJoin() async {
    FocusScope.of(context).unfocus();
    if (_isCooldownActive) {
      AppLogger.warn('SpaceGatewayScreen', 'Join blocked by active cooldown.');
      return;
    }
    if (!_joinFormKey.currentState!.validate()) {
      AppLogger.warn('SpaceGatewayScreen', 'Join form validation failed.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await AppLogger.traceAsync(
        'SpaceGatewayScreen',
        'onJoinSpace',
        () => widget.onJoinSpace(_inviteCodeController.text.trim()),
        describeResult: (s) => 'spaceId=${s.id}',
      );
      if (mounted) {
        AppLogger.nav(
          'SpaceGatewayScreen -> entering Space via onSpaceEntered',
          scope: 'SpaceGatewayScreen',
        );
        widget.onSpaceEntered();
      }
    } catch (e, st) {
      AppLogger.error(
        'SpaceGatewayScreen',
        'Join space failed',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      if (e is AppFailure) {
        setState(() {
          _errorMessage = e.message;
          if (e.cooldownUnlockAt != null) {
            _serverCooldownUnlockAt = e.cooldownUnlockAt;
            _ensureTimerIfCoolingDown();
          }
        });
      } else {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _submitCreate() async {
    FocusScope.of(context).unfocus();
    if (!_createFormKey.currentState!.validate()) {
      AppLogger.warn('SpaceGatewayScreen', 'Create form validation failed.');
      return;
    }

    final priceFull = double.tryParse(_fullPriceController.text.trim());
    final priceHalf = double.tryParse(_halfPriceController.text.trim());
    if (priceFull == null || priceHalf == null) {
      AppLogger.error(
        'SpaceGatewayScreen',
        'Failed to parse prices: full="${_fullPriceController.text}", half="${_halfPriceController.text}"',
      );
      setState(() => _errorMessage = 'Please enter valid numeric prices.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final created = await AppLogger.traceAsync(
        'SpaceGatewayScreen',
        'onCreateSpace',
        () => widget.onCreateSpace(
          name: _spaceNameController.text.trim(),
          priceFull: priceFull,
          priceHalf: priceHalf,
          cutoffHour: _cutoffHour,
          cutoffMinute: _cutoffMinute,
        ),
        describeResult: (s) => 'spaceId=${s.id}, code=${s.inviteCode}',
      );
      if (!mounted) return;
      await _showInviteCodeDialog(created);
      if (mounted) {
        AppLogger.nav(
          'SpaceGatewayScreen -> entering created Space via onSpaceEntered',
          scope: 'SpaceGatewayScreen',
        );
        widget.onSpaceEntered();
      }
    } catch (e, st) {
      AppLogger.error(
        'SpaceGatewayScreen',
        'Create space failed',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        setState(() {
          _errorMessage = e is AppFailure ? e.message : e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showInviteCodeDialog(Space space) async {
    AppLogger.nav(
      'Opened invite code dialog (space="${space.name}")',
      scope: 'SpaceGatewayScreen',
    );
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Space Created!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Share this 6-digit invite code with your colleagues to join "${space.name}":',
                style: const TextStyle(color: AppTheme.mutedInk),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  space.inviteCode,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                try {
                  await Clipboard.setData(
                    ClipboardData(text: space.inviteCode),
                  );
                  AppLogger.info(
                    'SpaceGatewayScreen',
                    'Copied invite code to clipboard for "${space.name}"',
                  );
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Invite code copied!')),
                    );
                  }
                } catch (e, st) {
                  AppLogger.error(
                    'SpaceGatewayScreen',
                    'Failed to copy invite code to clipboard',
                    error: e,
                    stackTrace: st,
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy Code'),
            ),
            FilledButton(
              onPressed: () {
                AppLogger.nav(
                  'Closed invite code dialog (Continue tapped)',
                  scope: 'SpaceGatewayScreen',
                );
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cooldownLeft = _cooldownRemaining;
    final isCooling = _isCooldownActive;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join or Create Space'),
        actions: [
          TextButton.icon(
            onPressed: _isSubmitting
                ? null
                : () async {
                    AppLogger.info('SpaceGatewayScreen', 'Sign out tapped.');
                    try {
                      await AppLogger.traceAsync(
                        'SpaceGatewayScreen',
                        'onSignOut',
                        widget.onSignOut,
                      );
                    } catch (e, st) {
                      AppLogger.error(
                        'SpaceGatewayScreen',
                        'Sign out failed',
                        error: e,
                        stackTrace: st,
                      );
                    }
                  },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign Out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome, ${widget.profile.displayName}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Every colleague belongs to one active office Space. Join with a 6-digit code or start a new Space as Leader.',
                    style: TextStyle(color: AppTheme.mutedInk, fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.group_add_outlined),
                        label: Text('Join Space'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.add_business_outlined),
                        label: Text('Create Space'),
                      ),
                    ],
                    selected: {_showCreateTab},
                    onSelectionChanged: _isSubmitting
                        ? null
                        : (values) {
                            final nextCreate = values.first;
                            AppLogger.nav(
                              'SpaceGatewayScreen tab -> ${nextCreate ? 'Create Space' : 'Join Space'}',
                              scope: 'SpaceGatewayScreen',
                            );
                            setState(() {
                              _showCreateTab = nextCreate;
                              _errorMessage = null;
                            });
                          },
                  ),
                  const SizedBox(height: 18),
                  if (!_showCreateTab && isCooling) ...[
                    _CooldownBanner(remaining: cooldownLeft),
                    const SizedBox(height: 14),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: _showCreateTab
                          ? _buildCreateForm()
                          : _buildJoinForm(isCooling),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoinForm(bool isCooling) {
    return Form(
      key: _joinFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enter 6-Digit Invite Code',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ask your Space Leader for the office code.',
            style: TextStyle(fontSize: 13, color: AppTheme.mutedInk),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _inviteCodeController,
            enabled: !isCooling && !_isSubmitting,
            keyboardType: TextInputType.text,
            maxLength: 6,
            inputFormatters: [
              TextInputFormatter.withFunction((oldValue, newValue) {
                final extracted = AppConfig.extractInviteCode(newValue.text);
                if (extracted != null && newValue.text.length > 6) {
                  return TextEditingValue(
                    text: extracted,
                    selection:
                        TextSelection.collapsed(offset: extracted.length),
                  );
                }
                final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
                final truncated =
                    digits.length > 6 ? digits.substring(0, 6) : digits;
                return TextEditingValue(
                  text: truncated,
                  selection:
                      TextSelection.collapsed(offset: truncated.length),
                );
              }),
            ],
            decoration: InputDecoration(
              labelText: '6-Digit Code',
              hintText: '123456',
              counterText: '',
              prefixIcon: const Icon(Icons.key_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste_rounded, size: 20),
                tooltip: 'Paste invite code or link',
                onPressed: (!isCooling && !_isSubmitting)
                    ? () async {
                        try {
                          final data =
                              await Clipboard.getData(Clipboard.kTextPlain);
                          final text = data?.text;
                          if (text != null && text.trim().isNotEmpty) {
                            final code = AppConfig.extractInviteCode(text);
                            if (code != null) {
                              setState(() {
                                _inviteCodeController.text = code;
                                _errorMessage = null;
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Pasted invite code: $code'),
                                  ),
                                );
                              }
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'No 6-digit invite code found in clipboard.',
                                    ),
                                    backgroundColor: Color(0xFFB91C1C),
                                  ),
                                );
                              }
                            }
                          }
                        } catch (_) {}
                      }
                    : null,
              ),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (!RegExp(r'^\d{6}$').hasMatch(text)) {
                return 'Enter a valid 6-digit invite code';
              }
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: (isCooling || _isSubmitting) ? null : _submitJoin,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Join Space'),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    return Form(
      key: _createFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Create Office Space',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'You become the Leader and set fixed INR prices for your team.',
            style: TextStyle(fontSize: 13, color: AppTheme.mutedInk),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _spaceNameController,
            enabled: !_isSubmitting,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Space Name',
              hintText: 'e.g. Engineering Floor 4',
              prefixIcon: Icon(Icons.apartment_rounded),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter a name for your Space';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _fullPriceController,
                  enabled: !_isSubmitting,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Full Price (₹)',
                    prefixText: '₹ ',
                  ),
                  validator: _validatePositiveAmount,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _halfPriceController,
                  enabled: !_isSubmitting,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Half Price (₹)',
                    prefixText: '₹ ',
                  ),
                  validator: _validatePositiveAmount,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isSubmitting ? null : _pickCutoffTime,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Daily Order Cut-off Time',
                prefixIcon: Icon(Icons.schedule_rounded),
              ),
              child: Text(
                AppConfig.formatCutoffDisplay(_cutoffHour, _cutoffMinute),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink,
                ),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isSubmitting ? null : _submitCreate,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Create Space & Get Code'),
          ),
        ],
      ),
    );
  }

  String? _validatePositiveAmount(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 0) {
      return 'Invalid amount';
    }
    return null;
  }
}

class _CooldownBanner extends StatelessWidget {
  const _CooldownBanner({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warningBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            color: AppTheme.warningFg,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '2-Day Cooling Period Active',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.warningFg,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'You recently left a space. You can join another space in ${AppConfig.formatDurationCompact(remaining)}.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.warningFg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

