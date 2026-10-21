import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

bool deviceContactsPlatformSupported() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

class DeviceContactItem {
  final String name;
  final String phone;
  final String rawPhone;

  const DeviceContactItem({
    required this.name,
    required this.phone,
    required this.rawPhone,
  });
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

  /// Chuẩn hóa số điện thoại: bỏ khoảng trắng, đổi +84 / 84 thành 0
  static String normalizePhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '').trim();
    if (cleaned.startsWith('+84')) {
      cleaned = '0${cleaned.substring(3)}';
    } else if (cleaned.startsWith('84') && cleaned.length >= 11) {
      cleaned = '0${cleaned.substring(2)}';
    }
    // Bỏ tất cả ký tự không phải số nếu còn sót lại
    return cleaned.replaceAll(RegExp(r'\D'), '');
  }

  Future<bool> requestPermission() async {
    if (!deviceContactsPlatformSupported()) return false;
    try {
      return await FlutterContacts.requestPermission(readonly: true);
    } catch (e) {
      debugPrint('DeviceContactsService requestPermission error: $e');
      return false;
    }
  }

  /// Lấy danh sách liên hệ từ danh bạ máy kèm bộ lọc tìm kiếm
  Future<List<DeviceContactItem>> getAllContacts({String? searchQuery}) async {
    if (!deviceContactsPlatformSupported()) return [];
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) return [];

      final list = await FlutterContacts.getContacts(
        withProperties: true,
      );

      final results = <DeviceContactItem>[];
      final seenPhones = <String>{};
      final query = searchQuery?.toLowerCase().trim() ?? '';

      for (var c in list) {
        final name = c.displayName.trim().isNotEmpty ? c.displayName.trim() : 'Chưa đặt tên';
        for (var p in c.phones) {
          final raw = p.number.trim();
          final normalized = normalizePhoneNumber(raw);
          if (normalized.length < 8) continue; // Bỏ số quá ngắn hoặc không hợp lệ

          if (seenPhones.contains(normalized)) continue;
          seenPhones.add(normalized);

          if (query.isEmpty ||
              name.toLowerCase().contains(query) ||
              normalized.contains(query) ||
              raw.contains(query)) {
            results.add(DeviceContactItem(
              name: name,
              phone: normalized,
              rawPhone: raw,
            ));
          }
        }
      }

      results.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return results;
    } catch (e) {
      debugPrint('DeviceContactsService getAllContacts error: $e');
      return [];
    }
  }

  Future<DeviceContactsSnapshot?> loadSnapshot() async {
    if (!deviceContactsPlatformSupported()) return null;
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) return null;

      final list = await FlutterContacts.getContacts(
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

