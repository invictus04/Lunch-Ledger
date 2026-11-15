import 'package:flutter/material.dart';

import '../models/space_member.dart';
import '../models/tiffin_log.dart';
import '../theme/app_theme.dart';
import 'tiffin_style_helper.dart';

/// Displays today's team headcounts and horizontal Squad View of colleague statuses.
class SquadStatusStrip extends StatelessWidget {
  const SquadStatusStrip({
    super.key,
    required this.members,
    required this.todayLogsByUser,
    required this.currentUserId,
  });

  final List<SpaceMember> members;
  final Map<String, TiffinLog> todayLogsByUser;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    var fullCount = 0;
    var halfCount = 0;
    var skipCount = 0;
    var pendingCount = 0;

    for (final member in members) {
      final log = todayLogsByUser[member.userId];
      switch (log?.type) {
        case TiffinType.full:
          fullCount++;
        case TiffinType.half:
          halfCount++;
        case TiffinType.skip:
          skipCount++;
        case null:
          pendingCount++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Squad View',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                ),
              ),
            ),
            Text(
              '${members.length} ${members.length == 1 ? 'member' : 'members'}',
              style: const TextStyle(
                color: AppTheme.mutedInk,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HeadcountChip(
              label: '$fullCount Full',
              style: TiffinVisualStyle.of(TiffinType.full),
            ),
            _HeadcountChip(
              label: '$halfCount Half',
              style: TiffinVisualStyle.of(TiffinType.half),
            ),
            _HeadcountChip(
              label: '$skipCount Skip',
              style: TiffinVisualStyle.of(TiffinType.skip),
            ),
            _HeadcountChip(
              label: '$pendingCount Pending',
              style: TiffinVisualStyle.of(null),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (members.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No colleagues in this Space yet.',
                style: TextStyle(color: AppTheme.mutedInk),
              ),
            ),
          )
        else
          SizedBox(
            height: 126,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: members.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final member = members[index];
                final log = todayLogsByUser[member.userId];
                final style = TiffinVisualStyle.of(log?.type);
                final isSelf = member.userId == currentUserId;

                return Container(
                  width: 112,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelf ? AppTheme.primary : AppTheme.cardBorder,
                      width: isSelf ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: style.softBg,
                        child: Text(
                          member.user.initials,
                          style: TextStyle(
                            color: style.color,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        isSelf ? 'You' : member.user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.ink,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: style.softBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          style.label,
                          style: TextStyle(
                            color: style.color,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _HeadcountChip extends StatelessWidget {
  const _HeadcountChip({
    required this.label,
    required this.style,
  });

  final String label;
  final TiffinVisualStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.softBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: style.color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

