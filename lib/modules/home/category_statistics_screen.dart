import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/transaction_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/currency_format_utils.dart';
import '../../utils/category_utils.dart';

class CategoryStatisticsScreen extends StatefulWidget {
  final String type; // 'income' or 'expense'

  const CategoryStatisticsScreen({super.key, required this.type});

  @override
  State<CategoryStatisticsScreen> createState() => _CategoryStatisticsScreenState();
}

class _CategoryStatisticsScreenState extends State<CategoryStatisticsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late String _currentType;
  int touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _currentType = widget.type;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String title = _currentType == 'income' ? 'Thống kê Thu nhập' : 'Thống kê Chi phí';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Segmented Toggle Control
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
            child: Container(
              height: 45,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildToggleItem('Chi phí', 'expense', isDark),
                  _buildToggleItem('Thu nhập', 'income', isDark),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: StreamBuilder<List<TransactionModel>>(
              stream: _firestoreService.getTransactionsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Chưa có dữ liệu giao dịch', style: TextStyle(color: Colors.grey)));
                }

                final now = DateTime.now();
                final filteredData = snapshot.data!.where((tx) => 
                  tx.type == _currentType && 
                  tx.date.month == now.month && 
                  tx.date.year == now.year
                ).toList();

                if (filteredData.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pie_chart_outline, size: 80, color: Colors.grey.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text('Không có ${_currentType == 'income' ? 'thu nhập' : 'chi phí'} trong tháng ${now.month}', 
                          style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final Map<String, double> categorySums = {};
                double totalSum = 0;
                for (var tx in filteredData) {
                  categorySums[tx.category] = (categorySums[tx.category] ?? 0) + tx.amount;
                  totalSum += tx.amount;
                }

                final List<PieChartSectionData> sections = [];
                final categories = categorySums.keys.toList();
                
                for (int i = 0; i < categories.length; i++) {
                  final category = categories[i];
                  final amount = categorySums[category]!;
                  final percentage = (amount / totalSum) * 100;
                  final isTouched = i == touchedIndex;
                  final color = CategoryUtils.getVibrantColor(category);

                  sections.add(
                    PieChartSectionData(
                      color: color,
                      value: amount,
                      title: percentage > 8 ? '${percentage.toStringAsFixed(1)}%' : '',
                      radius: isTouched ? 65.0 : 55.0,
                      titleStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF000000) : Colors.white, width: 2),
                    ),
                  );
                }

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      // Donut Chart with Info in Center
                      SizedBox(
                        height: 250,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                              PieChartData(
                                pieTouchData: PieTouchData(
                                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                    setState(() {
                                      if (!event.isInterestedForInteractions ||
                                          pieTouchResponse == null ||
                                          pieTouchResponse.touchedSection == null) {
                                        touchedIndex = -1;
                                        return;
                                      }
                                      touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                    });
                                  },
                                ),
                                borderData: FlBorderData(show: false),
                                sectionsSpace: 0,
                                centerSpaceRadius: 75,
                                sections: sections,
                                startDegreeOffset: -90,
                              ),
                              swapAnimationDuration: const Duration(milliseconds: 600),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Tổng ${_currentType == 'income' ? 'thu' : 'chi'}',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  CurrencyUtils.formatCurrency(totalSum).replaceAll(' ₫', ''),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                Text(
                                  'VNĐ',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11, letterSpacing: 1),
                                ),
                              ],
                            ),
                          ],
                        ),
                       ),
                      ),
                      const SizedBox(height: 40),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: categories.asMap().entries.map((entry) {
                            final category = entry.value;
                            final amount = categorySums[category]!;
                            final percentage = amount / totalSum;
                            final color = CategoryUtils.getVibrantColor(category);
                            final icon = CategoryUtils.getCategoryIcon(category);
                            
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 16),
                              color: isDark ? const Color(0xFF1E2F2E).withOpacity(0.5) : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.transparent),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(15),
                                          ),
                                          child: Icon(icon, color: color, size: 22),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                category,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold, 
                                                  fontSize: 16,
                                                  color: isDark ? Colors.white : Colors.black87
                                                ),
                                              ),
                                              Text(
                                                '${(percentage * 100).toStringAsFixed(1)}%',
                                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          CurrencyUtils.formatCurrency(amount),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: color,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: percentage,
                                        backgroundColor: color.withOpacity(0.1),
                                        valueColor: AlwaysStoppedAnimation<Color>(color),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 30),
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

  Widget _buildToggleItem(String label, String type, bool isDark) {
    bool isSelected = _currentType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF438883) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ] : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

