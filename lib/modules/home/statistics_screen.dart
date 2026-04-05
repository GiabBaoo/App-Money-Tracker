import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import '../../utils/currency_format_utils.dart';
import '../transaction/transaction_detail_screen.dart';
import 'export_report_screen.dart';
import '../../widgets/transaction_item.dart';
import '../../utils/category_utils.dart';
import 'package:intl/intl.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late Stream<List<TransactionModel>> _transactionStream;

  int _selectedMainTab = 0; // Mặc định là Tuần (0)
  int _selectedFilterIndex = 0; // Mặc định là Tuần này (index 0)
  
  bool _isExpense = true;
  bool _isDescending = true;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _transactionStream = _firestoreService.getTransactionsStream();
  }

  List<String> _getFilterOptions() {
    final now = DateTime.now();
    if (_selectedMainTab == 0) {
      return ['Tuần này', 'Tuần trước', 'Tuần 1 tháng ${now.month}', 'Tuần 2 tháng ${now.month}', 'Tuần 3 tháng ${now.month}', 'Tuần 4 tháng ${now.month}'];
    } else if (_selectedMainTab == 1) {
      return List.generate(12, (i) => 'Tháng ${i + 1}');
    } else {
      return [now.year.toString(), (now.year - 1).toString(), (now.year - 2).toString()];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // === HEADER CURVE ===
          Stack(
            children: [
              Container(
                height: 140, width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.elliptical(400, 30))
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40),
                      const Text('Thống kê', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                      IconButton(
                        icon: const Icon(Icons.file_download_outlined, size: 24, color: Colors.white),
                        onPressed: () => Navigator.push(context, PageTransitions.slideRight(const ExportReportScreen())),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // === MAIN TABS (TUẦN/THÁNG/NĂM) ===
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _buildMainTab(0, 'Tuần'),
                  _buildMainTab(1, 'Tháng'),
                  _buildMainTab(2, 'Năm'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // === CAPSULE FILTER (PICKER) ===
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => _showFilterPickerSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                      boxShadow: [
                         if(!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                      ]
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 14, color: isDark ? Colors.white70 : const Color(0xFF438883)),
                        const SizedBox(width: 8),
                        Text(
                          _getFilterOptions()[_selectedFilterIndex >= _getFilterOptions().length ? 0 : _selectedFilterIndex],
                          style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF333333), fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                ),

                // NÚT LOẠI GIAO DỊCH
                GestureDetector(
                  onTap: () => setState(() {
                    _isExpense = !_isExpense;
                    _touchedIndex = -1;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isExpense ? (isDark ? const Color(0xFF3D1B1B) : const Color(0xFFFEF2F2)) : (isDark ? const Color(0xFF1B3D2F) : const Color(0xFFE8F5EE)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _isExpense ? 'Chi phí' : 'Thu nhập',
                          style: TextStyle(
                            color: _isExpense ? (isDark ? const Color(0xFFF87171) : const Color(0xFFE63946)) : (isDark ? const Color(0xFF4ADE80) : const Color(0xFF24A869)),
                            fontSize: 13,
                            fontWeight: FontWeight.w700
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.swap_horiz, color: _isExpense ? (isDark ? const Color(0xFFF87171) : const Color(0xFFE63946)) : (isDark ? const Color(0xFF4ADE80) : const Color(0xFF24A869)), size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // === CONTENT ===
          Expanded(
            child: StreamBuilder<List<TransactionModel>>(
              stream: _transactionStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                }

                final allTx = snapshot.data ?? [];
                final range = _getRangeFromFilter();
                
                final filteredAll = allTx.where((tx) {
                  final d = DateTime(tx.date.year, tx.date.month, tx.date.day);
                  return !d.isBefore(range.start) && !d.isAfter(range.end);
                }).toList();

                final filtered = filteredAll.where((tx) => _isExpense ? !tx.isIncome : tx.isIncome).toList();
                
                final chartPoints = _buildChartData(filtered, range);
                final total = filtered.fold<double>(0, (sum, tx) => sum + tx.amount);
                final topList = _getTopSpending(filtered);

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Column(
                    children: [
                      _buildWaveChart(chartPoints, total),
                      const SizedBox(height: 32),
                      _buildEnhancedTopSection(topList, total),
                      const SizedBox(height: 100),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // === NÂNG CẤP PHẦN DANH SÁCH THỐNG KÊ ===
  Widget _buildEnhancedTopSection(List<TransactionModel> topList, double total) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isExpense ? 'Danh sách chi tiêu' : 'Danh sách thu nhập',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            GestureDetector(
              onTap: () => setState(() => _isDescending = !_isDescending),
              child: Row(
                children: [
                  Text(_isDescending ? 'Cao nhất' : 'Thấp nhất', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                  Icon(_isDescending ? Icons.expand_more : Icons.expand_less, color: Colors.grey, size: 20),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        if (topList.isEmpty) 
          _buildEmptyState()
        else 
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topList.length,
            itemBuilder: (context, index) {
              final tx = topList[index];
              final double percent = total > 0 ? (tx.amount / total) : 0;
              final color = CategoryUtils.getVibrantColor(tx.category);
              final bgColor = CategoryUtils.getLightBgColor(tx.category, isDark);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    if(!isDark) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))
                  ],
                  border: isDark ? Border.all(color: Colors.white.withOpacity(0.05)) : null,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Icon Badge
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(15)),
                          child: Icon(tx.icon, color: color, size: 22),
                        ),
                        const SizedBox(width: 14),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tx.category, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              const SizedBox(height: 2),
                              Text(tx.description.isEmpty ? 'Không có nội dung' : tx.description, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        // Amount
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyUtils.formatCurrency(tx.amount),
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF333333), fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            Text('${(percent * 100).toStringAsFixed(1)}%', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Progress Bar
                    Stack(
                      children: [
                        Container(
                          height: 6, width: double.infinity,
                          decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                        ),
                        FractionallySizedBox(
                          widthFactor: percent,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.analytics_outlined, size: 60, color: Colors.grey.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('Chưa có dữ liệu thống kê', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // BOTTOM SHEET PICKER CHO BỘ LỌC
  void _showFilterPickerSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final options = _getFilterOptions();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 400,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 24),
            Text('Chọn ${_selectedMainTab == 0 ? 'Tuần' : _selectedMainTab == 1 ? 'Tháng' : 'Năm'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedFilterIndex;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilterIndex = index;
                        _touchedIndex = -1;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor : (isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            options[index],
                            style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87), fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
                          ),
                          if (isSelected) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        ],
                      ),
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

  // --- LOGIC HỖ TRỢ ---
  ({DateTime start, DateTime end}) _getRangeFromFilter() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_selectedMainTab == 0) {
      if (_selectedFilterIndex == 0) return (start: today.subtract(Duration(days: today.weekday - 1)), end: today);
      if (_selectedFilterIndex == 1) return (start: today.subtract(Duration(days: today.weekday - 1 + 7)), end: today.subtract(Duration(days: today.weekday)));
      final weekIdx = _selectedFilterIndex - 2;
      final startOfMonth = DateTime(now.year, now.month, 1);
      final start = startOfMonth.add(Duration(days: weekIdx * 7));
      var end = start.add(const Duration(days: 6));
      if (end.month != now.month) end = DateTime(now.year, now.month + 1, 0);
      return (start: start, end: end);
    } else if (_selectedMainTab == 1) {
      final month = _selectedFilterIndex + 1;
      return (start: DateTime(now.year, month, 1), end: DateTime(now.year, month + 1, 0));
    } else {
      final year = now.year - _selectedFilterIndex;
      return (start: DateTime(year, 1, 1), end: DateTime(year, 12, 31));
    }
  }

  Widget _buildMainTab(int index, String label) {
    bool isSelected = _selectedMainTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedMainTab = index;
          if (index == 0) _selectedFilterIndex = 0;
          if (index == 1) _selectedFilterIndex = DateTime.now().month - 1;
          if (index == 2) _selectedFilterIndex = 0;
          _touchedIndex = -1;
        }),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF438883) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaveChart(List<_ChartPoint> data, double total) {
    if (data.isEmpty) {
      return Container(
        height: 250, width: double.infinity,
        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text('Chưa có dữ liệu', style: TextStyle(color: Color(0xFF999999)))),
      );
    }
    final maxY = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final safeMaxY = maxY <= 0 ? 1.0 : maxY * 1.3;
    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0, maxX: (data.length - 1).toDouble(),
          minY: 0, maxY: safeMaxY,
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true, reservedSize: 32, interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(data[idx].label, style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2E2E2E) : Colors.white,
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(CurrencyUtils.formatCurrency(s.y), const TextStyle(color: Color(0xFF438883), fontWeight: FontWeight.bold))).toList(),
            ),
            handleBuiltInTouches: true,
          ),
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
              isCurved: true, color: const Color(0xFF438883), barWidth: 3, isStrokeCapRound: true,
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [const Color(0xFF438883).withOpacity(0.2), const Color(0xFF438883).withOpacity(0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_ChartPoint> _buildChartData(List<TransactionModel> transactions, ({DateTime start, DateTime end}) range) {
    List<_ChartPoint> result = [];
    final diff = range.end.difference(range.start).inDays;
    if (diff <= 10) {
      final dayNames = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
      for (int i = 0; i <= diff; i++) {
        final d = range.start.add(Duration(days: i));
        final val = transactions.where((tx) => tx.date.day == d.day && tx.date.month == d.month).fold<double>(0, (s, tx) => s + tx.amount);
        result.add(_ChartPoint(label: dayNames[d.weekday % 7], value: val));
      }
    } else if (diff <= 31) {
      for (int i = 0; i < 4; i++) {
        final val = transactions.where((tx) => tx.date.day > i * 7 && tx.date.day <= (i + 1) * 7).fold<double>(0, (s, tx) => s + tx.amount);
        result.add(_ChartPoint(label: 'W${i+1}', value: val));
      }
    } else {
      for (int i = 1; i <= 12; i++) {
        final val = transactions.where((tx) => tx.date.month == i).fold<double>(0, (s, tx) => s + tx.amount);
        result.add(_ChartPoint(label: 'T$i', value: val));
      }
    }
    return result;
  }

  List<TransactionModel> _getTopSpending(List<TransactionModel> txs) {
    final list = List<TransactionModel>.from(txs);
    list.sort((a, b) => _isDescending ? b.amount.compareTo(a.amount) : a.amount.compareTo(b.amount));
    return list.take(5).toList();
  }
}

class _ChartPoint {
  final String label;
  final double value;
  _ChartPoint({required this.label, required this.value});
}