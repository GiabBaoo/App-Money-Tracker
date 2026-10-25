import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/theme/app_theme.dart';
import '../../models/transaction_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/currency_format_utils.dart';
import '../../utils/category_utils.dart';
import '../../widgets/animated_scale_button.dart';
import '../../services/category_style_service.dart';
import '../../services/language_service.dart';

class CategoryStatisticsScreen extends StatefulWidget {
  final String type; // 'income' or 'expense'

  const CategoryStatisticsScreen({super.key, required this.type});

  @override
  State<CategoryStatisticsScreen> createState() =>
      _CategoryStatisticsScreenState();
}

class _CategoryStatisticsScreenState extends State<CategoryStatisticsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late String _currentType;
  int touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _currentType = widget.type;
    CategoryStyleService.instance.addListener(_onCategoryStyleChanged);
  }

  void _onCategoryStyleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CategoryStyleService.instance.removeListener(_onCategoryStyleChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.isDark;
    final headerColor = isDark
        ? AppColors.primaryTealDark
        : AppColors.primaryTeal;
    final isVi = LanguageScope.of(context).isVietnamese;

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
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      isVi ? 'Thống Kê Danh Mục' : 'Category Statistics',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          context.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ) ??
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
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
                  borderRadius: AppRadius.card,
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSegmentButton(
                        label: isVi ? 'Khoản Chi' : 'Expense',
                        type: 'expense',
                        icon: Icons.trending_down_rounded,
                        activeColor: context.expenseColor,
                      ),
                    ),
                    Expanded(
                      child: _buildSegmentButton(
                        label: isVi ? 'Khoản Thu' : 'Income',
                        type: 'income',
                        icon: Icons.trending_up_rounded,
                        activeColor: context.incomeColor,
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
                  color: context.colors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.3 : 0.08,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: StreamBuilder<List<TransactionModel>>(
                  stream: _firestoreService.getTransactionsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: context.colors.primary,
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Text(
                          isVi
                              ? 'Chưa có dữ liệu giao dịch'
                              : 'No transaction data yet',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.textMutedColor,
                          ),
                        ),
                      );
                    }

                    final now = DateTime.now();
                    final filteredData = snapshot.data!
                        .where(
                          (tx) =>
                              tx.type == _currentType &&
                              tx.date.month == now.month &&
                              tx.date.year == now.year,
                        )
                        .toList();

                    if (filteredData.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.pie_chart_outline_rounded,
                              size: 70,
                              color: context.textMutedColor.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isVi
                                  ? 'Không có ${_currentType == 'income' ? 'khoản thu' : 'khoản chi'} nào trong tháng ${now.month}'
                                  : 'No ${_currentType == 'income' ? 'income' : 'expense'} recorded in month ${now.month}',
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: context.textMutedColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final Map<String, double> categorySums = {};
                    final Map<String, int> storedIconCodes = {};
                    double totalSum = 0;
                    for (var tx in filteredData) {
                      categorySums[tx.category] =
                          (categorySums[tx.category] ?? 0) + tx.amount;
                      storedIconCodes.putIfAbsent(
                        tx.category,
                        () => tx.categoryIconCode,
                      );
                      totalSum += tx.amount;
                    }

                    final List<PieChartSectionData> sections = [];
                    final categories = categorySums.keys.toList()
                      ..sort(
                        (a, b) => categorySums[b]!.compareTo(categorySums[a]!),
                      );

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
                          title: percentage > 7
                              ? '${percentage.toStringAsFixed(0)}%'
                              : '',
                          radius: isTouched ? 65.0 : 54.0,
                          titleStyle: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          borderSide: BorderSide(
                            color: context.cardBg,
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
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: context.cardBg,
                              borderRadius: AppRadius.card,
                              border: Border.all(color: context.borderColor),
                              boxShadow: AppShadows.card(isDark),
                            ),
                            child: SizedBox(
                              height: 230,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  PieChart(
                                    PieChartData(
                                      pieTouchData: PieTouchData(
                                        touchCallback:
                                            (
                                              FlTouchEvent event,
                                              pieTouchResponse,
                                            ) {
                                              setState(() {
                                                if (!event
                                                        .isInterestedForInteractions ||
                                                    pieTouchResponse == null ||
                                                    pieTouchResponse
                                                            .touchedSection ==
                                                        null) {
                                                  touchedIndex = -1;
                                                  return;
                                                }
                                                touchedIndex = pieTouchResponse
                                                    .touchedSection!
                                                    .touchedSectionIndex;
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
                                        isVi
                                            ? 'Tổng ${_currentType == 'income' ? 'thu' : 'chi'}'
                                            : 'Total ${_currentType == 'income' ? 'Income' : 'Expense'}',
                                        style: context.textTheme.bodySmall
                                            ?.copyWith(
                                              color: context.textSecondaryColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        CurrencyUtils.formatCurrency(
                                          totalSum,
                                        ).replaceAll(' ₫', ''),
                                        style: context.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 20,
                                              color: _currentType == 'income'
                                                  ? context.incomeColor
                                                  : context.expenseColor,
                                            ),
                                      ),
                                      Text(
                                        'VND',
                                        style: context.textTheme.labelSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: context.textMutedColor,
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
                              Text(
                                isVi
                                    ? 'Chi tiết theo danh mục'
                                    : 'Category breakdown',
                                style: context.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                isVi
                                    ? '${categories.length} danh mục'
                                    : '${categories.length} categories',
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: context.textMutedColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Danh sách thẻ chi tiết từng danh mục
                          ...categories.map((category) {
                            final amount = categorySums[category]!;
                            final percentage = (amount / totalSum) * 100;
                            final color = CategoryUtils.getVibrantColor(
                              category,
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: context.cardBg,
                                borderRadius: AppRadius.card,
                                border: Border.all(color: context.borderColor),
                                boxShadow: AppShadows.card(isDark),
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          CategoryUtils.getCategoryIcon(
                                            category,
                                            fallbackCode:
                                                storedIconCodes[category],
                                          ),
                                          color: color,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              context.trCat(category),
                                              style: context
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    color: context
                                                        .textPrimaryColor,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              CurrencyUtils.formatCurrency(
                                                amount,
                                              ),
                                              style: context.textTheme.bodySmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: context
                                                        .textSecondaryColor,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withValues(
                                            alpha: isDark ? 0.25 : 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                      backgroundColor: isDark
                                          ? context.colors.surface.withValues(
                                              alpha: 0.3,
                                            )
                                          : AppColors.inputBgLight,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        color,
                                      ),
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
          color: isSelected
              ? (context.isDark ? context.cardBg : Colors.white)
              : Colors.transparent,
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
              style:
                  context.textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? context.textPrimaryColor
                        : Colors.white70,
                    fontWeight: FontWeight.w700,
                  ) ??
                  TextStyle(
                    color: isSelected
                        ? context.textPrimaryColor
                        : Colors.white70,
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
