import '../models/money_summary.dart';
import '../models/space.dart';
import '../models/space_member.dart';
import '../models/tiffin_log.dart';
import '../utils/app_logger.dart';

/// Pure calculation helpers for monthly INR totals, week-wise budgets, and
/// Leader per-member vendor billing breakdowns.
class TiffinCalculator {
  const TiffinCalculator._();

  static bool isWeekday(DateTime date) =>
      date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;

  /// Builds the full [MonthlyBudgetSummary] for [month].
  static MonthlyBudgetSummary buildMonthlySummary({
    required DateTime month,
    required DateTime now,
    required String currentUserId,
    required Space space,
    required List<SpaceMember> members,
    required List<TiffinLog> spaceMonthLogs,
  }) {
    final totalDaysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final userLogs = spaceMonthLogs
        .where((log) => log.userId == currentUserId)
        .toList();

    final userLogsByDay = <int, TiffinLog>{
      for (final log in userLogs) log.logDate.day: log,
    };

    var fullCount = 0;
    var halfCount = 0;
    var skipCount = 0;
    var customCount = 0;
    var actualSpend = 0.0;

    for (final log in userLogs) {
      actualSpend += log.cost;
      switch (log.type) {
        case TiffinType.full:
          fullCount++;
        case TiffinType.half:
          halfCount++;
        case TiffinType.skip:
          skipCount++;
        case TiffinType.custom:
          customCount++;
      }
    }

    if (space.priceFull < 0) {
      AppLogger.warn(
        'TiffinCalculator',
        'Space priceFull is negative (${space.priceFull})',
      );
    }

    // Use the user's average logged cost this month when they have at least one
    // paid meal; otherwise fall back to the Space's Full price.
    final estimatedDailyRate =
        userLogs.isNotEmpty && (fullCount + halfCount + customCount) > 0
        ? actualSpend / userLogs.length
        : space.priceFull;

    final isCurrentMonth = month.year == now.year && month.month == now.month;
    final isPastMonth =
        month.year < now.year ||
        (month.year == now.year && month.month < now.month);

    bool isRemainingWeekday(int day) {
      if (isPastMonth) return false;
      final candidate = DateTime(month.year, month.month, day);
      if (!isWeekday(candidate)) return false;
      if (!isCurrentMonth) return true;
      if (day > now.day) return true;
      if (day == now.day && !userLogsByDay.containsKey(day)) return true;
      return false;
    }

    final weeks = <WeekBudgetRow>[];
    var weekNumber = 1;
    for (var start = 1; start <= totalDaysInMonth; start += 7) {
      final end = (start + 6).clamp(1, totalDaysInMonth);
      var weekFull = 0;
      var weekHalf = 0;
      var weekSkip = 0;
      var weekCustom = 0;
      var weekActual = 0.0;
      var weekRemainingWeekdays = 0;

      for (var day = start; day <= end; day++) {
        final log = userLogsByDay[day];
        if (log != null) {
          weekActual += log.cost;
          switch (log.type) {
            case TiffinType.full:
              weekFull++;
            case TiffinType.half:
              weekHalf++;
            case TiffinType.skip:
              weekSkip++;
            case TiffinType.custom:
              weekCustom++;
          }
        }
        if (isRemainingWeekday(day)) {
          weekRemainingWeekdays++;
        }
      }

      weeks.add(
        WeekBudgetRow(
          weekNumber: weekNumber,
          startDay: start,
          endDay: end,
          fullCount: weekFull,
          halfCount: weekHalf,
          skipCount: weekSkip,
          customCount: weekCustom,
          actualSpend: weekActual,
          remainingWeekdays: weekRemainingWeekdays,
          projectedAdditionalSpend: weekRemainingWeekdays * estimatedDailyRate,
        ),
      );
      weekNumber++;
    }

    final remainingWeekdays = weeks.fold<int>(
      0,
      (sum, row) => sum + row.remainingWeekdays,
    );
    final projectedTotal =
        actualSpend + (remainingWeekdays * estimatedDailyRate);

    final memberBreakdown = buildMemberBreakdown(
      members: members,
      spaceMonthLogs: spaceMonthLogs,
    );

    return MonthlyBudgetSummary(
      month: DateTime(month.year, month.month),
      actualSpend: actualSpend,
      projectedTotal: projectedTotal,
      remainingWeekdays: remainingWeekdays,
      estimatedDailyRate: estimatedDailyRate,
      fullCount: fullCount,
      halfCount: halfCount,
      skipCount: skipCount,
      customCount: customCount,
      weeks: weeks,
      memberBreakdown: memberBreakdown,
    );
  }

  /// Aggregates monthly counts and snapshotted INR totals for each member.
  static List<MemberMonthlyTotal> buildMemberBreakdown({
    required List<SpaceMember> members,
    required List<TiffinLog> spaceMonthLogs,
  }) {
    final memberIds = {for (final member in members) member.userId};
    final logsByUser = <String, List<TiffinLog>>{};
    for (final log in spaceMonthLogs) {
      if (log.cost < 0) {
        AppLogger.warn(
          'TiffinCalculator',
          'Negative tiffin log cost encountered (userId=${log.userId}, day=${log.logDate.day}, cost=${log.cost})',
        );
      }
      if (!memberIds.contains(log.userId)) {
        AppLogger.warn(
          'TiffinCalculator',
          'Log references userId missing from Space members (userId=${log.userId}, day=${log.logDate.day})',
        );
      }
      logsByUser.putIfAbsent(log.userId, () => []).add(log);
    }

    final rows = members.map((member) {
      final logs = logsByUser[member.userId] ?? const <TiffinLog>[];
      var full = 0;
      var half = 0;
      var skip = 0;
      var custom = 0;
      var total = 0.0;
      for (final log in logs) {
        total += log.cost;
        switch (log.type) {
          case TiffinType.full:
            full++;
          case TiffinType.half:
            half++;
          case TiffinType.skip:
            skip++;
          case TiffinType.custom:
            custom++;
        }
      }
      return MemberMonthlyTotal(
        member: member,
        fullCount: full,
        halfCount: half,
        skipCount: skip,
        customCount: custom,
        totalSpend: total,
      );
    }).toList();

    rows.sort((a, b) {
      final spendCmp = b.totalSpend.compareTo(a.totalSpend);
      if (spendCmp != 0) return spendCmp;
      return a.member.user.displayName.toLowerCase().compareTo(
        b.member.user.displayName.toLowerCase(),
      );
    });

    return rows;
  }
}

