import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/transaction_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/currency_format_utils.dart';
import '../../utils/category_utils.dart';
import '../../widgets/animated_scale_button.dart';

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
    final headerColor = isDark ? const Color(0xFF0F2625) : const Color(0xFF438883);

    return Scaffold(
      backgroundColor: headerColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. TOP APP BAR FINTECH GLASSMORPHISM
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedScaleButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                    ),
                  ),
                  const Text(
                    'Thống Kê Danh Mục',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 42),
                ],
              ),
            ),

            // 2. LIQUID SEGMENTED SWITCHER (CHI PHÍ VS THU NHẬP)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSegmentButton(
                        label: 'Khoản Chi',
                        type: 'expense',
                        icon: Icons.trending_down_rounded,
                        activeColor: const Color(0xFFEF4444),
                      ),
                    ),
                    Expanded(
                      child: _buildSegmentButton(
                        label: 'Khoản Thu',
                        type: 'income',
                        icon: Icons.trending_up_rounded,
                        activeColor: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. MAIN CONTENT SHEET
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
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
                            Icon(Icons.pie_chart_outline_rounded, size: 70, color: Colors.grey.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text(
                              'Không có ${_currentType == 'income' ? 'khoản thu' : 'khoản chi'} nào trong tháng ${now.month}',
                              style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
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
                    final categories = categorySums.keys.toList()
                      ..sort((a, b) => categorySums[b]!.compareTo(categorySums[a]!));

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
                          title: percentage > 7 ? '${percentage.toStringAsFixed(0)}%' : '',
                          radius: isTouched ? 65.0 : 54.0,
                          titleStyle: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF1E2827) : Colors.white,
                            width: 2,
                          ),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      child: Column(
                        children: [
                          // Thẻ biểu đồ Donut Chart trung tâm
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2827) : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: SizedBox(
                              height: 230,
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
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 72,
                                      sections: sections,
                                      startDegreeOffset: -90,
                                    ),
                                    duration: const Duration(milliseconds: 400),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Tổng ${_currentType == 'income' ? 'thu' : 'chi'}',
                                        style: TextStyle(
                                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        CurrencyUtils.formatCurrency(totalSum).replaceAll(' ₫', ''),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 20,
                                          color: _currentType == 'income'
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFEF4444),
                                        ),
                                      ),
                                      Text(
                                        'VNĐ',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Header danh sách phân loại
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Chi tiết theo danh mục',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                '${categories.length} danh mục',
                                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Danh sách thẻ chi tiết từng danh mục
                          ...categories.map((category) {
                            final amount = categorySums[category]!;
                            final percentage = (amount / totalSum) * 100;
                            final color = CategoryUtils.getVibrantColor(category);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E2827) : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          CategoryUtils.getCategoryIcon(category),
                                          color: color,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              category,
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              CurrencyUtils.formatCurrency(amount),
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white70 : Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${percentage.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: (percentage / 100).clamp(0.0, 1.0),
                                      minHeight: 6,
                                      backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                      valueColor: AlwaysStoppedAnimation<Color>(color),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
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

  Widget _buildSegmentButton({
    required String label,
    required String type,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _currentType == type;

    return AnimatedScaleButton(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _currentType = type;
          touchedIndex = -1;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF1E293B) : Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
