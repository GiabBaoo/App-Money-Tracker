import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/user_model.dart';
import '../../services/device_contacts_service.dart';
import '../../services/firestore_service.dart';
import '../../services/place_name_resolver.dart';

class DataUsageScreen extends StatefulWidget {
  const DataUsageScreen({super.key});

  @override
  State<DataUsageScreen> createState() => _DataUsageScreenState();
}

class _DataUsageScreenState extends State<DataUsageScreen> {
  String? _locationDisplayText;
  bool _locationLoading = false;
  bool _locationEnabling = false;
  bool _autoLocationFetchAttempted = false;

  DeviceContactsSnapshot? _contactsSnapshot;
  bool _contactsLoading = false;
  bool _contactsEnabling = false;
  bool _autoContactsFetchAttempted = false;

  Future<void> _updatePreference(UserModel user, String key, bool value) {
    return FirestoreService().updateUserProfile({
      'dataUsage': {...user.dataUsage, key: value},
    });
  }

  /// Thành công khi đã lấy được GPS; luôn hiển thị tên địa điểm (không hiện tọa độ).
  Future<bool> _fetchLocationDisplay() async {
    if (_locationLoading) return false;

    setState(() {
      _locationLoading = true;
      _locationDisplayText = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationDisplayText =
                'Không lấy được vị trí. Hãy bật dịch vụ vị trí trên thiết bị.';
          });
        }
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _locationDisplayText =
                'Đã từ chối quyền vị trí. Bật quyền trong Cài đặt hệ thống để xem vị trí.';
          });
        }
        return false;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationDisplayText =
                'Quyền vị trí bị từ chối vĩnh viễn. Mở Cài đặt ứng dụng để cấp quyền.';
          });
        }
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final name = await PlaceNameResolver.instance.resolveDisplayName(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return false;
      setState(() {
        _locationDisplayText = (name != null && name.isNotEmpty)
            ? name
            : 'Không xác định được tên địa điểm. Thử nút làm mới hoặc kiểm tra kết nối mạng.';
      });
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationDisplayText = 'Lỗi vị trí: $e';
        });
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _locationLoading = false);
      }
    }
  }

  Future<void> _onLocationSwitch(UserModel user, bool wantOn) async {
    if (!wantOn) {
      setState(() {
        _locationDisplayText = null;
        _autoLocationFetchAttempted = false;
      });
      await _updatePreference(user, 'location', false);
      return;
    }

    setState(() => _locationEnabling = true);
    try {
      final ok = await _fetchLocationDisplay();
      if (!mounted) return;
      if (ok) {
        await _updatePreference(user, 'location', true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể bật vị trí. Kiểm tra dịch vụ vị trí và quyền truy cập.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locationEnabling = false);
    }
  }

  Future<bool> _fetchContactsDisplay() async {
    if (_contactsLoading) return false;

    if (!deviceContactsPlatformSupported()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Danh bạ chỉ khả dụng trên ứng dụng Android hoặc iOS.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    setState(() {
      _contactsLoading = true;
      _contactsSnapshot = null;
    });

    try {
      final snap = await DeviceContactsService.instance.loadSnapshot();
      if (!mounted) return false;
      if (snap == null) {
        setState(() {
          _contactsSnapshot = null;
        });
        return false;
      }
      setState(() => _contactsSnapshot = snap);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không đọc được danh bạ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _contactsLoading = false);
    }
  }

  Future<void> _onContactsSwitch(UserModel user, bool wantOn) async {
    if (!wantOn) {
      setState(() {
        _contactsSnapshot = null;
        _autoContactsFetchAttempted = false;
      });
      await _updatePreference(user, 'contacts', false);
      return;
    }

    if (!deviceContactsPlatformSupported()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Danh bạ chỉ khả dụng trên ứng dụng Android hoặc iOS.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _contactsEnabling = true);
    try {
      final ok = await _fetchContactsDisplay();
      if (!mounted) return;
      if (ok) {
        await _updatePreference(user, 'contacts', true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể bật danh bạ. Kiểm tra quyền truy cập danh bạ trong Cài đặt.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _contactsEnabling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: FirestoreService().getUserStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF438883),
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF438883),
            body: Center(
              child: Text(
                'Lỗi tải dữ liệu',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        final isLocationEnabled = user.dataUsage['location'] ?? true;
        final isContactsEnabled = user.dataUsage['contacts'] ?? false;

        if (!isLocationEnabled && _locationDisplayText != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _locationDisplayText = null;
                _autoLocationFetchAttempted = false;
              });
            }
          });
        }

        if (isLocationEnabled &&
            _locationDisplayText == null &&
            !_locationLoading &&
            !_locationEnabling &&
            !_autoLocationFetchAttempted) {
          _autoLocationFetchAttempted = true;
          Future.microtask(() async {
            if (!mounted) return;
            await _fetchLocationDisplay();
          });
        }

        if (!isContactsEnabled && _contactsSnapshot != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _contactsSnapshot = null;
                _autoContactsFetchAttempted = false;
              });
            }
          });
        }

        if (isContactsEnabled &&
            _contactsSnapshot == null &&
            !_contactsLoading &&
            !_contactsEnabling &&
            !_autoContactsFetchAttempted &&
            deviceContactsPlatformSupported()) {
          _autoContactsFetchAttempted = true;
          Future.microtask(() async {
            if (!mounted) return;
            await _fetchContactsDisplay();
          });
        }

        return Scaffold(
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF1E1E1E) 
            : const Color(0xFF438883),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Sử dụng dữ liệu',
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
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(
                        top: 30,
                        bottom: 40,
                        left: 24,
                        right: 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 12),
                            child: Text(
                              'DỮ LIỆU ĐƯỢC THU THẬP',
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark 
                                ? const Color(0xFF2E2E2E) 
                                : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                _buildLocationToggleItem(
                                  value: isLocationEnabled,
                                  onChanged: _locationEnabling
                                      ? null
                                      : (val) => _onLocationSwitch(user, val),
                                ),
                                _buildContactsToggleItem(
                                  value: isContactsEnabled,
                                  onChanged: _contactsEnabling
                                      ? null
                                      : (val) => _onContactsSwitch(user, val),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          Builder(
                            builder: (context) {
                              final isDark = Theme.of(context).brightness == Brightness.dark;
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF0F7F5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFCCFEEB),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF3E3E3E) : Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.verified_user,
                                        color: Color(0xFF4A9B7F),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Cam kết bảo mật',
                                            style: TextStyle(
                                              color: isDark ? Colors.white : const Color(0xFF333333),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Dữ liệu của bạn được mã hóa và bảo vệ theo tiêu chuẩn quốc tế.',
                                            style: TextStyle(
                                              color: isDark ? Colors.white70 : const Color(0xFF666666),
                                              fontSize: 14,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationToggleItem({
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE8F5F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF438883),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vị trí',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF333333),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cho phép truy cập vị trí hiện tại để tối ưu hóa gợi ý địa phương',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF888888),
                            fontSize: 14,
                          ),
                        ),

                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: value,
                    onChanged: onChanged,
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFF4A9B7F),
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFFE0E0E0),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: isDark ? const Color(0xFF3E3E3E) : Colors.grey.shade200,
              indent: 76,
              endIndent: 16,
            ),
          ],
        );
      }
    );
  }

  Widget _buildContactsToggleItem({
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final snap = _contactsSnapshot;
    final remaining = snap != null && snap.total > snap.previewLines.length
        ? snap.total - snap.previewLines.length
        : 0;

    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE8F5F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.contacts_outlined,
                  color: Color(0xFF438883),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Danh bạ',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF333333),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Đồng bộ hóa danh bạ để kết nối nhanh chóng với bạn bè',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF888888),
                        fontSize: 14,
                      ),
                    ),

                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF4A9B7F),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFE0E0E0),
              ),
            ],
          ),
        );
      }
    );
  }
}
