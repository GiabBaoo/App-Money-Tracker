import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';

import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import '../home/home_screen.dart';
import 'transaction_detail_screen.dart';

class AllTransactionsScreen extends StatelessWidget {
  const AllTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF222222), size: 20), onPressed: () => Navigator.pop(context)),
                const Text('Lịch sử giao dịch', style: TextStyle(color: Color(0xFF222222), fontSize: 18, fontWeight: FontWeight.w600)),
                IconButton(icon: const Icon(Icons.filter_list, color: Color(0xFF222222), size: 24), onPressed: () {}),
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
                      Icon(Icons.receipt_long, size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('Chưa có giao dịch nào', style: TextStyle(color: Color(0xFF999999), fontSize: 16)),
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
                            date: HomeBody.formatDate(tx.date),
                            amount: '${tx.isIncome ? "+" : "-"} ${HomeBody.formatCurrency(tx.amount)}',
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
      final key = HomeBody.formatDate(tx.date);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(tx);
    }
    return grouped;
  }

  Widget _buildDateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(date, style: const TextStyle(color: Color(0xFF666666), fontSize: 16, fontWeight: FontWeight.w600)),
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
          isIncome: isIncome, title: title, amount: amount, date: date, time: transaction.time, icon: icon,
        ))),
        child: Row(children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: const Color(0xFFF0F6F5), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: const Color(0xFF438883), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
            const SizedBox(height: 4),
            Text(date, style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
          ])),
          Text(amount, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isIncome ? const Color(0xFF24A869) : const Color(0xFFF95B51))),
        ]),
      ),
    );
  }
}
