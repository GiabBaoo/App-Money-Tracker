import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import '../../utils/currency_format_utils.dart';
import '../../widgets/transaction_item.dart';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedType = 'Tất cả';
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    // Mặc định lọc tháng hiện tại theo yêu cầu
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  void _resetFilters() {
    setState(() {
      _selectedType = 'Tất cả';
      _selectedDateRange = null; // Khi reset hoàn toàn thì cho xem tất cả hoặc tùy ý
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // HEADER & FILTER ICON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text('Lịch sử giao dịch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(
                      Icons.filter_list,
                      size: 26,
                      color: (_selectedType != 'Tất cả' || _selectedDateRange != null)
                          ? const Color(0xFF438883)
                          : Theme.of(context).iconTheme.color,
                    ),
                    onPressed: () => _showFilterBottomSheet(context),
                  ),
                ],
              ),
            ),

            // CHIP HIỂN THỊ BỘ LỌC ĐANG CHỌN (NẾU CÓ)
            if (_selectedType != 'Tất cả' || _selectedDateRange != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_selectedType != 'Tất cả')
                        _buildFilterChip(_selectedType, () => setState(() => _selectedType = 'Tất cả')),
                      if (_selectedDateRange != null)
                        _buildFilterChip(
                          '${CurrencyUtils.formatDate(_selectedDateRange!.start)} - ${CurrencyUtils.formatDate(_selectedDateRange!.end)}',
                          () => setState(() => _selectedDateRange = null),
                        ),
                      TextButton(
                        onPressed: _resetFilters,
                        child: const Text('Xóa tất cả', style: TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // DANH SÁCH GIAO DỊCH REALTIME VỚI BỘ LỌC
            Expanded(
              child: StreamBuilder<List<TransactionModel>>(
                stream: _firestoreService.getTransactionsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                  }

                  // 1. ÁP DỤNG BỘ LỌC
                  List<TransactionModel> transactions = snapshot.data ?? [];
                  
                  // LỌC THỨ TỰ (Tie-breaker cho các giao dịch cùng ngày bằng time và createdAt)
                  transactions.sort((a, b) {
                    DateTime dateA = DateTime(a.date.year, a.date.month, a.date.day);
                    DateTime dateB = DateTime(b.date.year, b.date.month, b.date.day);
                    int dateComp = dateB.compareTo(dateA);
                    if (dateComp != 0) return dateComp;
                    int timeComp = b.time.compareTo(a.time);
                    if (timeComp != 0) return timeComp;
                    if (a.createdAt != null && b.createdAt != null) {
                      return b.createdAt!.compareTo(a.createdAt!);
                    }
                    return 0;
                  });
                  
                  // Lọc theo loại hình
                  if (_selectedType == 'Thu nhập') {
                    transactions = transactions.where((tx) => tx.isIncome).toList();
                  } else if (_selectedType == 'Chi tiêu') {
                    transactions = transactions.where((tx) => !tx.isIncome).toList();
                  }
                  
                  // Lọc theo thời gian
                  if (_selectedDateRange != null) {
                    transactions = transactions.where((tx) {
                      final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
                      return !txDate.isBefore(_selectedDateRange!.start) && 
                             !txDate.isAfter(_selectedDateRange!.end);
                    }).toList();
                  }

                  if (transactions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 60, color: Colors.grey.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text('Không tìm thấy giao dịch nào', style: TextStyle(color: Colors.grey.withValues(alpha: 0.6), fontSize: 16)),
                        ],
                      ),
                    );
                  }

                  // 2. NHÓM GIAO DỊCH THEO NGÀY
                  final grouped = _groupByDate(transactions);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...grouped.entries.expand((entry) => [
                          _buildDateHeader(entry.key),
                          ...entry.value.map((tx) => TransactionItem(
                                transaction: tx,
                                showDate: false, // Vì đã có Header ngày rồi
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

  Widget _buildFilterChip(String label, VoidCallback onDeleted) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        onDeleted: onDeleted,
        deleteIcon: const Icon(Icons.close, size: 14),
        backgroundColor: const Color(0xFF438883).withValues(alpha: 0.1),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  // BỘ LỌC BOTTOM SHEET
  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bộ lọc giao dịch', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  
                  // LỌC THEO LOẠI HÌNH
                  const Text('Loại giao dịch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: ['Tất cả', 'Thu nhập', 'Chi tiêu'].map((tp) {
                      final isSelected = _selectedType == tp;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() => _selectedType = tp);
                            setState(() {}); // Cập nhật màn hình chính
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF438883) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? const Color(0xFF438883) : Colors.grey.withValues(alpha: 0.3)),
                            ),
                            child: Center(
                              child: Text(
                                tp,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // LỌC THEO THỜI GIAN
                  const Text('Thời gian', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDateRange: _selectedDateRange,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color(0xFF438883),
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: Colors.black,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (range != null) {
                        setModalState(() => _selectedDateRange = range);
                        setState(() {});
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, color: Color(0xFF438883)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedDateRange == null
                                  ? 'Chọn khoảng thời gian'
                                  : '${CurrencyUtils.formatDate(_selectedDateRange!.start)} - ${CurrencyUtils.formatDate(_selectedDateRange!.end)}',
                              style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, size: 20),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                  
                  // NÚT HOÀN TẤT
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF438883),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Xem kết quả', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
        padding: const EdgeInsets.only(bottom: 12, top: 12),
        child: Text(
          date, 
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5), 
            fontSize: 14, 
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          )
        ),
      ),
    );
  }
}
