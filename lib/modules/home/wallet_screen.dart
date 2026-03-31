import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import '../home/home_screen.dart';
import '../transaction/transaction_detail_screen.dart';
import '../home/notification_screen.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
        ? const Color(0xFF1E1E1E) 
        : const Color(0xFF438883),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // APP BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const SizedBox(width: 32),
                const Text('Ví', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                InkWell(
                  onTap: () => Navigator.push(context, PageTransitions.slideRight(const NotificationScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.notifications_none, color: Colors.white),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 30),

            // NỘI DUNG
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor, 
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30))
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 40, bottom: 120),
                  child: Column(
                    children: [
                      // TỔNG SỐ DƯ REALTIME
                      StreamBuilder<({double balance, double totalIncome, double totalExpense})>(
                        stream: firestoreService.getBalanceStream(),
                        builder: (context, snapshot) {
                          final balance = snapshot.data?.balance ?? 0;
                          return Column(children: [
                            Text('Tổng số dư', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(HomeBody.formatCurrency(balance), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 32, fontWeight: FontWeight.bold)),
                          ]);
                        },
                      ),
                      const SizedBox(height: 30),

                      Container(
                        width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark 
                            ? const Color(0xFF2E2E2E) 
                            : const Color(0xFFF4F6F6), 
                          borderRadius: BorderRadius.circular(30)
                        ),
                        child: Text('Transactions', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 20),

                      // DANH SÁCH GIAO DỊCH REALTIME
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: StreamBuilder<List<TransactionModel>>(
                          stream: firestoreService.getTransactionsStream(),
                          builder: (context, snapshot) {
                            final transactions = snapshot.data ?? [];
                            if (transactions.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(40),
                                child: Text('Chưa có giao dịch nào', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 16)),
                              );
                            }
                            return Column(
                              children: transactions.map((tx) => _buildTransactionItem(
                                context: context,
                                icon: tx.icon,
                                iconColor: tx.isIncome ? Colors.green : Colors.red,
                                title: tx.category,
                                date: HomeBody.formatDate(tx.date),
                                amount: '${tx.isIncome ? "+" : "-"} ${HomeBody.formatCurrency(tx.amount)}',
                                isIncome: tx.isIncome,
                                transaction: tx,
                              )).toList(),
                            );
                          },
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

  Widget _buildTransactionItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String date,
    required String amount,
    required bool isIncome,
    required TransactionModel transaction,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: () => Navigator.push(context, PageTransitions.slideRight(TransactionDetailScreen(
          isIncome: isIncome, title: title, amount: amount, date: date, time: transaction.time, icon: icon,
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
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(date, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 13)),
          ])),
          Text(amount, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isIncome ? const Color(0xFF24A869) : const Color(0xFFF95B51))),
        ]),
      ),
    );
  }
}
