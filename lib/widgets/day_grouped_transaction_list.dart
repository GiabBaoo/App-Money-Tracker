import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/wallet_model.dart';
import '../services/language_service.dart';
import '../utils/currency_format_utils.dart';
import '../utils/time_utils.dart';
import 'staggered_list_item.dart';
import 'transaction_item.dart';

/// Nút chuyển chế độ hiển thị lịch sử giao dịch: "Gần đây" <-> "Theo ngày"
class TransactionViewModeToggle extends StatelessWidget {
  final bool groupByDay;
  final ValueChanged<bool> onChanged;

  const TransactionViewModeToggle({
    super.key,
    required this.groupByDay,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVi = LanguageScope.of(context).isVietnamese;

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFEEF3F2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegment(
            label: isVi ? 'Gần đây' : 'Recent',
            selected: !groupByDay,
            isDark: isDark,
            onTap: () {
              if (groupByDay) {
                HapticFeedback.selectionClick();
                onChanged(false);
              }
            },
          ),
          _buildSegment(
            label: isVi ? 'Theo ngày' : 'By day',
            selected: groupByDay,
            isDark: isDark,
            onTap: () {
              if (!groupByDay) {
                HapticFeedback.selectionClick();
                onChanged(true);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSegment({
    required String label,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? (isDark ? const Color(0xFF0A1614) : Colors.white)
                : (isDark ? Colors.white60 : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }
}

/// Hiển thị danh sách giao dịch được nhóm theo từng ngày kèm header tổng thu / chi.
class DayGroupedTransactionList extends StatelessWidget {
  final List<TransactionDayGroup> groups;
  final Map<String, double> reverseBalances;
  final Map<String, WalletModel> walletMap;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final Key? listKey;
  final bool animateItems;

  const DayGroupedTransactionList({
    super.key,
    required this.groups,
    required this.reverseBalances,
    required this.walletMap,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.listKey,
    this.animateItems = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVi = LanguageScope.of(context).isVietnamese;

    if (shrinkWrap) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < groups.length; i++)
            _buildDaySection(groups[i], isDark, isVi, sectionIndex: i),
        ],
      );
    }

    return ListView.builder(
      key: listKey,
      physics: physics ?? const BouncingScrollPhysics(),
      cacheExtent: 400,
      padding: padding ?? const EdgeInsets.fromLTRB(24, 4, 24, 100),
      itemCount: groups.length,
      itemBuilder: (context, index) =>
          _buildDaySection(groups[index], isDark, isVi, sectionIndex: index),
    );
  }

  Widget _buildDaySection(
    TransactionDayGroup group,
    bool isDark,
    bool isVi, {
    required int sectionIndex,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: sectionIndex == 0 ? 4 : 12, bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  TimeUtils.formatFriendlyDate(group.date, isVi: isVi),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (group.totalIncome > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    '+${CurrencyUtils.formatCurrency(group.totalIncome)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              if (group.totalExpense > 0)
                Text(
                  '-${CurrencyUtils.formatCurrency(group.totalExpense)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEF4444),
                  ),
                ),
            ],
          ),
        ),
        for (int i = 0; i < group.transactions.length; i++)
          _buildTxItem(group.transactions[i], sectionIndex * 10 + i),
      ],
    );
  }

  Widget _buildTxItem(dynamic tx, int index) {
    final item = TransactionItem(
      transaction: tx,
      showDate: false,
      runningTotal: reverseBalances[tx.id],
      wallet: walletMap[tx.walletId],
    );
    if (!animateItems) return item;
    return StaggeredListItem(index: index, child: item);
  }
}
