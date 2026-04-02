import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';

import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import '../home/home_screen.dart';
import '../../utils/currency_format_utils.dart';
import 'transaction_detail_screen.dart';

class AllTransactionsScreen extends StatelessWidget {
  const AllTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios, size: 20), onPressed: () => Navigator.pop(context)),
                const Text('Lịch sử giao dịch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                IconButton(icon: const Icon(Icons.filter_list, size: 24), onPressed: () {}),
              ]),
            ),
            const SizedBox(height: 10),

            // DANH SÁCH GIAO DỊCH REALTIME
            Expanded(
              child: StreamBuilder<List<TransactionModel>>(
                stream: firestoreService.getTransactionsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                  }

                  final transactions = snapshot.data ?? [];
                  if (transactions.isEmpty) {
                    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.receipt_long, size: 60, color: Theme.of(context).iconTheme.color?.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text('Chưa có giao dịch nào', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 16)),
                    ]));
                  }

                  // Nhóm giao dịch theo ngày
                  final grouped = _groupByDate(transactions);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...grouped.entries.expand((entry) => [
                          _buildDateHeader(entry.key),
                          ...entry.value.map((tx) => _buildTransactionItem(
                            context: context,
                            icon: tx.icon,
                            title: tx.category,
                            date: CurrencyUtils.formatDate(tx.date),
                            amount: '${tx.isIncome ? "+" : "-"} ${CurrencyUtils.formatCurrency(tx.amount)}',
                            isIncome: tx.isIncome,
                            transaction: tx,
                          )),
                          const SizedBox(height: 16),
                        ]),
                        const SizedBox(height: 40),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Nhóm giao dịch theo ngày
  Map<String, List<TransactionModel>> _groupByDate(List<TransactionModel> transactions) {
    final Map<String, List<TransactionModel>> grouped = {};
    for (var tx in transactions) {
      final key = CurrencyUtils.formatDate(tx.date);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(tx);
    }
    return grouped;
  }

  Widget _buildDateHeader(String date) {
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 8),
        child: Text(date, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildTransactionItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String date,
    required String amount,
    required bool isIncome,
    required TransactionModel transaction,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => Navigator.push(context, PageTransitions.slideRight(TransactionDetailScreen(
          transaction: transaction,
        ))),
        child: Row(children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF2E2E2E) 
                : const Color(0xFFF0F6F5), 
              borderRadius: BorderRadius.circular(12)
            ),
            child: Icon(icon, color: isIncome ? const Color(0xFF24A869) : const Color(0xFFE17E5B), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color)),
            const SizedBox(height: 4),
            Text(date, style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6))),
          ])),
          Text(amount, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isIncome ? const Color(0xFF24A869) : const Color(0xFFE17E5B))),
        ]),
      ),
    );
  }
}
