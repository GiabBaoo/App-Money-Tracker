import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/transaction_model.dart';
import '../../services/receipt_storage_service.dart';
import '../../utils/currency_format_utils.dart';
import '../../utils/category_utils.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/animated_scale_button.dart';
import 'transaction_detail_screen.dart';
import 'edit_transaction_screen.dart';

class TransactionPhotoDetailScreen extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionPhotoDetailScreen({
    super.key,
    required this.transaction,
  });

  @override
  State<TransactionPhotoDetailScreen> createState() => _TransactionPhotoDetailScreenState();
}

class _TransactionPhotoDetailScreenState extends State<TransactionPhotoDetailScreen> {
  final TransformationController _transformController = TransformationController();
  int _quarterTurns = 0;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(() {
      final isNowZoomed = !_transformController.value.isIdentity();
      if (isNowZoomed != _isZoomed && mounted) {
        setState(() => _isZoomed = isNowZoomed);
      }
    });
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_transformController.value.isIdentity()) {
        _transformController.value = Matrix4.diagonal3Values(2.5, 2.5, 1.0);
      } else {
        _transformController.value = Matrix4.identity();
      }
    });
  }

  void _rotateClockwise() {
    HapticFeedback.lightImpact();
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
    });
  }

  void _resetView() {
    HapticFeedback.lightImpact();
    setState(() {
      _quarterTurns = 0;
      _transformController.value = Matrix4.identity();
    });
  }

  String _formatCreatedAt(DateTime createdAt) {
    final date = CurrencyUtils.formatDate(createdAt);
    final hh = createdAt.hour.toString().padLeft(2, '0');
    final mm = createdAt.minute.toString().padLeft(2, '0');
    return '$date $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final heroTag = 'tx_photo_${widget.transaction.id}';
    final isIncome = widget.transaction.isIncome;
    final categoryColor = CategoryUtils.getVibrantColor(widget.transaction.category);

    return Scaffold(
      backgroundColor: const Color(0xFF090D0D),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            // 1. VÙNG XEM ẢNH TƯƠNG TÁC (SCROLL & PINCH-TO-ZOOM)
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 88, bottom: 120),
                    child: Column(
                      children: [
                        // Vùng ảnh InteractiveViewer
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.58,
                          child: GestureDetector(
                            onDoubleTap: _handleDoubleTap,
                            child: Hero(
                              tag: heroTag,
                              child: InteractiveViewer(
                                transformationController: _transformController,
                                minScale: 0.8,
                                maxScale: 5.0,
                                clipBehavior: Clip.none,
                                child: Center(
                                  child: RotatedBox(
                                    quarterTurns: _quarterTurns,
                                    child: ReceiptStorageService.buildReceiptImage(
                                      photoLocalPath: widget.transaction.photoLocalPath,
                                      photoUrl: widget.transaction.photoUrl,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Gợi ý cử chỉ tương tác
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.touch_app_rounded, color: Colors.white60, size: 14),
                                    SizedBox(width: 6),
                                    Text(
                                      'Chạm 2 lần để phóng to • Kéo để thu phóng',
                                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Thẻ thông tin giao dịch tóm tắt phong cách E-Receipt FinTech
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                          child: _TransactionInfoGlassCard(
                            transaction: widget.transaction,
                            createdAtText: _formatCreatedAt(widget.transaction.createdAt),
                            isIncome: isIncome,
                            categoryColor: categoryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // 2. THANH CÔNG CỤ NỔI KÍNH MỜ (FLOATING APP BAR)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 12,
                  left: 16,
                  right: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.black.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Nút Back
                    AnimatedScaleButton(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      ),
                    ),

                    // Tiêu đề
                    const Text(
                      'Chi tiết hóa đơn',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),

                    // Dãy nút thao tác nhanh
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Nút Xoay 90 độ
                        AnimatedScaleButton(
                          onTap: _rotateClockwise,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24, width: 0.8),
                            ),
                            child: const Icon(Icons.rotate_right_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                        if (_quarterTurns != 0 || _isZoomed) ...[
                          const SizedBox(width: 8),
                          // Nút Reset góc nhìn
                          AnimatedScaleButton(
                            onTap: _resetView,
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFF438883).withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF5EEAD4), width: 0.8),
                              ),
                              child: const Icon(Icons.restart_alt_rounded, color: Color(0xFF5EEAD4), size: 20),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 3. ERGONOMIC FLOATING BOTTOM ACTION DOCK (THUMB ZONE)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D1C).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Nút Chỉnh sửa giao dịch
                    Expanded(
                      child: AnimatedScaleButton(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            PageTransitions.slideUp(
                              EditTransactionScreen(transaction: widget.transaction),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_note_rounded, color: Colors.white70, size: 20),
                              SizedBox(width: 6),
                              Text(
                                'Chỉnh sửa',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Nút Xem chi tiết giao dịch
                    Expanded(
                      child: AnimatedScaleButton(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            PageTransitions.slideRight(
                              TransactionDetailScreen(transaction: widget.transaction),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF438883), Color(0xFF2F6360)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF438883).withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Chi tiết GD',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
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

class _TransactionInfoGlassCard extends StatelessWidget {
  final TransactionModel transaction;
  final String createdAtText;
  final bool isIncome;
  final Color categoryColor;

  const _TransactionInfoGlassCard({
    required this.transaction,
    required this.createdAtText,
    required this.isIncome,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final amountText = CurrencyUtils.formatAmountWithSign(transaction.amount, isIncome);
    final statusColor = isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131D1C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Số tiền và loại thu/chi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  amountText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  isIncome ? 'KHOẢN THU' : 'KHOẢN CHI',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),

          // Danh mục giao dịch
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(transaction.icon, color: categoryColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.category.isEmpty ? 'Chưa có danh mục' : transaction.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (transaction.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        transaction.description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Thời gian ghi nhận
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_outlined, color: Colors.white54, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Ngày giao dịch',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                  ),
                ],
              ),
              Text(
                '${CurrencyUtils.formatDate(transaction.date)} • ${transaction.time}',
                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
