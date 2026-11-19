import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/space.dart';
import '../models/space_menu_item.dart';
import '../models/tiffin_log.dart';
import '../theme/app_theme.dart';
import 'tiffin_style_helper.dart';

/// Hero card on Home allowing the user to log or update today's meal choice.
/// Supports dynamic menu items, confirmation dialogs, and strict cut-off locking.
class TiffinChoiceCard extends StatelessWidget {
  const TiffinChoiceCard({
    super.key,
    required this.space,
    this.menuItems = const [],
    required this.todayLog,
    required this.isSaving,
    this.isLocked = false,
    this.isLeaderOverride = false,
    required this.onSelect,
  });

  final Space space;
  final List<SpaceMenuItem> menuItems;
  final TiffinLog? todayLog;
  final bool isSaving;
  final bool isLocked;
  final bool isLeaderOverride;
  final void Function({
    required TiffinType type,
    String? menuItemId,
    String? itemName,
  }) onSelect;

  Future<void> _handleOptionTap(
    BuildContext context, {
    required TiffinType type,
    String? menuItemId,
    required String itemName,
    required double price,
  }) async {
    if (isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Today's cut-off (${space.cutoffDisplay}) has passed. Contact Space Leader to make changes.",
          ),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
      return;
    }

    if (isSaving) return;

    final isSwitch = todayLog != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              type == TiffinType.skip
                  ? Icons.do_not_disturb_on_outlined
                  : Icons.restaurant_rounded,
              color: AppTheme.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(isSwitch ? 'Update Today’s Meal?' : 'Confirm Today’s Meal'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSwitch
                  ? 'Change your lunch entry to:'
                  : 'Are you sure you want to log:',
              style: const TextStyle(fontSize: 13.5, color: AppTheme.mutedInk),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      itemName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                  Text(
                    price == 0 ? 'Free' : AppConfig.formatInr(price),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (isLeaderOverride)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.pendingSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: AppTheme.pendingColor,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Leader Override: Submitting past daily cut-off.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.warningFg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                'Entries lock at ${space.cutoffDisplay}. You can modify your choice anytime before cut-off.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.mutedInk,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(isSwitch ? 'Update Meal' : 'Confirm & Log'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onSelect(type: type, menuItemId: menuItemId, itemName: itemName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStyle = TiffinVisualStyle.of(
      todayLog?.type,
      customLabel: todayLog?.displayLabel,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Today's Tiffin",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: currentStyle.softBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        currentStyle.icon,
                        size: 15,
                        color: currentStyle.color,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        todayLog == null
                            ? 'Not logged yet'
                            : '${todayLog!.displayLabel} · ${AppConfig.formatInr(todayLog!.cost)}',
                        style: TextStyle(
                          color: currentStyle.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isLocked
                  ? 'Cut-off (${space.cutoffDisplay}) has passed. Contact your Space Leader to adjust today\'s meal.'
                  : todayLog == null
                      ? 'Tap an option below to log your lunch for today.'
                      : 'Need to switch? Tap a different option to update today’s entry.',
              style: TextStyle(
                color: isLocked ? const Color(0xFF991B1B) : AppTheme.mutedInk,
                fontSize: 13,
                fontWeight: isLocked ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 14),
            if (menuItems.isNotEmpty)
              _buildDynamicMenuChoices(context)
            else
              _buildLegacyChoices(context),
            if (isSaving) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (isLocked)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 18,
                      color: Color(0xFFB91C1C),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Orders locked after cut-off. Contact Space Leader to change.',
                        style: TextStyle(
                          color: Color(0xFF991B1B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (isLeaderOverride)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.pendingSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warningBorder),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: AppTheme.pendingColor,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Leader Override: You can record and adjust meals past cut-off.',
                        style: TextStyle(
                          color: AppTheme.warningFg,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicMenuChoices(BuildContext context) {
    final activeItems = menuItems.where((i) => i.isActive).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 340 ? 2 : 1;
        final totalCount = activeItems.length + 1; // +1 for Skip

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: crossAxisCount == 2 ? 2.2 : 4.0,
          ),
          itemBuilder: (context, index) {
            if (index < activeItems.length) {
              final item = activeItems[index];
              final isSelected = todayLog != null &&
                  todayLog!.type != TiffinType.skip &&
                  (todayLog!.menuItemId == item.id ||
                      (todayLog!.itemName != null &&
                          todayLog!.itemName!.toLowerCase() ==
                              item.name.toLowerCase()));
              final style = TiffinVisualStyle.of(
                TiffinType.custom,
                customLabel: item.name,
              );

              return _ChoiceTile(
                label: item.name,
                price: item.price,
                icon: item.name.toLowerCase().contains('half')
                    ? Icons.lunch_dining_rounded
                    : Icons.rice_bowl_rounded,
                style: style,
                selected: isSelected,
                disabled: isSaving || isLocked,
                onTap: () => _handleOptionTap(
                  context,
                  type: TiffinType.custom,
                  menuItemId: item.id,
                  itemName: item.name,
                  price: item.price,
                ),
              );
            } else {
              // Skip Lunch Tile
              final isSelected = todayLog?.type == TiffinType.skip;
              final style = TiffinVisualStyle.of(TiffinType.skip);

              return _ChoiceTile(
                label: 'Skip Lunch',
                price: 0,
                icon: Icons.do_not_disturb_on_outlined,
                style: style,
                selected: isSelected,
                disabled: isSaving || isLocked,
                onTap: () => _handleOptionTap(
                  context,
                  type: TiffinType.skip,
                  menuItemId: null,
                  itemName: 'Skip Lunch',
                  price: 0,
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildLegacyChoices(BuildContext context) {
    return Row(
      children: TiffinType.values
          .where((t) => t != TiffinType.custom)
          .map((type) {
        final selected = todayLog?.type == type;
        final style = TiffinVisualStyle.of(type);
        final price = space.priceForType(type);
        final label = type == TiffinType.skip ? 'Skip Lunch' : style.label;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: type == TiffinType.skip ? 0 : 8,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: (isSaving || isLocked)
                  ? null
                  : () => _handleOptionTap(
                        context,
                        type: type,
                        menuItemId: null,
                        itemName: label,
                        price: price,
                      ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: isLocked
                      ? AppTheme.surfaceBg
                      : selected
                          ? style.softBg
                          : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isLocked
                        ? AppTheme.cardBorder
                        : selected
                            ? style.color
                            : AppTheme.cardBorder,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      style.icon,
                      color: isLocked
                          ? AppTheme.mutedInk.withAlpha(120)
                          : selected
                              ? style.color
                              : AppTheme.mutedInk,
                      size: 24,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      style.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isLocked
                            ? AppTheme.mutedInk
                            : selected
                                ? style.color
                                : AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      price == 0 ? 'Free' : AppConfig.formatInr(price),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isLocked
                            ? AppTheme.mutedInk.withAlpha(140)
                            : selected
                                ? style.color
                                : AppTheme.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.price,
    required this.icon,
    required this.style,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final double price;
  final IconData icon;
  final TiffinVisualStyle style;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: disabled && !selected
              ? AppTheme.surfaceBg
              : selected
                  ? style.softBg
                  : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? style.color : AppTheme.cardBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withAlpha(200)
                    : AppTheme.surfaceBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: disabled
                    ? AppTheme.mutedInk.withAlpha(140)
                    : selected
                        ? style.color
                        : AppTheme.mutedInk,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: disabled
                          ? AppTheme.mutedInk
                          : selected
                              ? style.color
                              : AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    price == 0 ? 'Free' : AppConfig.formatInr(price),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: disabled
                          ? AppTheme.mutedInk.withAlpha(140)
                          : selected
                              ? style.color
                              : AppTheme.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: style.color,
              ),
          ],
        ),
      ),
    );
  }
}
