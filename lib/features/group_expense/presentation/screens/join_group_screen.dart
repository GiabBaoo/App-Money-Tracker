import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/group_expense_providers.dart';
import '../../data/dtos/update_group_dto.dart';
import 'group_detail_screen.dart';

class JoinGroupScreen extends ConsumerStatefulWidget {
  final String groupId;

  const JoinGroupScreen({super.key, required this.groupId});

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  bool _isJoining = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Delay nhỏ để đợi Firebase Auth cập nhật sau khi login
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _checkAndJoinGroup();
      }
    });
  }

  Future<void> _checkAndJoinGroup() async {
    // Sử dụng FirebaseAuth trực tiếp để đảm bảo có user
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final userId = firebaseUser?.uid;
    
    print('DEBUG: Checking user - Firebase: ${firebaseUser?.uid}, Provider: ${ref.read(currentUserIdProvider)}');
    
    if (userId == null) {
      // Chưa đăng nhập - lưu groupId vào SharedPreferences và chuyển đến login
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pendingGroupId', widget.groupId);
      print('DEBUG: Saved pendingGroupId to SharedPreferences: ${widget.groupId}');
      
      setState(() {
        _errorMessage = 'Đang chuyển đến trang đăng nhập...';
        _isJoining = false;
      });
      
      // Chờ 1 giây rồi chuyển đến login
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      // Kiểm tra xem group có tồn tại không
      final groupRepository = ref.read(groupRepositoryProvider);
      final group = await groupRepository.getById(widget.groupId);
      
      if (group == null) {
        setState(() {
          _errorMessage = 'Quỹ không tồn tại hoặc đã bị xóa';
          _isJoining = false;
        });
        return;
      }

      // Kiểm tra xem user đã là thành viên chưa
      if (group.memberIds.contains(userId)) {
        // Đã là thành viên, chuyển thẳng vào group detail
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => GroupDetailScreen(groupId: widget.groupId),
            ),
          );
        }
        return;
      }

      // Thêm user vào group bằng method addMember
      await groupRepository.addMember(widget.groupId, userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã tham gia quỹ "${group.name}" thành công! Vào "Quỹ Nhóm" để xem chi tiết.'),
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Navigate về Home thay vì GroupDetailScreen để tránh lỗi provider
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch (e) {
      print('DEBUG ERROR in _checkAndJoinGroup: $e');
      setState(() {
        _errorMessage = 'Lỗi: $e';
        _isJoining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121212) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isJoining) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    'Đang tham gia quỹ...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ] else if (_errorMessage != null) ...[
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[400],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Quay lại',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
