import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import '../../utils/page_transitions.dart';
import 'transaction_photo_detail_screen.dart';

class TransactionGalleryScreen extends StatefulWidget {
  const TransactionGalleryScreen({super.key});

  @override
  State<TransactionGalleryScreen> createState() => _TransactionGalleryScreenState();
}

class _TransactionGalleryScreenState extends State<TransactionGalleryScreen> {
  final FirestoreService _firestoreService = FirestoreService();

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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Gallery',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 48),
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
                  stream: _firestoreService.getTransactionsWithPhotosStream(),
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
                        for (final month in monthKeys) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
                              child: Text(
                                _monthLabel(month),
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color
                                      ?.withValues(alpha: 0.55),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1,
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
                            child: SizedBox(height: 18),
                          ),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
    // Yêu cầu: "Tháng 9 2025" (không cần tên tháng đầy đủ)
    return 'Tháng ${month.month} ${month.year}';
  }
}

class _GalleryEmptyState extends StatelessWidget {
  const _GalleryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 80,
            color: Colors.grey.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có ảnh nào',
            style: TextStyle(
              color: Colors.grey.withValues(alpha: 0.6),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
    final imageUrl = transaction.photoUrl;
    final heroTag = 'tx_photo_${transaction.id}';

    return Hero(
      tag: heroTag,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              cacheWidth: 520,
              filterQuality: FilterQuality.low,
              gaplessPlayback: true,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey.withValues(alpha: 0.08),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.withValues(alpha: 0.08),
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined, size: 28, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

