import 'package:flutter/services.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../data/repositories/wallet_repository.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    // Remove all non-numeric characters
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cleanText.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    double value = double.parse(cleanText);
    String newText = CurrencyUtils.formatCurrency(value);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length - 1), // Place cursor before 'đ'
    );
  }
}
class CurrencyUtils {
  static String formatCurrency(double amount) {
    // Format tiền kiểu Việt: 1000000 -> 1.000.000đ, -455964 -> -455.964đ
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    String amountStr = absAmount.toStringAsFixed(0);
    
    // Thêm dấu chấm vào mỗi 3 chữ số từ phải sang
    final buffer = StringBuffer();
    int count = 0;
    
    for (int i = amountStr.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(amountStr[i]);
      count++;
    }
    
    // Đảo lại chuỗi và thêm đ
    final reversed = buffer.toString().split('').reversed.join('');
    return isNegative ? '-$reversedđ' : '$reversedđ';
  }

  static String formatNumberOnly(double amount) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    String amountStr = absAmount.toStringAsFixed(0);
    final buffer = StringBuffer();
    int count = 0;
    for (int i = amountStr.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(amountStr[i]);
      count++;
    }
    final reversed = buffer.toString().split('').reversed.join('');
    return isNegative ? '-$reversed' : reversed;
  }

  static String formatAmountWithSign(double amount, bool isIncome) {
    String formatted = formatCurrency(amount);
    String withoutSymbol = formatted.replaceAll('đ', '').trim();
    return isIncome ? "+$withoutSymbolđ" : "-$withoutSymbolđ";
  }

  static double parseCurrency(String text) {
    String cleanText = text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(cleanText) ?? 0;
  }

  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Tính tổng tiền lũy kế (tính đến thời điểm ghi thu/chi) cho từng giao dịch
  static Map<String, double> calculateRunningTotals(List<TransactionModel> transactions) {
    if (transactions.isEmpty) return {};

    final sorted = List<TransactionModel>.from(transactions)
      ..sort((a, b) {
        int c = a.date.compareTo(b.date);
        if (c != 0) return c;
        c = a.time.compareTo(b.time);
        if (c != 0) return c;
        return a.createdAt.compareTo(b.createdAt);
      });

    final Map<String, double> totals = {};
    double expenseSum = 0;
    double incomeSum = 0;

    for (int i = 0; i < sorted.length; i++) {
      final tx = sorted[i];
      if (tx.isIncome) {
        incomeSum += tx.amount;
        final key = tx.id.isNotEmpty ? tx.id : '${tx.date.millisecondsSinceEpoch}_$i';
        totals[key] = incomeSum;
      } else {
        expenseSum += tx.amount;
        final key = tx.id.isNotEmpty ? tx.id : '${tx.date.millisecondsSinceEpoch}_$i';
        totals[key] = expenseSum;
      }
    }
    return totals;
  }

  /// So sánh hai giao dịch theo thứ tự thời gian chuẩn xác nhất (Canonical Comparator):
  /// 1. Ngày giao dịch (chuẩn hóa yyyy-MM-dd, bỏ qua phần giờ/phút/giây ngẫu nhiên trong Date)
  /// 2. Giờ phút giao dịch (chuỗi 'HH:mm', ví dụ '18:30' > '09:15')
  /// 3. Thời điểm tạo giao dịch (createdAt)
  /// 4. ID giao dịch (tie-breaker tuyệt đối)
  static int compareTransactionsChronological(TransactionModel a, TransactionModel b) {
    // 1. So sánh ngày (Mới nhất lên đầu)
    final dateA = DateTime(a.date.year, a.date.month, a.date.day);
    final dateB = DateTime(b.date.year, b.date.month, b.date.day);
    final int dateComp = dateB.compareTo(dateA);
    if (dateComp != 0) return dateComp;

    // 2. So sánh chuỗi giờ 'HH:mm' (ví dụ: '18:00' > '09:00')
    final int timeComp = b.time.compareTo(a.time);
    if (timeComp != 0) return timeComp;

    // 3. So sánh createdAt
    final int createdComp = b.createdAt.compareTo(a.createdAt);
    if (createdComp != 0) return createdComp;

    // 4. Tie-breaker bằng ID để đảm bảo tính tất định (deterministic)
    return b.id.compareTo(a.id);
  }

  /// Tính số dư ví tính đến thời điểm ghi giao dịch bằng cách cộng/trừ ngược lại
  /// so với số dư ví hiện tại (chuẩn xác nhất theo nguyên lý sổ phụ ngân hàng).
  ///
  /// - Giao dịch mới nhất của ví: Số dư = Số dư hiện tại của ví đó.
  /// - Lùi về quá khứ (từ mới nhất -> cũ nhất):
  ///   + Nếu giao dịch là THU NHẬP: số dư trước đó = số dư sau đó - số tiền thu
  ///   + Nếu giao dịch là CHI TIÊU: số dư trước đó = số dư sau đó + số tiền chi
  static Map<String, double> calculateReverseWalletBalances({
    required List<TransactionModel> allTransactions,
    List<WalletModel>? wallets,
  }) {
    if (allTransactions.isEmpty) return {};

    // 1. Nếu wallets rỗng, tự động lấy danh sách ví từ cache tươi mới của WalletRepository
    final effectiveWallets = (wallets != null && wallets.isNotEmpty)
        ? wallets
        : WalletRepository().latestWallets;

    final Map<String, double> walletCurrentBalances = {
      for (final w in effectiveWallets) w.id: w.balance,
    };

    final defaultWallet = effectiveWallets.isNotEmpty
        ? effectiveWallets.firstWhere((w) => w.isDefault, orElse: () => effectiveWallets.first)
        : null;
    final defaultWalletId = defaultWallet?.id ?? '';
    final defaultBalance = defaultWallet?.balance ?? 0.0;

    // 2. Nhóm giao dịch theo walletId (nếu rỗng thì gán vào defaultWallet)
    final Map<String, List<TransactionModel>> txsByWallet = {};
    for (final tx in allTransactions) {
      final wId = tx.walletId.isNotEmpty ? tx.walletId : defaultWalletId;
      txsByWallet.putIfAbsent(wId, () => []).add(tx);
    }

    final Map<String, double> balanceMap = {};

    // 3. Với từng ví, sắp xếp giao dịch từ MỚI NHẤT -> CŨ NHẤT bằng hàm so sánh chuẩn và tính lùi
    for (final entry in txsByWallet.entries) {
      final wId = entry.key;
      final txs = entry.value;

      final currentBalance = walletCurrentBalances[wId] ?? defaultBalance;

      // Sắp xếp MỚI NHẤT -> CŨ NHẤT bằng hàm compare canonical
      txs.sort(compareTransactionsChronological);

      double running = currentBalance;
      for (final tx in txs) {
        if (tx.id.isNotEmpty) {
          balanceMap[tx.id] = running;
        }

        // Tính ngược lại:
        if (tx.isIncome) {
          running -= tx.amount;
        } else {
          running += tx.amount;
        }
      }
    }

    return balanceMap;
  }
}
