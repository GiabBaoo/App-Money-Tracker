import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/page_transitions.dart';
import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import '../home/notification_screen.dart';
import '../../utils/currency_format_utils.dart';
import '../../widgets/transaction_item.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late DateTime _selectedMonth;
  late int _viewingYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _viewingYear = now.year;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // === HEADER (ĐỒNG BỘ) ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  const Text('Ví cá nhân', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                    onPressed: () => Navigator.push(context, PageTransitions.slideRight(const NotificationScreen())),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),

            // === BỘ CHỌN THÁNG DẠNG CAPSULE HIỆN ĐẠI ===
            GestureDetector(
              onTap: () => _showMonthPickerSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F2625).withOpacity(0.5) : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_outlined, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Tháng ${DateFormat('MM / yyyy').format(_selectedMonth)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // === DANH SÁCH GIAO DỊCH TINH GỌN ===
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: StreamBuilder<List<TransactionModel>>(
                  stream: _firestoreService.getTransactionsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allTx = snapshot.data ?? [];
                    final filteredTx = allTx.where((tx) => 
                      tx.date.year == _selectedMonth.year && tx.date.month == _selectedMonth.month
                    ).toList();

                    if (filteredTx.isEmpty) {
                      return _buildEmptyState(context);
                    }

                    filteredTx.sort((a, b) => b.date.compareTo(a.date));
                    final grouped = _groupTransactionsByDate(filteredTx);

                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 30, bottom: 100, left: 24, right: 24),
                      itemCount: grouped.length,
                      itemBuilder: (context, index) {
                        final date = grouped.keys.elementAt(index);
                        final dayTransactions = grouped[date]!;
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSimplifiedDateHeader(context, date),
                            const SizedBox(height: 16),
                            ...dayTransactions.map((tx) => TransactionItem(transaction: tx)).toList(),
                            const SizedBox(height: 32),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimplifiedDateHeader(BuildContext context, DateTime date) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    
    String label = isToday ? 'Hôm nay' : '${date.day} tháng ${date.month}';
    if (date.year != now.year) label += ', ${date.year}';

    return Text(
      label,
      style: TextStyle(
        color: isDark ? Colors.white38 : Colors.grey.shade500,
        fontWeight: FontWeight.w700,
        fontSize: 13,
        letterSpacing: 0.5,
      ),
    );
  }

  void _showMonthPickerSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final now = DateTime.now();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 24),
              const Text('Lọc theo thời gian', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => setModalState(() => _viewingYear--),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Year $_viewingYear',
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setModalState(() => _viewingYear++),
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.2,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final month = index + 1;
                    final isSelected = month == _selectedMonth.month && _viewingYear == _selectedMonth.year;
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedMonth = DateTime(_viewingYear, month));
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? primaryColor : (isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6)),
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected ? null : Border.all(color: Colors.grey.withOpacity(0.1)),
                        ),
                        child: Center(
                          child: Text(
                            'Tháng $month',
                            style: TextStyle(
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  setState(() {
                    _viewingYear = now.year;
                    _selectedMonth = DateTime(now.year, now.month);
                  });
                  Navigator.pop(context);
                },
                child: Text('Trở về hôm nay', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Map<DateTime, List<TransactionModel>> _groupTransactionsByDate(List<TransactionModel> txs) {
    Map<DateTime, List<TransactionModel>> groups = {};
    for (var tx in txs) {
      final date = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (!groups.containsKey(date)) groups[date] = [];
      groups[date]!.add(tx);
    }
    return groups;
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.grey.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'Không có dữ liệu T${_selectedMonth.month}/${_selectedMonth.year}',
            style: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
