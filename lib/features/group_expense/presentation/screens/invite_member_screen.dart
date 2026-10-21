import '../../../../services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../widgets/animated_scale_button.dart';
import '../../../../services/device_contacts_service.dart';
import '../../../../services/notification_service.dart';

class InviteMemberScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const InviteMemberScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _foundUserName;
  String? _foundUserId;
  bool _isSearching = false;
  String? _searchError;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickFromContacts() async {
    HapticFeedback.selectionClick();
    final hasPermission = await DeviceContactsService.instance.requestPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isVi
                  ? 'Ứng dụng cần quyền truy cập danh bạ để chọn người liên hệ'
                  : 'Contacts permission is required to select contacts',
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    final selectedPhone = await _showContactPickerSheet(context);
    if (selectedPhone != null && selectedPhone.isNotEmpty) {
      _phoneController.text = selectedPhone;
      _searchUser(selectedPhone);
    }
  }

  Future<String?> _showContactPickerSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ContactPickerModal(
        isDark: isDark,
        primaryColor: primaryColor,
      ),
    );
  }

  Future<void> _searchUser(String phone) async {
    if (phone.isEmpty) {
      setState(() {
        _foundUserName = null;
        _foundUserId = null;
        _searchError = null;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      // Tìm user theo số điện thoại
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        setState(() {
          _foundUserName = null;
          _foundUserId = null;
          _searchError = isVi ? 'Không tìm thấy người dùng' : 'User not found';
          _isSearching = false;
        });
        return;
      }

      final userData = usersSnapshot.docs.first.data();
      final userName = userData['name'] as String? ?? (isVi ? 'Người dùng' : 'User');
      final userId = usersSnapshot.docs.first.id;

      setState(() {
        _foundUserName = userName;
        _foundUserId = userId;
        _searchError = null;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _foundUserName = null;
        _foundUserId = null;
        _searchError = '${isVi ? 'Lỗi tìm kiếm' : 'Search error'}: $e';
        _isSearching = false;
      });
    }
  }

  void _inviteByPhone(String phone) async {
    if (_foundUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isVi ? 'Vui lòng chọn người dùng hợp lệ' : 'Please select a valid user')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Gửi thông báo mời tham gia nhóm quỹ chi tiêu qua NotificationService
      await NotificationService().notifyGroupInvitation(
        groupName: widget.groupName,
        inviterName: isVi ? 'Trưởng nhóm' : 'Group Admin',
        targetUid: _foundUserId!,
        groupId: widget.groupId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isVi ? '✓ Đã gửi lời mời đến $_foundUserName' : '✓ Invitation sent to $_foundUserName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        _phoneController.clear();
        setState(() {
          _foundUserName = null;
          _foundUserId = null;
          _searchError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isVi ? 'Lỗi' : 'Error'}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  AnimatedScaleButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Mời Thành Viên',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121212) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      
                      // Icon và tiêu đề
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                Icons.person_add_rounded,
                                size: 50,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              isVi ? 'Mời thành viên vào ${widget.groupName}' : 'Invite members to ${widget.groupName}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isVi ? 'Nhập số điện thoại để gửi lời mời' : 'Enter phone number to invite',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Phone input
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        enabled: !_isLoading,
                        onChanged: (phone) {
                          _searchUser(phone.trim());
                        },
                        decoration: InputDecoration(
                          hintText: isVi ? 'Ví dụ: 0912345678' : 'e.g. 0912345678',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          prefixIcon: Icon(
                            Icons.phone_rounded,
                            color: primaryColor,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isSearching)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                    ),
                                  ),
                                ),
                              IconButton(
                                icon: Icon(
                                  Icons.contacts_rounded,
                                  color: primaryColor,
                                ),
                                tooltip: isVi ? 'Chọn từ danh bạ' : 'Pick from contacts',
                                onPressed: _isLoading ? null : _pickFromContacts,
                              ),
                            ],
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3F4F6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: isDark ? BorderSide(color: Colors.white.withValues(alpha: 0.08)) : BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: isDark ? BorderSide(color: Colors.white.withValues(alpha: 0.08)) : BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                      
                      // Display found user name or error
                      if (_phoneController.text.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            if (_searchError != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 18,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _searchError!,
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_foundUserName != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.person_outline,
                                        color: Colors.green,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isVi ? 'Sẽ mời' : 'Invite',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _foundUserName!,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      
                      const SizedBox(height: 24),
                      
                      // Submit button
                      AnimatedScaleButton(
                        onTap: (_isLoading || _foundUserId == null)
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                _inviteByPhone(_phoneController.text.trim());
                              },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: (_isLoading || _foundUserId == null)
                                ? primaryColor.withValues(alpha: 0.4)
                                : primaryColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: (_isLoading || _foundUserId == null)
                                ? null
                                : [
                                    BoxShadow(
                                      color: primaryColor.withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Center(
                            child: _isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isDark ? Colors.black : Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Gửi Lời Mời',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Info box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Người được mời sẽ nhận thông báo lời mời',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}

class _ContactPickerModal extends StatefulWidget {
  final bool isDark;
  final Color primaryColor;

  const _ContactPickerModal({
    required this.isDark,
    required this.primaryColor,
  });

  @override
  State<_ContactPickerModal> createState() => _ContactPickerModalState();
}

class _ContactPickerModalState extends State<_ContactPickerModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<DeviceContactItem> _allContacts = [];
  List<DeviceContactItem> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final list = await DeviceContactsService.instance.getAllContacts();
      if (mounted) {
        setState(() {
          _allContacts = list;
          _filtered = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading contacts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = _allContacts;
      } else {
        _filtered = _allContacts.where((c) {
          return c.name.toLowerCase().contains(q) ||
              c.phone.contains(q) ||
              c.rawPhone.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.75;
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Container(
      height: sheetHeight,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.contacts_rounded, color: widget.primaryColor, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      isVi ? 'Chọn từ danh bạ' : 'Select from Contacts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: isVi ? 'Tìm kiếm tên hoặc số điện thoại...' : 'Search name or phone number...',
                hintStyle: TextStyle(
                  color: widget.isDark ? Colors.white38 : Colors.black38,
                  fontSize: 14,
                ),
                prefixIcon: Icon(Icons.search_rounded, color: widget.primaryColor, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: widget.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Contact List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(widget.primaryColor),
                    ),
                  )
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_search_rounded,
                              size: 48,
                              color: Colors.grey.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isVi ? 'Không tìm thấy liên hệ nào' : 'No contacts found',
                              style: TextStyle(
                                color: widget.isDark ? Colors.white60 : Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          indent: 68,
                          color: widget.isDark ? Colors.white12 : Colors.black12,
                        ),
                        itemBuilder: (ctx, index) {
                          final contact = _filtered[index];
                          final initial = contact.name.isNotEmpty
                              ? contact.name.characters.first.toUpperCase()
                              : '?';

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: widget.primaryColor.withValues(alpha: 0.15),
                              foregroundColor: widget.primaryColor,
                              child: Text(
                                initial,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              contact.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: widget.isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              contact.phone,
                              style: TextStyle(
                                fontSize: 13,
                                color: widget.isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: Colors.grey,
                            ),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.pop(context, contact.phone);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

