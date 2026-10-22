import '../../../../services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/animated_scale_button.dart';
import '../../../../widgets/mono_toast.dart';
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
        MonoToast.warning(
          context,
          isVi
              ? 'Ứng dụng cần quyền truy cập danh bạ để chọn người liên hệ'
              : 'Contacts permission is required to select contacts',
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
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        setState(() {
          _foundUserName = null;
          _foundUserId = null;
          _searchError = isVi ? 'Không tìm thấy người dùng với số này' : 'User not found with this phone';
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
      MonoToast.warning(
        context,
        isVi ? 'Vui lòng chọn người dùng hợp lệ' : 'Please select a valid user',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await NotificationService().notifyGroupInvitation(
        groupName: widget.groupName,
        inviterName: isVi ? 'Trưởng nhóm' : 'Group Admin',
        targetUid: _foundUserId!,
        groupId: widget.groupId,
      );

      if (mounted) {
        MonoToast.success(
          context,
          isVi ? 'Đã gửi lời mời đến $_foundUserName' : 'Invitation sent to $_foundUserName',
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
        MonoToast.error(
          context,
          '${isVi ? 'Lỗi' : 'Error'}: $e',
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
    final isDark = context.isDarkMode;
    final primaryColor = context.colors.primary;

    // Design Tokens
    final bgColor = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBgColor = context.cardBg;
    final textPrimary = context.colors.onSurface;
    final textSecondary = context.colors.onSurfaceVariant;
    final borderColor = context.borderColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─── ERGONOMIC TOP APP BAR ───
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
                        color: cardBgColor,
                        border: Border.all(color: borderColor, width: 1),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: textPrimary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVi ? 'Mời Thành Viên' : 'Invite Member',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          widget.groupName,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── CONTENT BODY ───
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor, width: 1),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primaryColor.withValues(alpha: 0.12),
                            ),
                            child: Icon(
                              Icons.person_add_rounded,
                              size: 28,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isVi ? 'Mời tham gia quỹ nhóm' : 'Invite to Group Fund',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isVi
                                ? 'Nhập số điện thoại đã đăng ký để tìm kiếm và gửi lời mời tham gia.'
                                : 'Enter registered phone number to search and invite.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Phone input header
                    Text(
                      isVi ? 'SỐ ĐIỆN THOẠI THÀNH VIÊN' : 'MEMBER PHONE NUMBER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        enabled: !_isLoading,
                        style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                        onChanged: (phone) {
                          _searchUser(phone.trim());
                        },
                        decoration: InputDecoration(
                          hintText: isVi ? 'Ví dụ: 0912345678' : 'e.g. 0912345678',
                          hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 14),
                          prefixIcon: Icon(
                            Icons.phone_rounded,
                            color: primaryColor,
                            size: 20,
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
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        primaryColor,
                                      ),
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
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),

                    // Search Feedback (Error or Found user)
                    if (_phoneController.text.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      if (_searchError != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.warning.withValues(alpha: isDark ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: context.warning),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _searchError!,
                                  style: TextStyle(color: context.warning, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_foundUserName != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.income.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: context.income.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: context.income.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person_rounded,
                                  color: context.income,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isVi ? 'Người nhận lời mời' : 'Invitee',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: context.income,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _foundUserName!,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.check_circle_rounded,
                                color: context.income,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                    ],

                    const SizedBox(height: 24),

                    // Info note
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications_active_outlined,
                            color: primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isVi
                                  ? 'Lời mời sẽ gửi tức thì qua thông báo đến tài khoản của người nhận.'
                                  : 'Invitation will be dispatched instantly via in-app notification.',
                              style: TextStyle(
                                fontSize: 13,
                                color: textSecondary,
                                height: 1.4,
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

            // ─── ERGONOMIC THUMB-FRIENDLY BOTTOM ACTION BAR ───
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: cardBgColor,
                border: Border(top: BorderSide(color: borderColor, width: 1)),
              ),
              child: SafeArea(
                top: false,
                child: AnimatedScaleButton(
                  onTap: (_isLoading || _foundUserId == null)
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          _inviteByPhone(_phoneController.text.trim());
                        },
                  child: Container(
                    height: 54,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: (_isLoading || _foundUserId == null)
                          ? null
                          : LinearGradient(
                              colors: [
                                primaryColor,
                                primaryColor.withValues(alpha: 0.85),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: (_isLoading || _foundUserId == null)
                          ? (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9))
                          : null,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: (_isLoading || _foundUserId == null)
                          ? []
                          : [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.send_rounded,
                                  color: (_isLoading || _foundUserId == null) ? textSecondary : Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isVi ? 'Gửi Lời Mời Ngay' : 'Send Invitation Now',
                                  style: TextStyle(
                                    color: (_isLoading || _foundUserId == null) ? textSecondary : Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
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

    final sheetBg = context.cardBg;
    final textP = context.colors.onSurface;
    final textS = context.colors.onSurfaceVariant;
    final dividerColor = context.borderColor;
    final primaryColor = context.colors.primary;

    return Container(
      height: sheetHeight,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: context.borderColor, width: 1),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: textS.withValues(alpha: 0.3),
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
                    Icon(Icons.contacts_rounded, color: primaryColor, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      isVi ? 'Chọn từ danh bạ' : 'Select from Contacts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textP,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 22, color: textS),
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
              style: TextStyle(color: textP, fontSize: 14),
              decoration: InputDecoration(
                hintText: isVi ? 'Tìm kiếm tên hoặc số điện thoại...' : 'Search name or phone number...',
                hintStyle: TextStyle(
                  color: textS.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
                prefixIcon: Icon(Icons.search_rounded, color: textS, size: 20),
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
                fillColor: context.inputBgColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
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
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  )
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_search_rounded,
                              size: 44,
                              color: textS.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isVi ? 'Không tìm thấy liên hệ nào' : 'No contacts found',
                              style: TextStyle(color: textS, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          indent: 68,
                          color: dividerColor,
                        ),
                        itemBuilder: (ctx, index) {
                          final contact = _filtered[index];
                          final initial = contact.name.isNotEmpty
                              ? contact.name.characters.first.toUpperCase()
                              : '?';

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: primaryColor.withValues(alpha: 0.15),
                              foregroundColor: primaryColor,
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
                                color: textP,
                              ),
                            ),
                            subtitle: Text(
                              contact.phone,
                              style: TextStyle(
                                fontSize: 13,
                                color: textS,
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: textS.withValues(alpha: 0.6),
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
