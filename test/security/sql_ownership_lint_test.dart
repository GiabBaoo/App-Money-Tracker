import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Mọi UPDATE/DELETE trên bảng nghiệp vụ phải có uid = ?', () {
    const owned = {
      'transactions',
      'wallets',
      'budgets',
      'goals',
      'notifications',
      'messages',
      'device_sessions',
    };
    final call = RegExp(r"\.(update|delete)\(\s*'(\w+)'(.*?)\);", dotAll: true);
    final whereRe = RegExp(r"where:\s*'([^']*)'");
    final offenders = <String>[];
    for (final dir in ['lib/data', 'lib/services']) {
      for (final f in Directory(
        dir,
      ).listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final content = f.readAsStringSync();
        for (final m in call.allMatches(content)) {
          if (!owned.contains(m.group(2))) continue;
          final where = whereRe.firstMatch(m.group(3)!)?.group(1) ?? '';
          if (!where.contains('uid = ?')) {
            offenders.add('${f.path}: ${m.group(0)!.split('\n').first}');
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
