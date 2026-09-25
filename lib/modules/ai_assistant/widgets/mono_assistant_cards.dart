import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                (w.accountNumber.isNotEmpty && res.rawMessage.contains(w.accountNumber)),
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
        time: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        description: res.description.isNotEmpty ? res.description : 'Giao dịch qua ${res.bankName}',
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
        final walletNotice = targetWallet != null ? ' (Ví: ${targetWallet.name})' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Đã lưu ${res.type == 'income' ? 'khoản thu' : 'khoản chi'} ${CurrencyUtils.formatCurrency(res.amount)}$walletNotice vào sổ!'),
            backgroundColor: const Color(0xFF438883),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      widget.onSaved?.call();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = widget.parseResult;
    final isIncome = res.type == 'income';
    final primaryColor = isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF438883).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_rounded, size: 14, color: Color(0xFF438883)),
                    const SizedBox(width: 5),
                    Text(
                      res.bankName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF438883)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isIncome ? '+ Tiền vào' : '- Tiền ra',
                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Amount
          Text(
            '${isIncome ? '+' : '-'}${CurrencyUtils.formatCurrency(res.amount)}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: primaryColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),

          // Description & Category
          Text(
            res.description,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Icon(CategoryUtils.getCategoryIcon(res.category), size: 16, color: const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                'Danh mục: ${res.category}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              if (res.newBalance != null) ...[
                const Spacer(),
                Text(
                  'Số dư: ${CurrencyUtils.formatCurrency(res.newBalance!)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
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
                backgroundColor: _isSaved ? const Color(0xFFE2E8F0) : const Color(0xFF438883),
                foregroundColor: _isSaved ? const Color(0xFF64748B) : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_isSaved ? Icons.check_circle_rounded : Icons.save_rounded, size: 18),
              label: Text(
                _isSaved ? 'Đã ghi vào sổ' : (_isSaving ? 'Đang lưu...' : 'Lưu vào sổ giao dịch'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Đã sao chép nội dung chia tiền! Bạn có thể dán gửi vào Zalo/Messenger.'),
        backgroundColor: Color(0xFF438883),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.08),
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
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people_alt_rounded, color: Color(0xFF6366F1), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      splitResult.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      'Người trả: ${splitResult.payerName}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyUtils.formatCurrency(splitResult.totalAmount),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF6366F1)),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),

          // Highlight per person
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mỗi người (${splitResult.memberCount} người):',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                ),
                Text(
                  CurrencyUtils.formatCurrency(splitResult.perPersonAmount),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
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
                    backgroundColor: m.isPayer ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                    child: Text(
                      m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(m.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    m.isPayer ? 'Đã thanh toán' : CurrencyUtils.formatCurrency(m.amount),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: m.isPayer ? const Color(0xFF10B981) : const Color(0xFF475569),
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
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Sao chép tin nhắn gửi nhóm (Zalo/Mess)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
        cardColor = const Color(0xFFEF4444);
        statusIcon = Icons.warning_amber_rounded;
        break;
      case 'warning':
        cardColor = const Color(0xFFF59E0B);
        statusIcon = Icons.info_outline_rounded;
        break;
      default:
        cardColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cardColor.withValues(alpha: 0.08),
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
                  color: cardColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: cardColor, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Hạn mức an toàn mỗi ngày',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Còn ${result.daysRemaining} ngày',
                  style: TextStyle(color: cardColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Safe daily amount
          Text(
            CurrencyUtils.formatCurrency(result.safeDailyAmount),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: cardColor, letterSpacing: -0.5),
          ),
          const Text(
            'Số tiền bạn có thể tiêu hôm nay để không lo thâm hụt ví',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          // Stats row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Đã tiêu hôm nay', CurrencyUtils.formatCurrency(result.todaySpent)),
                _buildStatItem('Đã tiêu tháng này', CurrencyUtils.formatCurrency(result.totalSpentThisMonth)),
                _buildStatItem('Ngân sách còn', CurrencyUtils.formatCurrency(result.remainingBudget)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Advice
          Text(
            result.advice,
            style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF97316).withValues(alpha: 0.08),
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
                  color: const Color(0xFFF97316).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.coffee_rounded, color: Color(0xFFF97316), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phân tích "Thủng ví" (Latte Factor)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      'Các khoản tiêu vặt < 70k tưởng nhỏ mà không nhỏ',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
                  const Text('Tổng tiêu vặt tháng này:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Text(
                    CurrencyUtils.formatCurrency(result.totalSmallExpenses),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFF97316)),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${result.transactionCount} lần quẹt ví',
                  style: const TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 1-year projection banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.savings_outlined, color: Color(0xFFD97706), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nếu tiết kiệm khoản này 1 năm:',
                        style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                      ),
                      Text(
                        CurrencyUtils.formatCurrency(result.projectedYearlySavings),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                      ),
                      Text(
                        '≈ ${result.comparisonItem}',
                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF78350F)),
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
            style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
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
            content: Text('🎯 Đã thêm mục tiêu "${widget.roadmap.goal.title}" vào Sổ Tiết Kiệm của bạn!'),
            backgroundColor: const Color(0xFF438883),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu mục tiêu: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rm = widget.roadmap;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF438883).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF438883).withValues(alpha: 0.08),
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
                  color: const Color(0xFF438883).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flag_rounded, color: Color(0xFF438883), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rm.goal.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      'Thời hạn: ${rm.monthsNeeded} tháng',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyUtils.formatCurrency(rm.goal.targetAmount),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF438883)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Plan stats
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Mỗi tháng cần', style: TextStyle(fontSize: 11, color: Color(0xFF166534))),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyUtils.formatCurrency(rm.monthlyTarget),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                    ),
                  ],
                ),
                Container(height: 28, width: 1, color: const Color(0xFFBBF7D0)),
                Column(
                  children: [
                    const Text('Tương đương mỗi ngày', style: TextStyle(fontSize: 11, color: Color(0xFF166534))),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyUtils.formatCurrency(rm.dailyTarget),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Suggestions
          const Text('Gợi ý hành động từ Mono:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          const SizedBox(height: 4),
          ...rm.cutbackSuggestions.map((s) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: Color(0xFF438883), fontWeight: FontWeight.bold)),
                Expanded(child: Text(s, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
              ],
            ),
          )),
          const SizedBox(height: 14),

          // Save goal button
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: _isSaved ? null : _saveGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSaved ? const Color(0xFFE2E8F0) : const Color(0xFF438883),
                foregroundColor: _isSaved ? const Color(0xFF64748B) : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(_isSaved ? Icons.check_circle_rounded : Icons.star_rounded, size: 18),
              label: Text(
                _isSaved ? 'Đã thêm vào Sổ Tiết Kiệm' : (_isSaving ? 'Đang thêm...' : 'Lưu mục tiêu này vào sổ tiết kiệm'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
