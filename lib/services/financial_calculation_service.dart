import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../models/goal_model.dart';
import '../utils/finance_precision.dart';

/// Dữ liệu tổng hợp các chỉ số tài chính chuẩn mực
class FinancialPeriodMetrics {
  final double totalIncome; // Thu nhập hoạt động (Operating Income)
  final double totalExpense; // Chi tiêu hoạt động (Operating Expense, bao gồm phí chuyển tiền)
  final double netCashFlow; // Dòng tiền thuần: totalIncome - totalExpense
  final double transferFeeTotal; // Tổng phí chuyển tiền phát sinh
  final double savingsRate; // Tỷ lệ tiết kiệm (%)
  final int transactionCount; // Số lượng giao dịch hoạt động thực tế

  const FinancialPeriodMetrics({
    required this.totalIncome,
    required this.totalExpense,
    required this.netCashFlow,
    required this.transferFeeTotal,
    required this.savingsRate,
    required this.transactionCount,
  });

  static const empty = FinancialPeriodMetrics(
    totalIncome: 0.0,
    totalExpense: 0.0,
    netCashFlow: 0.0,
    transferFeeTotal: 0.0,
    savingsRate: 0.0,
    transactionCount: 0,
  );
}

/// Dữ liệu phân loại tài sản ròng (Net Worth Breakdown)
class NetWorthMetrics {
  final double netWorth; // Tổng tài sản ròng
  final double liquidAssets; // Tài sản thanh khoản (Tiền mặt, Ngân hàng, Ví điện tử)
  final double savingsAssets; // Tài sản tích lũy (Sổ tiết kiệm, Heo đất, Mục tiêu)
  final double liabilities; // Nợ phải trả (Dư nợ thẻ tín dụng âm)

  const NetWorthMetrics({
    required this.netWorth,
    required this.liquidAssets,
    required this.savingsAssets,
    required this.liabilities,
  });

  static const empty = NetWorthMetrics(
    netWorth: 0.0,
    liquidAssets: 0.0,
    savingsAssets: 0.0,
    liabilities: 0.0,
  );
}

/// Service tính toán tài chính chuẩn mực (Financial Calculation Engine)
/// Tuân thủ nguyên tắc SSOT và triệt tiêu sai số làm tròn số học.
class FinancialCalculationService {
  const FinancialCalculationService._();

  /// Kiểm tra giao dịch có phải là tái phân bổ tài sản nội bộ (Chuyển tiền hoặc Nạp/Rút quỹ mục tiêu)
  static bool isAssetReallocation(TransactionModel tx) {
    return tx.isTransfer || tx.isSavingsGoal;
  }

  /// Tính toán các chỉ số Thu, Chi, Phí chuyển tiền, Dòng tiền và Tỷ lệ tiết kiệm trong một tập giao dịch.
  /// Tự động loại trừ chuyển tiền nội bộ và nạp/rút mục tiêu tiết kiệm để không bị tính trùng (Double-Counting).
  static FinancialPeriodMetrics calculatePeriodMetrics(
    List<TransactionModel> transactions, {
    String currency = 'VND',
    int? filterMonth,
    int? filterYear,
  }) {
    double incomeSum = 0.0;
    double expenseSum = 0.0;
    final transferExpenseById = <String, double>{};
    final transferIncomeById = <String, double>{};
    double unkeyedTransferExpenseSum = 0.0;
    double unkeyedTransferIncomeSum = 0.0;
    int count = 0;

    for (final tx in transactions) {
      if (tx.isDeleted) continue;

      if (filterMonth != null && tx.date.month != filterMonth) continue;
      if (filterYear != null && tx.date.year != filterYear) continue;

      // 1. Nếu là giao dịch chuyển tiền nội bộ
      if (tx.isTransfer) {
        final key = tx.transferId;
        if (key != null && key.isNotEmpty) {
          if (tx.isIncome) {
            transferIncomeById[key] = FinancePrecision.add(
              transferIncomeById[key] ?? 0.0,
              tx.amount,
              currency: currency,
            );
          } else {
            transferExpenseById[key] = FinancePrecision.add(
              transferExpenseById[key] ?? 0.0,
              tx.amount,
              currency: currency,
            );
          }
        } else {
          if (tx.isIncome) {
            unkeyedTransferIncomeSum = FinancePrecision.add(
              unkeyedTransferIncomeSum,
              tx.amount,
              currency: currency,
            );
          } else {
            unkeyedTransferExpenseSum = FinancePrecision.add(
              unkeyedTransferExpenseSum,
              tx.amount,
              currency: currency,
            );
          }
        }
        continue;
      }

      // 2. Nếu là giao dịch nạp/rút mục tiêu tiết kiệm (Asset Reallocation)
      if (tx.isSavingsGoal) {
        continue;
      }

      // 3. Giao dịch thu chi hoạt động thực tế
      count++;
      if (tx.isIncome) {
        incomeSum = FinancePrecision.add(
          incomeSum,
          tx.amount,
          currency: currency,
        );
      } else {
        expenseSum = FinancePrecision.add(
          expenseSum,
          tx.amount,
          currency: currency,
        );
      }
    }

    // Bóc tách phí chuyển tiền thực tế chỉ khi có đủ cả 2 vế (đi và đến)
    // để tránh tính nhầm tiền gốc thành phí khi xem đơn lẻ 1 ví hoặc vế chưa ghép cặp.
    double transferFeeTotal = 0.0;
    for (final entry in transferExpenseById.entries) {
      final matchingIncome = transferIncomeById[entry.key];
      if (matchingIncome != null) {
        final fee = FinancePrecision.subtract(
          entry.value,
          matchingIncome,
          currency: currency,
        );
        if (fee > 0) {
          transferFeeTotal = FinancePrecision.add(
            transferFeeTotal,
            fee,
            currency: currency,
          );
        }
      }
    }
    if (unkeyedTransferExpenseSum > 0 && unkeyedTransferIncomeSum > 0) {
      final unkeyedFee = FinancePrecision.subtract(
        unkeyedTransferExpenseSum,
        unkeyedTransferIncomeSum,
        currency: currency,
      );
      if (unkeyedFee > 0) {
        transferFeeTotal = FinancePrecision.add(
          transferFeeTotal,
          unkeyedFee,
          currency: currency,
        );
      }
    }

    // Chi tiêu hoạt động bao gồm cả phí chuyển khoản thực tế phát sinh
    final totalExpense = FinancePrecision.add(
      expenseSum,
      transferFeeTotal,
      currency: currency,
    );
    final totalIncome = incomeSum;
    final netCashFlow = FinancePrecision.subtract(
      totalIncome,
      totalExpense,
      currency: currency,
    );

    final savingsRate = totalIncome > 0
        ? ((totalIncome - totalExpense) / totalIncome * 100).clamp(-100.0, 100.0)
        : 0.0;

    return FinancialPeriodMetrics(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netCashFlow: netCashFlow,
      transferFeeTotal: transferFeeTotal,
      savingsRate: savingsRate,
      transactionCount: count,
    );
  }

  /// Tính toán Tổng tài sản ròng (Net Worth) và phân loại cơ cấu tài sản
  static NetWorthMetrics calculateNetWorth({
    required List<WalletModel> wallets,
    List<GoalModel> goals = const [],
    String currency = 'VND',
  }) {
    double liquid = 0.0;
    double savings = 0.0;
    double liabilities = 0.0;

    for (final w in wallets) {
      if (w.isDeleted) continue;

      if (w.type == WalletType.credit && w.balance < 0) {
        liabilities = FinancePrecision.add(
          liabilities,
          w.balance.abs(),
          currency: currency,
        );
      } else if (w.type == WalletType.savings) {
        savings = FinancePrecision.add(
          savings,
          w.balance,
          currency: currency,
        );
      } else {
        liquid = FinancePrecision.add(
          liquid,
          w.balance,
          currency: currency,
        );
      }
    }

    for (final g in goals) {
      if (g.isDeleted) continue;
      savings = FinancePrecision.add(
        savings,
        g.currentAmount,
        currency: currency,
      );
    }

    // Net Worth = (Liquid + Savings) - Liabilities
    final totalAssets = FinancePrecision.add(
      liquid,
      savings,
      currency: currency,
    );
    final netWorth = FinancePrecision.subtract(
      totalAssets,
      liabilities,
      currency: currency,
    );

    return NetWorthMetrics(
      netWorth: netWorth,
      liquidAssets: liquid,
      savingsAssets: savings,
      liabilities: liabilities,
    );
  }

  /// Tính toán số dư chuẩn mực của ví từ Sổ nhật ký giao dịch (Ledger Re-calculation)
  static double calculateWalletTrueBalance({
    required double initialBalance,
    required List<TransactionModel> walletTransactions,
    String currency = 'VND',
  }) {
    double balance = initialBalance;
    for (final tx in walletTransactions) {
      if (tx.isDeleted) continue;
      if (tx.isIncome) {
        balance = FinancePrecision.add(balance, tx.amount, currency: currency);
      } else {
        balance = FinancePrecision.subtract(balance, tx.amount, currency: currency);
      }
    }
    return balance;
  }
}
