import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/receipt_storage_service.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../models/transaction_model.dart';
import '../../utils/currency_format_utils.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/animated_scale_button.dart';
import 'transaction_photo_detail_screen.dart';
import 'add_transaction_screen.dart';

class TransactionGalleryScreen extends StatefulWidget {
  const TransactionGalleryScreen({super.key});

  @override
  State<TransactionGalleryScreen> createState() => _TransactionGalleryScreenState();
}

class _TransactionGalleryScreenState extends State<TransactionGalleryScreen> {
  final TransactionRepository _txRepo = TransactionRepository();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Glassmorphism Header
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
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                    ),
                  ),
                  const Column(
                    children: [
                      Text(
                        'Thư viện hóa đơn',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Chứng từ thu chi đã lưu',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  AnimatedScaleButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        PageTransitions.slideUp(const AddTransactionScreen()),
                      );
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                      ),
                      child: const Icon(Icons.add_a_photo_rounded, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Body Sheet
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
                  stream: _txRepo.getTransactionsWithPhotosStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF438883)),
                      );
                    }

                    final photos = snapshot.data ?? [];
                    if (photos.isEmpty) {
                      return const _GalleryEmptyState();
                    }

                    photos.sort((a, b) {
                      final dateA = DateTime(a.date.year, a.date.month, a.date.day);
                      final dateB = DateTime(b.date.year, b.date.month, b.date.day);
                      final dayCompare = dateB.compareTo(dateA);
                      if (dayCompare != 0) return dayCompare;
                      return b.createdAt.compareTo(a.createdAt);
                    });

                    // Tính tổng tiền chi phí & thu nhập có hóa đơn
                    double totalExpense = 0;
                    double totalIncome = 0;
                    for (final p in photos) {
                      if (p.isIncome) {
                        totalIncome += p.amount;
                      } else {
                        totalExpense += p.amount;
                      }
                    }

                    final grouped = _groupByMonth(photos);
                    final monthKeys = grouped.keys.toList()
                      ..sort((a, b) {
                        final cmp = b.year.compareTo(a.year);
                        if (cmp != 0) return cmp;
                        return b.month.compareTo(a.month);
                      });

                    return CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // Tóm tắt Hero Gallery Card
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? [
                                          const Color(0xFF132C2A),
                                          const Color(0xFF0F2220),
                                        ]
                                      : [
                                          const Color(0xFFE8F5F3),
                                          const Color(0xFFD6EFEA),
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF235550)
                                      : const Color(0xFF438883).withValues(alpha: 0.2),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF438883).withValues(alpha: isDark ? 0.35 : 0.15),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long_rounded,
                                      color: Color(0xFF438883),
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${photos.length} hóa đơn đã lưu trữ',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : const Color(0xFF0F2625),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              'Chi: -${CurrencyUtils.formatCurrency(totalExpense)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFFEF4444),
                                              ),
                                            ),
                                            if (totalIncome > 0) ...[
                                              const SizedBox(width: 10),
                                              Text(
                                                'Thu: +${CurrencyUtils.formatCurrency(totalIncome)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF10B981),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Monthly sections
                        for (final month in monthKeys) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF438883),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _monthLabel(month),
                                        style: TextStyle(
                                          color: isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E293B),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.grey.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${grouped[month]!.length} ảnh',
                                      style: TextStyle(
                                        color: isDark ? Colors.white60 : Colors.grey.shade700,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.9,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final tx = grouped[month]![index];
                                  return _PhotoGridTile(
                                    transaction: tx,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.push(
                                        context,
                                        PageTransitions.slideRight(
                                          TransactionPhotoDetailScreen(transaction: tx),
                                        ),
                                      );
                                    },
                                  );
                                },
                                childCount: grouped[month]!.length,
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 12),
                          ),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 36)),
                      ],
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

  Map<DateTime, List<TransactionModel>> _groupByMonth(List<TransactionModel> txs) {
    final Map<DateTime, List<TransactionModel>> result = {};
    for (final tx in txs) {
      final monthKey = DateTime(tx.date.year, tx.date.month);
      result.putIfAbsent(monthKey, () => []);
      result[monthKey]!.add(tx);
    }
    return result;
  }

  String _monthLabel(DateTime month) {
    return 'Tháng ${month.month}, ${month.year}';
  }
}

class _GalleryEmptyState extends StatelessWidget {
  const _GalleryEmptyState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFF438883).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF438883).withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 54,
                color: Color(0xFF438883),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Chưa có hóa đơn nào',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Khi thêm khoản thu chi hoặc dùng Trợ lý Mono quét hóa đơn, ảnh chứng từ sẽ tự động lưu trữ tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey.shade600,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            AnimatedScaleButton(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  PageTransitions.slideUp(const AddTransactionScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF438883), Color(0xFF2F6360)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF438883).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt_rounded, size: 20, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Chụp hóa đơn mới',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoGridTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onTap;

  const _PhotoGridTile({
    required this.transaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final heroTag = 'tx_photo_${transaction.id}';
    final isIncome = transaction.isIncome;
    final statusColor = isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Hero(
      tag: heroTag,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: Colors.black12,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Ảnh hóa đơn
                  ReceiptStorageService.buildReceiptImage(
                    photoLocalPath: transaction.photoLocalPath,
                    photoUrl: transaction.photoUrl,
                    fit: BoxFit.cover,
                  ),

                  // Lớp phủ gradient ở đáy
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.88),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // Huy hiệu số tiền ở góc dưới
                  Positioned(
                    bottom: 6,
                    left: 6,
                    right: 6,
                    child: Text(
                      '${isIncome ? '+' : '-'}${CurrencyUtils.formatCurrency(transaction.amount)}',
                      style: TextStyle(
                        color: isIncome ? const Color(0xFF34D399) : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        shadows: [
                          Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 4),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Huy hiệu danh mục ở góc trên trái
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: Icon(transaction.icon, size: 12, color: statusColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
