import '../../../../core/theme/app_theme.dart';
import '../../../../services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../widgets/animated_scale_button.dart';
import '../../../../widgets/mono_dialog.dart';
import '../../../../widgets/mono_toast.dart';
import '../providers/group_expense_providers.dart';
import '../../data/models/fund_transaction_model.dart';
import 'invite_member_screen.dart';
import 'group_members_screen.dart';
import 'group_all_transactions_screen.dart';
import 'group_expense_statistics_screen.dart';
import '../../../../modules/transaction/add_transaction_screen.dart';
import '../../../../utils/page_transitions.dart';

// Helper function để format tiền theo kiểu Việt (200000 -> 200.000)
String _formatMoney(double amount) {
  return amount.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => '.',
  );
}

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupStreamProvider(groupId));
    final expensesAsync = ref.watch(groupExpensesStreamProvider(groupId));
    final debtsAsync = ref.watch(groupDebtsProvider(groupId));
    final fundTransactionsAsync = ref.watch(groupFundTransactionsProvider(groupId));

    final isDark = context.isDarkMode;
    final primaryColor = context.colors.primary;

    // Design Tokens
    final bgColor = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBgColor = context.cardBg;
    final textPrimary = context.colors.onSurface;
    final textSecondary = context.colors.onSurfaceVariant;
    final borderColor = context.borderColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: groupAsync.when(
        data: (group) {
          if (group == null) {
            return SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.group_off_rounded,
                        size: 56,
                        color: textSecondary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isVi
                            ? 'Bạn đã rời khỏi nhóm hoặc không có quyền truy cập'
                            : 'You have left the group or have no access',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: textPrimary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text(isVi ? 'Quay lại' : 'Go back'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final currentUserId = ref.watch(currentUserIdProvider);
          final isAdmin = currentUserId == group.adminId;

          return Column(
            children: [
              // ─── ERGONOMIC TOP APP BAR ───
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      AnimatedScaleButton(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cardBgColor,
                            border: Border.all(color: borderColor, width: 1),
                            boxShadow: [
                              if (!isDark)
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: textPrimary,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              style: context.textTheme.titleLarge?.copyWith(
                                color: textPrimary,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageTransitions.slideRight(
                                    GroupMembersScreen(
                                      groupId: group.id,
                                      groupName: group.name,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                group.groupType == 'personal'
                                    ? (isVi ? 'Quỹ cá nhân' : 'Personal fund')
                                    : (isVi ? '${group.memberIds.length} thành viên • Chi tiết >' : '${group.memberIds.length} members • Details >'),
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Stats button
                      AnimatedScaleButton(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            PageTransitions.slideRight(
                              GroupExpenseStatisticsScreen(
                                groupId: group.id,
                                groupName: group.name,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cardBgColor,
                            border: Border.all(color: borderColor, width: 1),
                          ),
                          child: Icon(
                            Icons.bar_chart_rounded,
                            color: textPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── SCROLLABLE CONTENT (SUMMARY CARD + DEBTS + ACTIVITIES) ───
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Air & Spacious Summary Card
                      expensesAsync.when(
                        data: (expenses) => fundTransactionsAsync.when(
                          data: (transactions) {
                            double income = 0;
                            double expense = 0;
                            for (var tx in transactions) {
                              if (tx.type == TransactionType.contribute) {
                                income += tx.amount;
                              } else {
                                expense += tx.amount;
                              }
                            }
                            for (var e in expenses) {
                              expense += e.amount;
                            }
                            return _buildSummaryCard(
                              context,
                              group,
                              income,
                              expense,
                              isDark,
                              primaryColor,
                              transactions.length,
                            );
                          },
                          loading: () => _buildSummaryLoading(isDark, cardBgColor, borderColor),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                        loading: () => _buildSummaryLoading(isDark, cardBgColor, borderColor),
                        error: (_, _) => const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 24),

                      // 2. Debts Section
                      debtsAsync.when(
                        data: (debts) {
                          if (debts.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle(
                                title: isVi ? 'Công nợ nhóm' : 'Group Debts',
                                icon: Icons.compare_arrows_rounded,
                                iconColor: Colors.orange,
                                textPrimary: textPrimary,
                              ),
                              const SizedBox(height: 12),
                              ...debts.take(4).map((debt) => _buildDebtItem(
                                    debt,
                                    isDark,
                                    cardBgColor,
                                    textPrimary,
                                    textSecondary,
                                    borderColor,
                                  )),
                              const SizedBox(height: 24),
                            ],
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),

                      // 3. Recent Activity Section
                      fundTransactionsAsync.when(
                        data: (transactions) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSectionTitle(
                                    title: isVi ? 'Hoạt động gần đây' : 'Recent Activities',
                                    icon: Icons.history_rounded,
                                    iconColor: primaryColor,
                                    textPrimary: textPrimary,
                                  ),
                                  if (transactions.length > 5)
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          PageTransitions.slideRight(
                                            GroupAllTransactionsScreen(
                                              groupId: groupId,
                                              groupName: group.name,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        isVi ? 'Tất cả >' : 'See all >',
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (transactions.isEmpty)
                                _buildEmptyActivity(isDark, cardBgColor, textSecondary, borderColor)
                              else
                                ...transactions.take(8).map((tx) => _buildTransactionItem(
                                      context,
                                      ref,
                                      tx,
                                      isDark,
                                      cardBgColor,
                                      textPrimary,
                                      textSecondary,
                                      borderColor,
                                    )),
                            ],
                          );
                        },
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ),
                        error: (e, _) => Center(
                          child: Text(
                            '${isVi ? 'Lỗi' : 'Error'}: $e',
                            style: TextStyle(color: textSecondary),
                          ),
                        ),
                      ),

                      const SizedBox(height: 80), // extra padding for bottom bar
                    ],
                  ),
                ),
              ),

              // ─── ERGONOMIC THUMB-FRIENDLY BOTTOM ACTION BAR ───
              _buildBottomActionBar(
                context,
                group,
                isAdmin,
                isDark,
                primaryColor,
                cardBgColor,
                borderColor,
                textPrimary,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('${isVi ? 'Lỗi' : 'Error'}: $error'),
        ),
      ),
    );
  }

  // ─── 1. TOP SUMMARY CARD ───
  Widget _buildSummaryCard(
    BuildContext context,
    dynamic group,
    double income,
    double expense,
    bool isDark,
    Color primaryColor,
    int transactionCount,
  ) {
    final balance = income - expense;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.surfaceElevatedDark,
                  AppColors.surfaceDark,
                ]
              : [
                  primaryColor,
                  Color.lerp(primaryColor, Colors.black, 0.12) ?? primaryColor,
                ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : primaryColor).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isVi ? 'SỐ DƯ QUỸ HIỆN TẠI' : 'CURRENT FUND BALANCE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_outlined, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '$transactionCount ${isVi ? 'giao dịch' : 'txns'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Big bold balance text
          Text(
            '${_formatMoney(balance)}đ',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.8,
            ),
          ),

          const SizedBox(height: 20),

          // Inflow & Outflow Metrics row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                // Inflow
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: context.income.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_downward_rounded,
                          color: context.income,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isVi ? 'Tổng góp' : 'Total In',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '+${_formatMoney(income)}đ',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  height: 28,
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                const SizedBox(width: 12),

                // Outflow
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: context.expense.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          color: context.expense,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isVi ? 'Tổng chi/rút' : 'Total Out',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '-${_formatMoney(expense)}đ',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLoading(bool isDark, Color cardBgColor, Color borderColor) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  // ─── 2. SECTION TITLE ───
  Widget _buildSectionTitle({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color textPrimary,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  // ─── 3. DEBT ITEM ───
  Widget _buildDebtItem(
    dynamic debt,
    bool isDark,
    Color cardBgColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final isOwed = debt.amount > 0;
    final color = isOwed ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF34D399) : const Color(0xFF10B981));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: AppShadows.card(isDark),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOwed ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOwed
                      ? (isVi ? 'Bạn cần thanh toán' : 'You need to pay')
                      : (isVi ? 'Bạn sẽ được nhận lại' : 'You will receive'),
                  style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatMoney(debt.amount.abs())}đ',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 4. RECENT ACTIVITY ITEM ───
  Widget _buildTransactionItem(
    BuildContext context,
    WidgetRef ref,
    FundTransactionModel tx,
    bool isDark,
    Color cardBgColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final isContribute = tx.type == TransactionType.contribute;
    final color = isContribute
        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF10B981))
        : (isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: AppShadows.card(isDark),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _detailRefactorTransactionDetail(context, ref, tx, isDark),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isContribute ? Icons.add_rounded : Icons.arrow_outward_rounded,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isContribute ? (isVi ? 'Góp quỹ' : 'Contribute') : (isVi ? 'Rút quỹ' : 'Withdraw'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tx.userName,
                        style: TextStyle(fontSize: 12, color: textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isContribute ? '+' : '-'}${_formatMoney(tx.amount)}đ',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tx.createdAt.day}/${tx.createdAt.month} • ${tx.createdAt.hour.toString().padLeft(2, '0')}:${tx.createdAt.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyActivity(
    bool isDark,
    Color cardBgColor,
    Color textSecondary,
    Color borderColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 44,
            color: textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            isVi ? 'Chưa có hoạt động thu chi nào' : 'No activities yet',
            style: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ─── 5. ERGONOMIC THUMB-FRIENDLY BOTTOM ACTION BAR ───
  Widget _buildBottomActionBar(
    BuildContext context,
    dynamic group,
    bool isAdmin,
    bool isDark,
    Color primaryColor,
    Color cardBgColor,
    Color borderColor,
    Color textPrimary,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: cardBgColor,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Invite Member Button (Thumb reachable)
            if (group.groupType != 'personal') ...[
              AnimatedScaleButton(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    PageTransitions.slideRight(
                      InviteMemberScreen(
                        groupId: group.id,
                        groupName: group.name,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Icon(
                    Icons.person_add_outlined,
                    color: textPrimary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],

            // Withdraw Button (For Admin)
            if (isAdmin) ...[
              Expanded(
                child: AnimatedScaleButton(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      PageTransitions.slideUp(
                        AddTransactionScreen(
                          initialData: {
                            'isFundAction': true,
                            'groupId': groupId,
                            'fundActionType': 'withdraw',
                            'isPersonalGroup': group.groupType == 'personal',
                            'type': 'expense',
                            'description': 'Rút từ quỹ ${group.name}',
                          },
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_outward_rounded,
                          color: textPrimary,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isVi ? 'Rút quỹ' : 'Withdraw',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],

            // Primary Contribute Button (Big, Prominent)
            Expanded(
              flex: isAdmin ? 1 : 2,
              child: AnimatedScaleButton(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    PageTransitions.slideUp(
                      AddTransactionScreen(
                        initialData: {
                          'isFundAction': true,
                          'groupId': groupId,
                          'fundActionType': 'contribute',
                          'isPersonalGroup': group.groupType == 'personal',
                          'type': 'expense',
                          'description': 'Góp quỹ ${group.name}',
                        },
                      ),
                    ),
                  );
                },
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor,
                        primaryColor.withValues(alpha: 0.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isVi ? 'Góp quỹ' : 'Contribute',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 6. DETAIL BOTTOM SHEET ───
  void _detailRefactorTransactionDetail(
    BuildContext context,
    WidgetRef ref,
    FundTransactionModel transaction,
    bool isDark,
  ) {
    final sheetBg = context.cardBg;
    final textP = context.colors.onSurface;
    final textS = context.colors.onSurfaceVariant;
    final isContribute = transaction.type == TransactionType.contribute;
    final color = isContribute ? context.income : context.expense;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: context.borderColor,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textS.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isContribute ? Icons.add_rounded : Icons.arrow_outward_rounded,
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isContribute ? (isVi ? 'Góp quỹ' : 'Contribution') : (isVi ? 'Rút quỹ' : 'Withdrawal'),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textP),
                      ),
                      Text(transaction.userName, style: TextStyle(color: textS, fontSize: 13)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                isVi ? 'SỐ TIỀN' : 'AMOUNT',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textS, letterSpacing: 0.8),
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatMoney(transaction.amount)}đ',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5),
              ),
              const SizedBox(height: 18),
              Text(
                isVi ? 'THỜI GIAN' : 'TIME',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textS, letterSpacing: 0.8),
              ),
              const SizedBox(height: 4),
              Text(
                '${transaction.createdAt.day}/${transaction.createdAt.month}/${transaction.createdAt.year} • ${transaction.createdAt.hour.toString().padLeft(2, '0')}:${transaction.createdAt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textP),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final confirmed = await MonoDialog.confirm(
                          context,
                          title: isVi ? 'Xác nhận xóa' : 'Confirm Delete',
                          message: isVi
                              ? 'Bạn có chắc chắn muốn xóa giao dịch này không? Hành động này sẽ cập nhật lại số dư quỹ và ví cá nhân.'
                              : 'Are you sure you want to delete this transaction? This will update group and personal balances.',
                          confirmText: isVi ? 'Xóa' : 'Delete',
                          cancelText: isVi ? 'Hủy' : 'Cancel',
                          isDestructive: true,
                          icon: Icons.delete_outline_rounded,
                        );

                        if (confirmed == true) {
                          try {
                            await ref.read(fundTransactionRepositoryProvider).delete(transaction);
                            if (context.mounted) {
                              Navigator.pop(context); // Close bottom sheet
                              MonoToast.success(
                                context,
                                isVi ? 'Đã xóa giao dịch thành công' : 'Transaction deleted successfully',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              MonoToast.error(
                                context,
                                isVi ? 'Lỗi khi xóa: $e' : 'Delete error: $e',
                              );
                            }
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.colors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: Text(
                        isVi ? 'Xóa' : 'Delete',
                        style: TextStyle(color: context.colors.error, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.inputBgColor,
                        foregroundColor: textP,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: Text(isVi ? 'Đóng' : 'Close', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
