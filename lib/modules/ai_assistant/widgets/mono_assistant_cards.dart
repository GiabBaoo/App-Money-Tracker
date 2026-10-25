import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/language_service.dart';
import '../../../models/transaction_model.dart';
import '../../../models/wallet_model.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../../services/auth_service.dart';
import '../../../services/bank_sms_parser_service.dart';
import '../../../services/group_bill_split_service.dart';
import '../../../services/financial_advisor_service.dart';
import '../../../services/transaction_balance_service.dart';
import '../../../utils/currency_format_utils.dart';
import '../../../utils/category_utils.dart';
import '../../../core/theme/app_theme.dart';

/// Thẻ xác nhận giao dịch từ SMS / Biến động số dư ngân hàng
class BankSmsTransactionCard extends StatefulWidget {
  final BankSmsParseResult parseResult;
  final VoidCallback? onSaved;

  const BankSmsTransactionCard({
    super.key,
    required this.parseResult,
    this.onSaved,
  });

  @override
  State<BankSmsTransactionCard> createState() => _BankSmsTransactionCardState();
}

class _BankSmsTransactionCardState extends State<BankSmsTransactionCard> {
  bool _isSaving = false;
  bool _isSaved = false;

  Future<void> _saveTransaction() async {
    if (_isSaved || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      final res = widget.parseResult;
      final now = DateTime.now();
      final uid = AuthService().currentUid ?? '';

      // Tự động tìm ví ngân hàng tương ứng theo tên ngân hàng hoặc số tài khoản trong SMS
      final wallets = WalletRepository().latestWallets;
      WalletModel? targetWallet;

      if (res.bankName.isNotEmpty) {
        final bankLower = res.bankName.toLowerCase();
        try {
          targetWallet = wallets.firstWhere(
            (w) =>
                w.name.toLowerCase().contains(bankLower) ||
                w.bankName.toLowerCase().contains(bankLower) ||
                (w.accountNumber.isNotEmpty &&
                    res.rawMessage.contains(w.accountNumber)),
          );
        } catch (_) {}
      }

      if (targetWallet == null && wallets.isNotEmpty) {
        try {
          targetWallet = wallets.firstWhere((w) => w.isDefault);
        } catch (_) {
          targetWallet = wallets.first;
        }
      }

      final walletId = targetWallet?.id ?? '';

      final tx = TransactionModel(
        id: '',
        uid: uid,
        type: res.type,
        category: res.category,
        categoryIconCode: CategoryUtils.getCategoryIcon(res.category).codePoint,
        amount: res.amount,
        date: res.transactionDate ?? now,
        time:
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        description: res.description.isNotEmpty
            ? res.description
            : 'Giao dịch qua ${res.bankName}',
        walletId: walletId,
        source: 'bank_sms',
        syncStatus: 'pending',
      );

      // Lưu giao dịch nguyên tử & tự động cập nhật số dư ví
      await TransactionBalanceService().addTransactionAtomic(tx);

      setState(() {
        _isSaving = false;
        _isSaved = true;
      });

      if (mounted) {
        final walletNotice = targetWallet != null
            ? ' (Ví: ${targetWallet.name})'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Đã lưu ${res.type == 'income' ? 'khoản thu' : 'khoản chi'} ${CurrencyUtils.formatCurrency(res.amount)}$walletNotice vào sổ!',
            ),
            backgroundColor: context.colors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      widget.onSaved?.call();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu: $e'),
            backgroundColor: context.expense,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final res = widget.parseResult;
    final isIncome = res.type == 'income';
    final primaryColor = isIncome ? context.income : context.expense;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? context.colors.surface : context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: primaryColor.withValues(alpha: isDark ? 0.45 : 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Bank badge + Type
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(
                    alpha: isDark ? 0.22 : 0.1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_rounded,
                      size: 14,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      res.bankName,
                      style: context.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isIncome ? '+ Tiền vào' : '- Tiền ra',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Amount
          Text(
            '${isIncome ? '+' : '-'}${CurrencyUtils.formatCurrency(res.amount)}',
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: primaryColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),

          // Description & Category
          Text(
            res.description,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Icon(
                CategoryUtils.getCategoryIcon(res.category),
                size: 16,
                color: context.colors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Danh mục: ${res.category}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              if (res.newBalance != null) ...[
                const Spacer(),
                Text(
                  'Số dư: ${CurrencyUtils.formatCurrency(res.newBalance!)}',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: _isSaved ? null : _saveTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSaved
                    ? (isDark
                          ? context.colors.surfaceContainerHighest
                          : context.colors.surfaceContainerHigh)
                    : (isDark ? AppColors.primaryTeal : context.colors.primary),
                foregroundColor: _isSaved
                    ? context.colors.onSurfaceVariant
                    : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _isSaved
                          ? Icons.check_circle_rounded
                          : Icons.save_rounded,
                      size: 18,
                    ),
              label: Text(
                _isSaved
                    ? (isVi ? 'Đã ghi vào sổ' : 'Saved to ledger')
                    : (_isSaving
                          ? (isVi ? 'Đang lưu...' : 'Saving...')
                          : (isVi ? 'Lưu vào sổ giao dịch' : 'Save to ledger')),
                style: context.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _isSaved
                      ? context.colors.onSurfaceVariant
                      : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ chia tiền hóa đơn nhóm thông minh
class GroupSplitBillCard extends StatelessWidget {
  final GroupBillSplitResult splitResult;

  const GroupSplitBillCard({super.key, required this.splitResult});

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: splitResult.shareSummaryText));
    final isVi = LanguageScope.of(context).isVietnamese;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isVi
              ? '📋 Đã sao chép nội dung chia tiền! Bạn có thể dán gửi vào Zalo/Messenger.'
              : '📋 Split bill copied to clipboard! You can paste into chat.',
        ),
        backgroundColor: context.colors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? context.colors.surface : context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.info.withValues(alpha: isDark ? 0.45 : 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.info.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.people_alt_rounded,
                  color: context.info,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      splitResult.title,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.colors.onSurface,
                      ),
                    ),
                    Text(
                      '${isVi ? "Người trả" : "Payer"}: ${splitResult.payerName}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyUtils.formatCurrency(splitResult.totalAmount),
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.info,
                ),
              ),
            ],
          ),
          Divider(
            height: 24,
            thickness: 1,
            color: context.colors.outlineVariant.withValues(alpha: 0.4),
          ),

          // Highlight per person
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceElevatedDark
                  : context.inputBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? context.colors.outline.withValues(alpha: 0.25)
                    : context.colors.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isVi
                      ? 'Mỗi người (${splitResult.memberCount} người):'
                      : 'Per person (${splitResult.memberCount} people):',
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  CurrencyUtils.formatCurrency(splitResult.perPersonAmount),
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Member list
          ...splitResult.members.map((m) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: m.isPayer
                        ? context.income
                        : context.colors.outlineVariant,
                    child: Text(
                      m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    m.name,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    m.isPayer
                        ? (isVi ? 'Đã thanh toán' : 'Paid')
                        : CurrencyUtils.formatCurrency(m.amount),
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: m.isPayer
                          ? context.income
                          : context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 14),

          // Copy Share Button
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () => _copyToClipboard(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.info,
                foregroundColor: context.colors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(
                isVi
                    ? 'Sao chép tin nhắn gửi nhóm (Zalo/Mess)'
                    : 'Copy message to share with group',
                style: context.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colors.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ hiển thị hạn mức an toàn tiêu mỗi ngày
class SafeDailySpendCard extends StatelessWidget {
  final SafeDailySpendResult result;

  const SafeDailySpendCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    Color cardColor;
    IconData statusIcon;
    switch (result.status) {
      case 'danger':
        cardColor = context.expense;
        statusIcon = Icons.warning_amber_rounded;
        break;
      case 'warning':
        cardColor = context.warning;
        statusIcon = Icons.info_outline_rounded;
        break;
      default:
        cardColor = context.income;
        statusIcon = Icons.check_circle_outline_rounded;
    }

    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? context.colors.surface : context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cardColor.withValues(alpha: isDark ? 0.45 : 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: cardColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isVi
                      ? 'Hạn mức an toàn mỗi ngày'
                      : 'Safe Daily Spending Limit',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.colors.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isVi
                      ? 'Còn ${result.daysRemaining} ngày'
                      : '${result.daysRemaining} days left',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: cardColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Safe daily amount
          Text(
            CurrencyUtils.formatCurrency(result.safeDailyAmount),
            style: context.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cardColor,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            isVi
                ? 'Số tiền bạn có thể tiêu hôm nay để không lo thâm hụt ví'
                : 'Safe amount you can spend today without overspending',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // Stats row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceElevatedDark
                  : context.inputBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? context.colors.outline.withValues(alpha: 0.25)
                    : context.colors.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  isVi ? 'Đã tiêu hôm nay' : 'Spent today',
                  CurrencyUtils.formatCurrency(result.todaySpent),
                  isDark,
                ),
                _buildStatItem(
                  context,
                  isVi ? 'Đã tiêu tháng này' : 'Spent this month',
                  CurrencyUtils.formatCurrency(result.totalSpentThisMonth),
                  isDark,
                ),
                _buildStatItem(
                  context,
                  isVi ? 'Ngân sách còn' : 'Budget left',
                  CurrencyUtils.formatCurrency(result.remainingBudget),
                  isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Advice
          Text(
            result.advice,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurface,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    bool isDark,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: context.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: context.colors.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Thẻ phân tích tiêu vặt gây thủng ví (Latte Factor)
class LatteFactorCard extends StatelessWidget {
  final LatteFactorResult result;

  const LatteFactorCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = context.warning;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? context.colors.surface : context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cardColor.withValues(alpha: isDark ? 0.45 : 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.coffee_rounded, color: cardColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi
                          ? 'Phân tích "Thủng ví" (Latte Factor)'
                          : 'Latte Factor Analysis',
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.colors.onSurface,
                      ),
                    ),
                    Text(
                      isVi
                          ? 'Các khoản tiêu vặt < 70k tưởng nhỏ mà không nhỏ'
                          : 'Small expenses that secretly add up',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Total small expenses this month
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVi
                        ? 'Tổng tiêu vặt tháng này:'
                        : 'Total small expenses this month:',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    CurrencyUtils.formatCurrency(result.totalSmallExpenses),
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cardColor,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cardColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  isVi
                      ? '${result.transactionCount} lần quẹt ví'
                      : '${result.transactionCount} transactions',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: cardColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 1-year projection banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceElevatedDark : context.warningBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: cardColor.withValues(alpha: isDark ? 0.45 : 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.savings_outlined, color: cardColor, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi
                            ? 'Nếu tiết kiệm khoản này 1 năm:'
                            : 'If saved for 1 year:',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: cardColor,
                        ),
                      ),
                      Text(
                        CurrencyUtils.formatCurrency(
                          result.projectedYearlySavings,
                        ),
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cardColor,
                        ),
                      ),
                      Text(
                        '≈ ${result.comparisonItem}',
                        style: context.textTheme.labelSmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: cardColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Text(
            result.advice,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurface,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ lộ trình tiết kiệm theo mục tiêu cụ thể
class SavingsRoadmapCard extends StatefulWidget {
  final SavingsRoadmapResult roadmap;

  const SavingsRoadmapCard({super.key, required this.roadmap});

  @override
  State<SavingsRoadmapCard> createState() => _SavingsRoadmapCardState();
}

class _SavingsRoadmapCardState extends State<SavingsRoadmapCard> {
  bool _isSaved = false;
  bool _isSaving = false;

  Future<void> _saveGoal() async {
    if (_isSaved || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      await GoalRepository().addGoal(widget.roadmap.goal);
      setState(() {
        _isSaving = false;
        _isSaved = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎯 Đã thêm mục tiêu "${widget.roadmap.goal.title}" vào Sổ Tiết Kiệm của bạn!',
            ),
            backgroundColor: context.colors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu mục tiêu: $e'),
            backgroundColor: context.expense,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final rm = widget.roadmap;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? context.colors.surface : context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.colors.primary.withValues(alpha: isDark ? 0.45 : 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withValues(
              alpha: isDark ? 0.12 : 0.08,
            ),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(
                    alpha: isDark ? 0.18 : 0.12,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.flag_rounded,
                  color: context.colors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rm.goal.title,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.colors.onSurface,
                      ),
                    ),
                    Text(
                      'Thời hạn: ${rm.monthsNeeded} tháng',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyUtils.formatCurrency(rm.goal.targetAmount),
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Plan stats
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceElevatedDark : context.incomeBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: context.income.withValues(alpha: isDark ? 0.35 : 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'Mỗi tháng cần',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.income,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyUtils.formatCurrency(rm.monthlyTarget),
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.income,
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 28,
                  width: 1,
                  color: context.income.withValues(alpha: 0.2),
                ),
                Column(
                  children: [
                    Text(
                      'Tương đương mỗi ngày',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.income,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyUtils.formatCurrency(rm.dailyTarget),
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.income,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Suggestions
          Text(
            'Gợi ý hành động từ Mono:',
            style: context.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          ...rm.cutbackSuggestions.map(
            (s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      color: context.colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      s,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Save goal button
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: _isSaved ? null : _saveGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSaved
                    ? (isDark
                          ? context.colors.surfaceContainerHighest
                          : context.colors.surfaceContainerHigh)
                    : (isDark ? AppColors.primaryTeal : context.colors.primary),
                foregroundColor: _isSaved
                    ? context.colors.onSurfaceVariant
                    : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                _isSaved ? Icons.check_circle_rounded : Icons.star_rounded,
                size: 18,
              ),
              label: Text(
                _isSaved
                    ? (isVi ? 'Đã thêm vào Sổ Tiết Kiệm' : 'Added to Savings')
                    : (_isSaving
                          ? (isVi ? 'Đang thêm...' : 'Adding...')
                          : (isVi
                                ? 'Lưu mục tiêu này vào sổ tiết kiệm'
                                : 'Save goal to savings')),
                style: context.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _isSaved
                      ? context.colors.onSurfaceVariant
                      : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ phân tích xu hướng chi tiêu & cảnh báo bất thường
class SpendingTrendCard extends StatelessWidget {
  final SpendingTrendResult trendResult;

  const SpendingTrendCard({super.key, required this.trendResult});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tr = trendResult;
    final isIncrease = tr.percentChange > 0;
    final isDecrease = tr.percentChange < 0;

    final trendColor = isIncrease
        ? (tr.percentChange > 15 ? context.expense : context.warning)
        : (isDecrease ? context.income : context.info);

    final trendIcon = isIncrease
        ? Icons.trending_up_rounded
        : (isDecrease
              ? Icons.trending_down_rounded
              : Icons.trending_flat_rounded);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? context.colors.surface : context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: trendColor.withValues(alpha: isDark ? 0.45 : 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: trendColor.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(trendIcon, color: trendColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xu hướng chi tiêu ${tr.periodName}',
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.colors.onSurface,
                      ),
                    ),
                    Text(
                      isIncrease
                          ? 'Tăng ${tr.percentChange.toStringAsFixed(1)}% so với kỳ trước'
                          : (isDecrease
                                ? 'Giảm ${tr.percentChange.abs().toStringAsFixed(1)}% so với kỳ trước'
                                : 'Chi tiêu duy trì ổn định'),
                      style: context.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: trendColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // So sánh hai kỳ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceElevatedDark
                  : context.inputBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? context.colors.outline.withValues(alpha: 0.25)
                    : context.colors.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'Kỳ này',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyUtils.formatCurrency(tr.currentExpense),
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.colors.onSurface,
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 26,
                  width: 1,
                  color: context.colors.outlineVariant.withValues(alpha: 0.4),
                ),
                Column(
                  children: [
                    Text(
                      'Kỳ trước',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyUtils.formatCurrency(tr.previousExpense),
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Cảnh báo bất thường nếu có
          if (tr.anomalies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '⚠️ Biến động đáng chú ý:',
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.warning,
              ),
            ),
            const SizedBox(height: 4),
            ...tr.anomalies.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        color: context.warning,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        a,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Thẻ điểm sức khỏe tài chính toàn diện (0 - 100)
class FinancialHealthScoreCard extends StatelessWidget {
  final FinancialHealthScoreResult result;

  const FinancialHealthScoreCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? context.colors.surface : context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: result.statusColor.withValues(alpha: isDark ? 0.45 : 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: result.statusColor.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: result.statusColor.withValues(alpha: 0.15),
                  border: Border.all(color: result.statusColor, width: 2.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${result.overallScore}',
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: result.statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isVi ? 'Sức khỏe tài chính' : 'Financial Health',
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.colors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: result.statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            result.rating,
                            style: context.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: result.statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isVi
                          ? 'Thang điểm 100 theo chuẩn quản lý tài chính'
                          : '100-point scale based on personal finance standards',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ...result.metrics.map((m) {
            final ratio = (m.score / m.maxScore).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        m.name,
                        style: context.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colors.onSurface,
                        ),
                      ),
                      Text(
                        '${m.score}/${m.maxScore}đ',
                        style: context.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 5,
                      backgroundColor: isDark
                          ? AppColors.borderDark
                          : context.colors.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ratio >= 0.8
                            ? context.income
                            : (ratio >= 0.5
                                  ? context.warning
                                  : context.expense),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m.detail,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }),

          if (result.recommendations.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '💡 Lời khuyên hành động từ Mono:',
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(height: 4),
            ...result.recommendations.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        color: context.colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        r,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Thẻ phát hiện giao dịch & chi phí định kỳ
class RecurringTransactionsCard extends StatelessWidget {
  final RecurringDetectionResult result;

  const RecurringTransactionsCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? context.colors.surface : context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.info.withValues(alpha: isDark ? 0.45 : 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: context.info.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.cached_rounded,
                  color: context.info,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi
                          ? 'Chi phí cố định định kỳ'
                          : 'Recurring Fixed Expenses',
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.colors.onSurface,
                      ),
                    ),
                    Text(
                      isVi
                          ? 'Ước tính: ${CurrencyUtils.formatCurrency(result.totalMonthlyFixedCost)}/tháng'
                          : 'Est: ${CurrencyUtils.formatCurrency(result.totalMonthlyFixedCost)}/mo',
                      style: context.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.info,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (result.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                isVi
                    ? 'Chưa phát hiện khoản chi lặp lại định kỳ nào trong 90 ngày qua.'
                    : 'No recurring fixed expenses detected in the last 90 days.',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            )
          else
            ...result.items.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceElevatedDark
                      : context.inputBgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? context.colors.outline.withValues(alpha: 0.25)
                        : context.colors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        CategoryUtils.getCategoryIcon(item.category),
                        size: 16,
                        color: context.colors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: context.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.colors.onSurface,
                            ),
                          ),
                          Text(
                            '${item.frequency} • Lần tới: ${item.nextEstimatedDate.day}/${item.nextEstimatedDate.month}',
                            style: context.textTheme.labelSmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      CurrencyUtils.formatCurrency(item.amount),
                      style: context.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.expense,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Thẻ tra cứu chi tiêu cá nhân thông minh & phân tích việc nào chi nhiều nhất
class PersonalSpendingQueryCard extends StatelessWidget {
  final PersonalSpendingQueryResult result;

  const PersonalSpendingQueryCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final primaryColor = context.colors.primary;
    final totalFormatted = CurrencyUtils.formatCurrency(result.totalAmount);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? context.colors.surface : context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: primaryColor.withValues(alpha: isDark ? 0.45 : 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Tiêu đề & Tổng chi
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: isDark ? 0.22 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.insights_rounded,
                  color: primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thống kê chi tiêu (${result.periodDescription})',
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.colors.onSurface,
                      ),
                    ),
                    Text(
                      'Tổng chi: $totalFormatted • ${result.transactionCount} giao dịch',
                      style: context.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Banner Danh mục chi tiêu nhiều nhất (Top Category Highlight)
          if (result.topCategory != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceElevatedDark
                    : primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: primaryColor.withValues(alpha: isDark ? 0.35 : 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      CategoryUtils.getCategoryIcon(result.topCategory!),
                      color: primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '👑 Chi nhiều nhất: ',
                              style: context.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              result.topCategory!,
                              style: context.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: context.colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${CurrencyUtils.formatCurrency(result.topCategoryAmount ?? 0)} (${result.topCategoryPercentage?.toStringAsFixed(1)}% tổng chi)',
                          style: context.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Thanh phân bổ danh mục (Category Breakdown Bars)
          if (result.categoryBreakdown != null &&
              result.categoryBreakdown!.isNotEmpty &&
              result.totalAmount > 0) ...[
            const SizedBox(height: 14),
            Text(
              'Cơ cấu danh mục chi tiêu:',
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ...result.categoryBreakdown!.entries.take(4).map((entry) {
              final pct = (entry.value / result.totalAmount) * 100;
              final isTop = entry.key == result.topCategory;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              CategoryUtils.getCategoryIcon(entry.key),
                              size: 14,
                              color: isTop
                                  ? primaryColor
                                  : context.colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              entry.key,
                              style: context.textTheme.bodySmall?.copyWith(
                                fontWeight: isTop
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: context.colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${CurrencyUtils.formatCurrency(entry.value)} (${pct.toStringAsFixed(0)}%)',
                          style: context.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isTop
                                ? primaryColor
                                : context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (pct / 100).clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: isDark
                            ? AppColors.borderDark
                            : context.colors.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isTop ? primaryColor : context.info,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // Khoản chi lớn nhất đơn lẻ (Top Transaction Item)
          if (result.topTransaction != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceElevatedDark
                    : context.colors.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? context.colors.outline.withValues(alpha: 0.25)
                      : context.colors.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.push_pin_rounded,
                    size: 15,
                    color: context.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Giao dịch lớn nhất: "${result.topTransaction!.description}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    CurrencyUtils.formatCurrency(result.topTransaction!.amount),
                    style: context.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.expense,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Thẻ xác nhận chuyển tiền giữa các ví (Transfer / Withdraw)
class TransferConfirmCard extends StatefulWidget {
  final WalletModel fromWallet;
  final WalletModel toWallet;
  final double amount;
  final double fee;
  final String note;
  final VoidCallback? onCompleted;

  const TransferConfirmCard({
    super.key,
    required this.fromWallet,
    required this.toWallet,
    required this.amount,
    this.fee = 0.0,
    this.note = '',
    this.onCompleted,
  });

  @override
  State<TransferConfirmCard> createState() => _TransferConfirmCardState();
}

class _TransferConfirmCardState extends State<TransferConfirmCard> {
  bool _isProcessing = false;
  bool _isSuccess = false;

  Future<void> _handleConfirmTransfer() async {
    if (_isProcessing || _isSuccess) return;
    setState(() => _isProcessing = true);

    try {
      final success = await WalletRepository().transferMoney(
        fromWalletId: widget.fromWallet.id,
        toWalletId: widget.toWallet.id,
        amount: widget.amount,
        fee: widget.fee,
        note: widget.note.isNotEmpty
            ? widget.note
            : 'Chuyển tiền qua Trợ lý Mono',
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isSuccess = success;
        });

        if (success) {
          widget.onCompleted?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Đã chuyển ${CurrencyUtils.formatCurrency(widget.amount)} từ [${widget.fromWallet.name}] sang [${widget.toWallet.name}] thành công!',
              ),
              backgroundColor: context.income,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '⚠️ Không thể hoàn tất chuyển tiền. Vui lòng kiểm tra lại số dư!',
              ),
              backgroundColor: context.expense,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi chuyển tiền: $e'),
            backgroundColor: context.expense,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = context.isDark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? context.colors.surface : context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isSuccess
              ? context.income
              : context.colors.primary.withValues(alpha: isDark ? 0.45 : 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isSuccess
                      ? context.income.withValues(alpha: 0.15)
                      : context.colors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isSuccess
                      ? Icons.check_circle_rounded
                      : Icons.swap_horiz_rounded,
                  color: _isSuccess ? context.income : context.colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isSuccess
                      ? (isVi
                            ? 'Chuyển tiền thành công'
                            : 'Transfer Successful')
                      : (isVi
                            ? 'Xác nhận chuyển tiền giữa các ví'
                            : 'Confirm Wallet Transfer'),
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _isSuccess
                        ? context.income
                        : context.colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceElevatedDark
                  : context.colors.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? context.colors.outline.withValues(alpha: 0.25)
                    : context.colors.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ví nguồn (Chuyển đi)',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.fromWallet.name,
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Số dư: ${CurrencyUtils.formatCurrency(widget.fromWallet.balance)}',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: context.colors.primary,
                    size: 18,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Ví đích (Nhận vào)',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.toWallet.name,
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Số dư: ${CurrencyUtils.formatCurrency(widget.toWallet.balance)}',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Số tiền chuyển:',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              Text(
                CurrencyUtils.formatCurrency(widget.amount),
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colors.primary,
                ),
              ),
            ],
          ),
          if (widget.fee > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Phí giao dịch:',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  CurrencyUtils.formatCurrency(widget.fee),
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          if (widget.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Ghi chú: ${widget.note}',
              style: context.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _isSuccess || _isProcessing
                  ? null
                  : _handleConfirmTransfer,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSuccess
                    ? context.income
                    : (isDark ? AppColors.primaryTeal : context.colors.primary),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _isSuccess
                          ? (isVi
                                ? '✓ Đã hoàn tất chuyển tiền'
                                : '✓ Transfer Completed')
                          : (isVi
                                ? 'Xác nhận chuyển tiền ngay'
                                : 'Confirm Transfer Now'),
                      style: context.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
