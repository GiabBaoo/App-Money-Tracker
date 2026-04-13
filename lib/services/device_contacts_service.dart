import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

bool deviceContactsPlatformSupported() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

class DeviceContactsSnapshot {
  const DeviceContactsSnapshot({
    required this.total,
    required this.previewLines,
  });

  final int total;
  final List<String> previewLines;
}

class DeviceContactsService {
  DeviceContactsService._();
  static final DeviceContactsService instance = DeviceContactsService._();

  static const int _previewLimit = 15;

  bool _permissionOk(bool granted) => granted;

  Future<bool> requestPermission() async {
    if (!deviceContactsPlatformSupported()) return false;
    try {
      return await FlutterContacts.requestPermission(readonly: true);
    } catch (_) {
      return false;
    }
  }

  Future<DeviceContactsSnapshot?> loadSnapshot() async {
    if (!deviceContactsPlatformSupported()) return null;
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) return null;

      final list = await FlutterContacts.getAll(
        withProperties: true,
      );

      final preview = <String>[];
      for (var i = 0; i < list.length && i < _previewLimit; i++) {
        final c = list[i];
        final name = (c.displayName.trim().isNotEmpty)
            ? c.displayName.trim()
            : '(Chưa đặt tên)';
        final phone = c.phones.isNotEmpty
            ? c.phones.first.number.replaceAll(RegExp(r'\s+'), ' ').trim()
            : '';
        preview.add(phone.isNotEmpty ? '$name · $phone' : name);
      }

      return DeviceContactsSnapshot(total: list.length, previewLines: preview);
    } catch (_) {
      return null;
    }
  }
}
