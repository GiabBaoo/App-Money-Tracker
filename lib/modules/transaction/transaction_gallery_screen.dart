import 'package:flutter/material.dart';

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedScaleButton(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                    ),
                  ),
                  const Text(
                    'Thư viện hóa đơn',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  AnimatedScaleButton(
                    onTap: () {
                      Navigator.push(
                        context,
                        PageTransitions.slideUp(const AddTransactionScreen()),
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: const Icon(Icons.add_a_photo_rounded, size: 19, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
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
                        // Header tóm tắt tổng số hóa đơn
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF438883).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.photo_library_rounded, size: 16, color: Color(0xFF438883)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${photos.length} hóa đơn đã lưu',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        for (final month in monthKeys) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
                              child: Text(
                                _monthLabel(month),
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color
                                      ?.withValues(alpha: 0.55),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.92,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final tx = grouped[month]![index];
                                  return _PhotoGridTile(
                                    transaction: tx,
                                    onTap: () {
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
                            child: SizedBox(height: 14),
                          ),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
    return 'Tháng ${month.month} năm ${month.year}';
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
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF438883).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 48,
                color: Color(0xFF438883),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Chưa có hóa đơn nào',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Khi thêm khoản thu chi hoặc dùng Trợ lý Mono chụp hóa đơn, ảnh sẽ tự động lưu vào đây.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey.shade600,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF438883),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 0,
              ),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text(
                'Chụp hóa đơn mới',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  PageTransitions.slideUp(const AddTransactionScreen()),
                );
              },
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
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
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      shadows: [
                        Shadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 4),
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
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(transaction.icon, size: 12, color: statusColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
