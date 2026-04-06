import 'lib/services/voice_service.dart';

void main() {
  final service = VoiceService();
  var result = service.parseVoiceCommand('sáng nay 8h sáng mẹ cho 100.000k ăn cơm');
  print('Result for 100.000k: \$result');
  
  result = service.parseVoiceCommand('8h sáng mẹ cho 100000k ăn cơm');
  print('Result for 100000k: \$result');
  
  result = service.parseVoiceCommand('sáng nay 8h sáng mẹ cho 100k ăn cơm');
  print('Result for 100k: \$result');
}
