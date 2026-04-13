import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/voice_service.dart';
import '../services/firestore_service.dart';
import '../utils/category_utils.dart';
import '../utils/page_transitions.dart';
import '../modules/transaction/add_transaction_screen.dart';
import 'voice_waveform.dart';

class VoiceInputBottomSheet extends StatefulWidget {
  const VoiceInputBottomSheet({super.key});

  @override
  State<VoiceInputBottomSheet> createState() => _VoiceInputBottomSheetState();
}

class _VoiceInputBottomSheetState extends State<VoiceInputBottomSheet> {
  final VoiceService _voiceService = VoiceService();
  final FirestoreService _firestoreService = FirestoreService();
  
  String _recognizedText = "Đang nghe...";
  bool _isListening = false;
  double _soundLevel = 0;
  Map<String, dynamic>? _parsedData;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _voiceService.stopListening();
    super.dispose();
  }

  void _startListening() async {
    if (!mounted) return;
    setState(() {
      _isListening = true;
      _recognizedText = "Hãy nói nội dung chi tiêu (VD: Bún bò ba mươi lăm ngàn)";
    });

    await _voiceService.startListening(
      onResult: (text) {
        if (mounted) {
          setState(() {
            _recognizedText = text;
          });
        }
      },
      onSoundLevelChange: (level) {
        if (mounted) {
          setState(() {
            _soundLevel = level;
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isListening = false;
            _processText(_recognizedText);
          });
        }
      },
    );
  }

  void _processText(String text) {
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
      _parsedData = _voiceService.parseVoiceCommand(text);
      
      // Smart Icon Matching
      if (_parsedData != null) {
        final categoryName = _parsedData!['category'];
        final Map<String, int> categoryIcons = {
          'Ăn uống': Icons.restaurant_rounded.codePoint,
          'Sức khỏe': Icons.medical_services_rounded.codePoint,
          'Di chuyển': Icons.directions_car_rounded.codePoint,
          'Học tập': Icons.school_rounded.codePoint,
          'Giải trí': Icons.movie_rounded.codePoint,
          'Du lịch': Icons.flight_rounded.codePoint,
          'Mua sắm': Icons.shopping_bag_rounded.codePoint,
          'Tiền điện': Icons.bolt_rounded.codePoint,
          'Quà tặng': Icons.redeem_rounded.codePoint,
          'Tiền lương': Icons.account_balance_wallet_rounded.codePoint,
          'Tiền thưởng': Icons.card_giftcard_rounded.codePoint,
          'Kinh doanh': Icons.business_center_rounded.codePoint,
        };
        _parsedData!['iconCode'] = categoryIcons[categoryName] ?? Icons.category_rounded.codePoint;
      }
      
      _isProcessing = false;
    });
  }

  void _confirmSelection() {
    if (_parsedData == null) return;
    
    // Đóng Bottom Sheet hiện tại và mở Màn hình Add Transaction với dữ liệu đã được parse
    Navigator.pop(context); // Đóng bottom sheet
    Navigator.push(
      context,
      PageTransitions.slideUp(AddTransactionScreen(initialData: _parsedData)),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1B2C2B), // Dark Moss Green Background
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          // Waveform
          VoiceWaveform(
            isListening: _isListening,
            currentLevel: _soundLevel,
          ),
          
          const SizedBox(height: 20),
          
          // Recognized text area
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              _recognizedText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16,
                fontStyle: _recognizedText.contains("...") ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Parsed Results Preview
          if (_parsedData != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF438883).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF438883).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: CategoryUtils.getVibrantColor(_parsedData!['category']),
                    child: const Icon(Icons.check, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_parsedData!['type'] == 'income' ? "Khoản thu" : "Khoản chi"} • ${_parsedData!['category']}',
                          style: TextStyle(
                            color: _parsedData!['type'] == 'income' ? Colors.greenAccent : Colors.orangeAccent, 
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(_parsedData!['amount']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _confirmSelection,
                    child: const Text("Chỉnh sửa", style: TextStyle(color: Color(0xFF438883))),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("Hủy"),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isListening 
                      ? () => _voiceService.stopListening() 
                      : (_parsedData != null ? _confirmSelection : null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF438883),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(_isListening ? "Dừng" : "Tiếp tục"),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
