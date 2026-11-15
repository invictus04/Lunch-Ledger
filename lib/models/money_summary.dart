import 'space_member.dart';

/// Weekly spend and remaining weekday projection inside a calendar month.
class WeekBudgetRow {
  const WeekBudgetRow({
    required this.weekNumber,
    required this.startDay,
    required this.endDay,
    required this.fullCount,
    required this.halfCount,
    required this.skipCount,
    required this.actualSpend,
    required this.remainingWeekdays,
    required this.projectedAdditionalSpend,
  });

  final int weekNumber;
  final int startDay;
  final int endDay;
  final int fullCount;
  final int halfCount;
  final int skipCount;
  final double actualSpend;
  final int remainingWeekdays;
  final double projectedAdditionalSpend;

  double get totalProjectedWeekSpend => actualSpend + projectedAdditionalSpend;
}

/// Monthly per-member spend breakdown shown to the Space Leader.
class MemberMonthlyTotal {
  const MemberMonthlyTotal({
    required this.member,
    required this.fullCount,
    required this.halfCount,
    required this.skipCount,
    required this.totalSpend,
  });

  final SpaceMember member;
  final int fullCount;
  final int halfCount;
  final int skipCount;
  final double totalSpend;

  int get totalMeals => fullCount + halfCount;
}

/// Complete monthly money summary for the Money tab.
class MonthlyBudgetSummary {
  const MonthlyBudgetSummary({
    required this.month,
    required this.actualSpend,
    required this.projectedTotal,
    required this.remainingWeekdays,
    required this.estimatedDailyRate,
    required this.fullCount,
    required this.halfCount,
    required this.skipCount,
    required this.weeks,
    required this.memberBreakdown,
  });

  final DateTime month;
  final double actualSpend;
  final double projectedTotal;
  final int remainingWeekdays;
  final double estimatedDailyRate;
  final int fullCount;
  final int halfCount;
  final int skipCount;
  final List<WeekBudgetRow> weeks;
  final List<MemberMonthlyTotal> memberBreakdown;

  double get squadGrandTotal =>
      memberBreakdown.fold(0, (sum, row) => sum + row.totalSpend);
}

