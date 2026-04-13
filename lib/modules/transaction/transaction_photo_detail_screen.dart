import 'package:flutter/material.dart';

import '../../models/transaction_model.dart';
import '../../utils/currency_format_utils.dart';

class TransactionPhotoDetailScreen extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionPhotoDetailScreen({
    super.key,
    required this.transaction,
  });

  String _formatDate(DateTime date) {
    // Dùng formatter hiện có để đồng bộ UI
    return CurrencyUtils.formatDate(date);
  }

  String _formatCreatedAt(DateTime createdAt) {
    final date = _formatDate(createdAt);
    final hh = createdAt.hour.toString().padLeft(2, '0');
    final mm = createdAt.minute.toString().padLeft(2, '0');
    return '$date $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = transaction.photoUrl;
    final heroTag = 'tx_photo_${transaction.id}';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            // Nền cuộn nội dung
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      children: [
                        // Ảnh full (gần full màn hình)
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.66,
                          child: Hero(
                            tag: heroTag,
                            child: InteractiveViewer(
                              minScale: 1.0,
                              maxScale: 3.2,
                              child: ClipRect(
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.low,
                                  cacheWidth: 1600,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.white70,
                                        size: 46,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                          child: _InfoCard(
                            transaction: transaction,
                            createdAtText: _formatCreatedAt(transaction.createdAt),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // App bar overlay
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () {
                      // Có thể mở menu trong tương lai (chia sẻ, xóa ảnh, ...)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tính năng đang phát triển')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final TransactionModel transaction;
  final String createdAtText;

  const _InfoCard({
    required this.transaction,
    required this.createdAtText,
  });

  @override
  Widget build(BuildContext context) {
    final amountText = CurrencyUtils.formatAmountWithSign(transaction.amount, transaction.isIncome);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            amountText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          _buildRow('Ghi chú', transaction.description.isEmpty ? 'Không có ghi chú' : transaction.description),
          const SizedBox(height: 10),
          _buildRow('Ngày tạo', createdAtText),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    transaction.icon,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    transaction.category.isEmpty ? 'Chưa có danh mục' : transaction.category,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

