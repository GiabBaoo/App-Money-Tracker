import 'lib/services/voice_service.dart';

void main() {
  final service = VoiceService();
  final cmds = [
    'sáng nay tôi bán tai nghe lời được 100.000'
  ];
  
  for (var c in cmds) {
    print('---');
    print(c);
    final res = service.parseVoiceCommand(c);
    print(res);
  }
}
