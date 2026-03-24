import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import 'export_report_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late Stream<List<TransactionModel>> _transactionStream;

  int _selectedTimeIndex = 1;
  bool _isExpense = true;
  int _touchedIndex = -1;

  final List<String> _timeFilters = ['Ngay', 'Tuan', 'Thang', 'Nam'];

  @override
  void initState() {
    super.initState();
    _transactionStream = _firestoreService.getTransactionsStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // === APP BAR ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  const Text(
                    'Thong Ke',
                    style: TextStyle(color: Color(0xFF222222), fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.file_download_outlined, color: Color(0xFF222222), size: 24),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportReportScreen())),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // === TAB THOI GIAN ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_timeFilters.length, (index) {
                  bool isSelected = _selectedTimeIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedTimeIndex = index;
                      _touchedIndex = -1;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF438883) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _timeFilters[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF666666),
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 16),

            // === NUT CHUYEN CHI PHI / THU NHAP ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isExpense = !_isExpense;
                    _touchedIndex = -1;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isExpense ? 'Chi phi' : 'Thu nhap',
                          style: const TextStyle(color: Color(0xFF666666), fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.keyboard_arrow_down, color: Color(0xFF666666), size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // === BIEU DO + DANH SACH ===
            Expanded(
              child: StreamBuilder<List<TransactionModel>>(
                stream: _transactionStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                  }

                  final allTx = snapshot.data ?? [];
                  final filtered = allTx.where((tx) => _isExpense ? !tx.isIncome : tx.isIncome).toList();
                  final chartPoints = _buildChartData(filtered);
                  final total = filtered.fold<double>(0, (sum, tx) => sum + tx.amount);
                  final topList = _getTopSpending(filtered);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWaveChart(chartPoints, total),
                        const SizedBox(height: 30),
                        _buildTopSpendingSection(topList),
                        const SizedBox(height: 100),
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

  // ================================================================
  // BIEU DO SONG
  // ================================================================
  Widget _buildWaveChart(List<_ChartPoint> data, double total) {
    if (data.isEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text('Chua co du lieu', style: TextStyle(color: Color(0xFF999999)))),
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
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: 0,
          maxY: safeMaxY,

          // === LABELS TRUC X ===
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  final isSelected = idx == _touchedIndex;
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      data[idx].label,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF438883) : const Color(0xFFAAAAAA),
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // === TOOLTIP KHI CHAM ===
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => Colors.white,
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              tooltipBorder: BorderSide(color: const Color(0xFF438883).withOpacity(0.15), width: 1),
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  return LineTooltipItem(
                    _formatMoney(spot.y),
                    const TextStyle(color: Color(0xFF438883), fontWeight: FontWeight.w600, fontSize: 13),
                  );
                }).toList();
              },
            ),
            touchCallback: (event, response) {
              if (response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
                setState(() => _touchedIndex = response.lineBarSpots!.first.x.toInt());
              }
            },
            handleBuiltInTouches: true,
            // DUONG KE DOC DASHED KHI CHAM
            getTouchedSpotIndicator: (barData, spotIndexes) {
              return spotIndexes.map((index) {
                return TouchedSpotIndicatorData(
                  FlLine(
                    color: const Color(0xFF438883).withOpacity(0.3),
                    strokeWidth: 1.5,
                    dashArray: [5, 4],
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, idx) {
                      return FlDotCirclePainter(
                        radius: 6,
                        color: const Color(0xFF438883),
                        strokeWidth: 3,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                );
              }).toList();
            },
          ),

          // === DUONG BIEU DO ===
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
              isCurved: true,
              curveSmoothness: 0.35,
              preventCurveOverShooting: true,
              color: const Color(0xFF438883),
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF438883).withOpacity(0.25),
                    const Color(0xFF438883).withOpacity(0.08),
                    const Color(0xFF438883).withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      ),
    );
  }

  // ================================================================
  // PHAN CHI TIEU HANG DAU
  // ================================================================
  Widget _buildTopSpendingSection(List<TransactionModel> topList) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isExpense ? 'Chi Tieu Hang Dau' : 'Thu Nhap Hang Dau',
              style: const TextStyle(color: Color(0xFF222222), fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Icon(Icons.swap_vert, color: Color(0xFF666666)),
          ],
        ),
        const SizedBox(height: 16),

        if (topList.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: Text('Chua co du lieu', style: TextStyle(color: Color(0xFF999999), fontSize: 16))),
          )
        else
          ...topList.asMap().entries.map((entry) {
            final idx = entry.key;
            final tx = entry.value;
            final isHighlight = idx == 1 && topList.length > 1;
            return _buildSpendingItem(
              icon: tx.icon,
              title: tx.category,
              date: _formatSimpleDate(tx.date),
              amount: '${_isExpense ? "- " : "+ "}${_formatMoney(tx.amount)}',
              isHighlight: isHighlight,
            );
          }),
      ],
    );
  }

  Widget _buildSpendingItem({
    required IconData icon,
    required String title,
    required String date,
    required String amount,
    required bool isHighlight,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFF29756F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isHighlight
            ? [BoxShadow(color: const Color(0xFF29756F).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))]
            : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isHighlight ? Colors.white.withOpacity(0.15) : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: isHighlight ? Colors.white : const Color(0xFF555555), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isHighlight ? Colors.white : const Color(0xFF222222),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    color: isHighlight ? Colors.white.withOpacity(0.7) : const Color(0xFF999999),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: isHighlight ? Colors.white : (_isExpense ? const Color(0xFFF95B51) : const Color(0xFF24A869)),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // XU LY DU LIEU CHART
  // ================================================================
  List<_ChartPoint> _buildChartData(List<TransactionModel> transactions) {
    switch (_selectedTimeIndex) {
      case 0:
        return _groupByDay(transactions, 7);
      case 1:
        return _groupByWeek(transactions, 7);
      case 2:
        return _groupByMonth(transactions, 7);
      case 3:
        return _groupByYear(transactions, 6);
      default:
        return _groupByMonth(transactions, 7);
    }
  }

  List<_ChartPoint> _groupByDay(List<TransactionModel> txs, int count) {
    final now = DateTime.now();
    List<_ChartPoint> result = [];
    final dayNames = ['CN', 'Th2', 'Th3', 'Th4', 'Th5', 'Th6', 'Th7'];
    
    for (int i = count - 1; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final total = txs
          .where((tx) => tx.date.year == day.year && tx.date.month == day.month && tx.date.day == day.day)
          .fold<double>(0, (s, tx) => s + tx.amount);
      // weekday: 1=Monday, 7=Sunday => Convert to 0=Sunday, 1=Monday, ...
      final dayName = dayNames[day.weekday % 7];
      result.add(_ChartPoint(label: dayName, value: total));
    }
    return result;
  }

  List<_ChartPoint> _groupByWeek(List<TransactionModel> txs, int count) {
    final now = DateTime.now();
    List<_ChartPoint> result = [];
    for (int i = count - 1; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1 + (i * 7)));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final total = txs
          .where((tx) =>
              !tx.date.isBefore(DateTime(weekStart.year, weekStart.month, weekStart.day)) &&
              !tx.date.isAfter(DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59)))
          .fold<double>(0, (s, tx) => s + tx.amount);
      result.add(_ChartPoint(label: '${weekStart.day}T${weekStart.month}', value: total));
    }
    return result;
  }

  List<_ChartPoint> _groupByMonth(List<TransactionModel> txs, int count) {
    final now = DateTime.now();
    List<_ChartPoint> result = [];
    for (int i = count - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final total = txs
          .where((tx) => tx.date.year == month.year && tx.date.month == month.month)
          .fold<double>(0, (s, tx) => s + tx.amount);
      result.add(_ChartPoint(label: 'Th${month.month}', value: total));
    }
    return result;
  }

  List<_ChartPoint> _groupByYear(List<TransactionModel> txs, int count) {
    final now = DateTime.now();
    List<_ChartPoint> result = [];
    for (int i = count - 1; i >= 0; i--) {
      final year = now.year - i;
      final total = txs.where((tx) => tx.date.year == year).fold<double>(0, (s, tx) => s + tx.amount);
      result.add(_ChartPoint(label: '$year', value: total));
    }
    return result;
  }

  List<TransactionModel> _getTopSpending(List<TransactionModel> txs) {
    final sorted = List<TransactionModel>.from(txs);
    sorted.sort((a, b) => b.amount.compareTo(a.amount));
    return sorted.take(3).toList();
  }

  String _formatMoney(double amount) {
    String text = amount.toStringAsFixed(0);
    String result = '';
    int count = 0;
    for (int i = text.length - 1; i >= 0; i--) {
      count++;
      result = text[i] + result;
      if (count % 3 == 0 && i > 0) {
        result = '.$result';
      }
    }
    return '${result}d';
  }

  String _formatSimpleDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Hom nay';
    if (d == yesterday) return 'Hom qua';
    return 'Th${date.month} ${date.day}, ${date.year}';
  }
}

class _ChartPoint {
  final String label;
  final double value;
  _ChartPoint({required this.label, required this.value});
}