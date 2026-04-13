import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;

  Future<bool> init() async {
    if (_isInitialized) return true;
    _isInitialized = await _speechToText.initialize(
      onError: (e) => debugPrint('Speech Error: $e'),
      onStatus: (s) => debugPrint('Speech Status: $s'),
    );
    return _isInitialized;
  }

  bool get isListening => _speechToText.isListening;

  Future<void> startListening({
    required Function(String) onResult,
    required Function(double) onSoundLevelChange,
    required VoidCallback onDone,
  }) async {
    final ready = await init();
    if (!ready) return;

    await _speechToText.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords);
        if (result.finalResult) {
          onDone();
        }
      },
      onSoundLevelChange: onSoundLevelChange,
      localeId: 'vi_VN',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
  }

  /// Advanced parsing logic for Vietnamese
  Map<String, dynamic>? parseVoiceCommand(String text) {
    if (text.isEmpty) return null;
    
    String cleanText = text.toLowerCase().trim()
        .replaceAll(',', '')
        .replaceAll('.', '')
        .replaceAll('  ', ' ');
        
    int? parsedHour;
    int? parsedMinute;
    
    // Tìm thời gian (VD: "8h sáng", "8 giờ 30", "20h")
    final timeReg = RegExp(r'\b(\d{1,2})\s*(h|giờ|g|:)\s*(\d{1,2})?\s*(sáng|trưa|chiều|tối|đêm)?\b');
    final timeMatch = timeReg.firstMatch(cleanText);
    if (timeMatch != null) {
      parsedHour = int.tryParse(timeMatch.group(1)!);
      parsedMinute = timeMatch.group(3) != null ? int.tryParse(timeMatch.group(3)!) : 0;
      final session = timeMatch.group(4);
      
      if (parsedHour != null) {
        if (session == 'chiều' || session == 'tối' || session == 'đêm') {
          if (parsedHour < 12) parsedHour += 12;
        } else if (session == 'sáng' && parsedHour == 12) {
          parsedHour = 0;
        }
      }
      // Xóa thời gian khỏi text để không lấy nhầm vào số tiền
      cleanText = cleanText.replaceFirst(timeMatch.group(0)!, ' ');
    }
    
    // 1. Try to extract amount from digits first
    final RegExp numReg = RegExp(r'(\d+)');
    final matches = numReg.allMatches(cleanText).toList();
    double amount = 0;
    
    if (matches.isNotEmpty) {
      // Tìm số thực tế là số tiền: Ưu tiên số lớn nhất
      int bestMatchIndex = 0;
      double maxNum = 0;
      for (int i = 0; i < matches.length; i++) {
        double temp = double.tryParse(matches[i].group(1)!) ?? 0;
        if (temp > maxNum) {
           maxNum = temp;
           bestMatchIndex = i;
        }
      }
      
      amount = maxNum;
      String textAfterFirstNum = cleanText.substring(matches[bestMatchIndex].end).trimLeft();
      
      // Handle "ngàn", "triệu" that come after the number
      if (textAfterFirstNum.startsWith('nghìn') || textAfterFirstNum.startsWith('ngàn') || textAfterFirstNum.startsWith('k')) {
        if (!textAfterFirstNum.contains('triệu')) {
           // Nếu số < 1000 thì nhân thêm 1000 (Ví dụ: "100 k" -> 100,000)
           if (amount < 1000) amount *= 1000;
        }
      }
      if (textAfterFirstNum.startsWith('triệu') || textAfterFirstNum.startsWith('tr')) {
        amount *= 1000000;
      }
      // Handle "rưỡi" (e.g. 1 triệu rưỡi -> 1.500.000)
      if (textAfterFirstNum.contains('rưỡi')) {
          if (textAfterFirstNum.contains('triệu')) {
            amount += 500000;
          } else if (textAfterFirstNum.contains('ngàn') || textAfterFirstNum.contains('nghìn')) {
            amount += 500;
          }
      }
    } else {
      // 2. Try to parse Vietnamese text numbers
      amount = _parseVietnameseNumber(cleanText);
    }

    if (amount <= 0) return null;

    // 3. Match Category
    String category = 'Chi khác';
    String type = 'expense';
    
    final categoriesMap = {
      // INCOME CATEGORIES (Ưu tiên Lên Đầu)
      'Tiền lương': ['lương', 'salary', 'nhận lương', 'lãnh lương', 'ting ting lương', 'phát lương', 'tiền công', 'trả công'],
      'Tiền thưởng': ['thưởng', 'bonus', 'khoản thu', 'khoảng thu', 'hoa hồng', 'tiền bo', 'tip', 'kpi'],
      'Tiền thuê nhà': ['tiền thuê nhà', 'thuê nhà', 'thu tiền nhà', 'nhận tiền thuê nhà', 'tiền trọ', 'thu tiền trọ'],
      'Được cho/Tặng': ['lì xì', 'mẹ cho', 'bố cho', 'cho tiền', 'được cho', 'nhận được', 'cho tôi', 'tặng', 'mẹ tôi cho', 'bố tôi cho', 'biếu', 'tài trợ', 'nhận tiền'],
      'Bán đồ': ['bán hàng', 'bán', 'lời', 'lãi', 'thu được', 'thanh lý', 'sang nhượng', 'đẩy đi', 'pass lại'],
      'Kinh doanh': ['kinh doanh', 'lợi nhuận', 'doanh thu', 'đầu tư', 'tiền lãi', 'cổ tức', 'nhận tiền nhà', 'cho thuê'],
      'Thu khác': ['trúng số', 'nhặt được', 'tiền rớt', 'quỹ đen', 'bồi thường'],

      // SPECIFIC EXPENSE CATEGORIES (Ưu tiên match trước các từ khóa chung chung như "mua")
      'Tiền nhà': ['thuê nhà', 'tiền nhà', 'trọ', 'nhà trọ', 'chung cư', 'quản lý phí'],
      'Tiền điện': ['điện', 'tiền điện', 'evn', 'nước', 'tiền nước', 'internet', 'wifi', 'cáp quang', 'tiền mạng', 'cước viễn thông'],
      'Điện thoại': ['điện thoại', 'nạp card', 'thẻ cào', 'thẻ viettel', 'thẻ mobi', 'thẻ vina', 'cước điện thoại', 'cước trả trước', 'cước trả sau', 'nạp thẻ', 'nạp tiền điện thoại'],
      'Sức khỏe': ['thuốc', 'khám', 'bệnh', 'nha khoa', 'vitamin', 'bệnh viện', 'phòng khám', 'xét nghiệm', 'bảo hiểm y tế', 'viện phí', 'tiêm phòng', 'băng cá nhân', 'y tế'],
      'Học tập': ['học', 'sách', 'vở', 'khóa học', 'bút', 'giáo trình', 'học phí', 'thi lại', 'hành trang', 'kỹ năng', 'toeic', 'ielts', 'tiếng anh'],
      'Thể thao': ['thể thao', 'gym', 'bơi', 'đá bóng', 'cầu lông', 'chạy', 'tennis', 'yoga', 'đạp xe', 'vợt', 'giày chạy', 'thuê sân', 'bóng đá', 'billard', 'bi a', 'bida'],
      'Di chuyển': ['xăng', 'xe', 'bus', 'grab', 'be', 'taxi', 'vé máy bay', 'tàu', 'gửi xe', 'bến', 'bơm xe', 'thay nhớt', 'rửa xe', 'vé xe', 'thu phí', 'bot', 'bảo dưỡng'],
      'Giải trí': ['phim', 'nhạc', 'game', 'karaoke', 'xem phim', 'netflix', 'spotify', 'gacha', 'nạp game', 'vé concert', 'nhạc hội', 'đi lượn', 'chơi'],
      'Du lịch': ['du lịch', 'khách sạn', 'homestay', 'resort', 'máy bay', 'phòng', 'vé tham quan', 'tour', 'visa', 'đặt phòng', 'villas'],
      'Quà tặng': ['quà', 'biếu', 'mừng', 'sinh nhật', 'lễ', 'đám cưới', 'chu cấp', 'thăm hỏi', 'phúng điếu', 'ma chay', 'thôi nôi', 'đầy tháng', 'tặng bạn', 'tặng người yêu', 'lì xì'],
      'Tiết kiệm': ['tiết kiệm', 'bỏ ống heo', 'đút lợn', 'gửi ngân hàng', 'nuôi heo'],
      'Thú cưng': ['thú cưng', 'chó mèo', 'thức ăn chó mèo', 'pate', 'cát vệ sinh', 'cám chó', 'cám mèo', 'thú y'],
      'Từ thiện': ['từ thiện', 'quyên góp', 'ủng hộ', 'cúng dường', 'nhang đèn', 'đi chùa'],
      'Bảo hiểm': ['bảo hiểm nhân thọ', 'bảo hiểm xe', 'đóng bảo hiểm'],
      'Con cái': ['bỉm', 'sữa', 'đồ chơi', 'học phí cho con', 'nuôi con'],
      'Làm đẹp': ['spa', 'cắt tóc', 'gội đầu', 'làm móng', 'nail', 'skincare', 'makeup', 'nối mi', 'massage', 'làm đẹp'],

      // BROAD EXPENSE CATEGORIES (Match cuối cùng để tránh cướp keyword của mục khác)
      'Ăn uống': ['ăn', 'uống', 'cafe', 'phở', 'bún', 'cơm', 'trà', 'nhậu', 'tiệc', 'bánh', 'mì', 'phê', 'sinh tố', 'trà sữa', 'ốc', 'nhà hàng', 'xôi', 'chè', 'đồ ăn', 'đồ uống', 'nước ép', 'bia', 'pizza', 'gà rán', 'hamburger', 'trái cây'],
      'Mua sắm': ['mua', 'shopee', 'lazada', 'quần', 'áo', 'giày', 'dép', 'túi', 'siêu thị', 'đồ dùng', 'mỹ phẩm', 'tiki', 'tiktok shop', 'váy', 'son', 'kem chống nắng', 'sắm'],
    };

    int maxKeywordLength = -1;
    for (var entry in categoriesMap.entries) {
      for (var keyword in entry.value) {
        if (cleanText.contains(keyword)) {
          if (keyword.length > maxKeywordLength) {
            category = entry.key;
            maxKeywordLength = keyword.length;
          }
        }
      }
    }

    // Determine type (income or expense)
    if (['Tiền lương', 'Tiền thưởng', 'Tiền thuê nhà', 'Kinh doanh', 'Được cho/Tặng', 'Bán đồ', 'Thu khác'].contains(category) || 
        cleanText.contains('nhận được') || cleanText.contains('thu nhập') || 
        cleanText.contains('được cho') || cleanText.contains('mẹ cho') || 
        cleanText.contains('bố cho') || cleanText.contains('cho tiền') || 
        cleanText.contains('trả tiền') || cleanText.contains('khoản thu') ||
        cleanText.contains('khoảng thu') || cleanText.contains('cho tôi') ||
        cleanText.contains('đưa tôi') || cleanText.contains('mẹ tôi cho') ||
        cleanText.contains('bán') || cleanText.contains('lời ') || 
        cleanText.contains('lãi') || cleanText.contains('thu được') || 
        cleanText.contains('đầu tư') || cleanText.contains('trúng số') ||
        cleanText.contains('nhận tiền') || cleanText.contains('thu tiền') ||
        cleanText.contains('cho thuê') || cleanText.contains('lãnh lương') || cleanText.contains('thanh lý')) {
      type = 'income';
    }

    return {
      'category': category,
      'amount': amount,
      'type': type,
      'description': text,
      'hour': parsedHour,
      'minute': parsedMinute,
    };
  }

  double _parseVietnameseNumber(String text) {
    final Map<String, int> units = {
      'không': 0, 'một': 1, 'hai': 2, 'ba': 3, 'bốn': 4, 'năm': 5, 'sáu': 6, 'bảy': 7, 'tám': 8, 'chín': 9, 'mười': 10,
      'mốt': 1, 'lăm': 5, 'nhăm': 5, 'tư': 4, 'linh': 0, 'lẻ': 0
    };
    
    final Map<String, int> multipliers = {
      'mươi': 10, 'chục': 10, 'trăm': 100, 'nghìn': 1000, 'ngàn': 1000, 'triệu': 1000000, 'tỷ': 1000000000
    };

    double total = 0;
    double current = 0;
    List<String> words = text.split(' ');

    for (int i = 0; i < words.length; i++) {
        String word = words[i];
        
        if (units.containsKey(word)) {
            current += units[word]!;
        } else if (multipliers.containsKey(word)) {
            int multiplier = multipliers[word]!;
            if (multiplier >= 1000) {
                total += (current == 0 ? 1.0 : current) * multiplier;
                current = 0;
            } else {
                current = (current == 0 ? 1.0 : current) * multiplier;
            }
        } else if (word == 'rưỡi') {
            if (i > 0) {
                String prev = words[i-1];
                if (prev == 'triệu') {
                  total += 500000;
                } else if (prev == 'nghìn' || prev == 'ngàn') {
                  total += 500;
                } else if (prev == 'trăm') {
                  total += 50;
                }
            }
        }
    }
    return total + current;
  }

}
